#!/bin/bash
mkdir -p ~/.ssh
echo "$GIT_SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
ssh-keyscan github.com >> ~/.ssh/known_hosts
exec bun run gbrain serve --http