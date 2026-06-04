#!/bin/bash
set -e # fail fast if any step errors.
set -x # Echo every line to stderr for easier debugging in Railway logs.

echo "=== Step 1: Changing to script directory ==="
cd "$(dirname "$0")" # Ensure in script directory before referencing `src/cli.ts`
pwd

# Install openssh-client if missing — Railway's Bun base image doesn't include it.
# Required for ssh-keyscan and git over SSH.
# `if ! command -v ssh-keyscan` guard avoids re-installing openssh-client on warm boots (it persists in the container layer between deploys on the same image)
echo "=== Step 2: Check for openssh-client ==="
if ! command -v ssh-keyscan &> /dev/null; then
  apt-get update && apt-get install -y --no-install-recommends openssh-client
fi
echo "ssh-keyscan present: $(command -v ssh-keyscan)"

# Symlink the gbrain CLI into PATH — fixes "Phase B (smoke) failed: gbrain: not found"
# during migration runs.
echo "=== Step 3: Symlink gbrain ==="
ls -la src/cli.ts # Verify file creatons
ln -sf "$(pwd)/src/cli.ts" /usr/local/bin/gbrain
chmod +x /usr/local/bin/gbrain
ls -la /usr/local/bin/gbrain # Verify file creatons

# Write the SSH deploy key from env var.
echo "=== Step 4: SSH key setup ==="
mkdir -p ~/.ssh
echo "GIT_SSH_PRIVATE_KEY length: ${#GIT_SSH_PRIVATE_KEY}"
echo "$GIT_SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
ls -la ~/.ssh/id_ed25519 # Verify file creatons
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>&1
echo "known_hosts:"
wc -l ~/.ssh/known_hosts # Verify file creatons

# Apply migrations (idempotent) then start the HTTP server.
# Mandatory aspects of the serve command:
# - `bun src/cli.ts``" NOT bun run gbrain — no such script in package.json
# - `--bind 0.0.0.0`: GBrain defaults to 127.0.0.1 since v0.34.1.
# - `--port "$PORT"`: GBrain doesn't read the PORT env var automatically
# - `--public-url "$GBRAIN_OAUTH_ISSUER"`: Required behind a proxy for correct OAuth issuer claims
echo "=== Step 5: Apply migrations ==="
bun src/cli.ts apply-migrations --yes --non-interactive

echo "=== Step 6: Start HTTP server ==="
exec bun src/cli.ts serve --http --bind 0.0.0.0 --port "$PORT" --public-url "$GBRAIN_OAUTH_ISSUER"
