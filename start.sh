#!/bin/bash
set -e # fail fast if any step errors.

# Install openssh-client if missing — Railway's Bun base image doesn't include it.
# Required for ssh-keyscan and git over SSH.
# `if ! command -v ssh-keyscan` guard avoids re-installing openssh-client on warm boots (it persists in the container layer between deploys on the same image)
if ! command -v ssh-keyscan &> /dev/null; then
  apt-get update && apt-get install -y --no-install-recommends openssh-client
fi

# Symlink the gbrain CLI into PATH — fixes "Phase B (smoke) failed: gbrain: not found"
# during migration runs.
ln -sf "$(pwd)/src/cli.ts" /usr/local/bin/gbrain
chmod +x /usr/local/bin/gbrain


# Write the SSH deploy key from env var.
mkdir -p ~/.ssh
echo "$GIT_SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
ssh-keyscan github.com >> ~/.ssh/known_hosts

# Apply migrations (idempotent) then start the HTTP server.
# Mandatory aspects of the serve command:
# - `bun src/cli.ts``" NOT bun run gbrain — no such script in package.json
# - `--bind 0.0.0.0`: GBrain defaults to 127.0.0.1 since v0.34.1.
# - `--port "$PORT"`: GBrain doesn't read the PORT env var automatically
# - `--public-url "$GBRAIN_OAUTH_ISSUER"`: Required behind a proxy for correct OAuth issuer claims
bun src/cli.ts apply-migrations --yes --non-interactive
exec bun src/cli.ts serve --http --bind 0.0.0.0 --port "$PORT" --public-url "$GBRAIN_OAUTH_ISSUER"
