#!/usr/bin/env bash
# Bootstrap Ansible control node for Kusala Studio Community Cloud
# AGPLv3 - https://www.gnu.org/licenses/agpl-3.0.html
#
# Run on a fresh GCP VM (Debian/Ubuntu). Installs Ansible and creates ed25519 SSH key.
set -euo pipefail

REPO_URL="${REPO_URL:-}"
REPO_PATH="${REPO_PATH:-/opt/community-cloud}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/ansible_ed25519}"

if [[ -z "${REPO_URL}" ]]; then
  if [[ -d "$REPO_PATH/.git" ]]; then
    REPO_URL="$(git -C "$REPO_PATH" config --get remote.origin.url || true)"
  elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    REPO_URL="$(git config --get remote.origin.url || true)"
  fi
fi

if [[ -z "${REPO_URL}" ]]; then
  echo "REPO_URL is not set and could not be inferred."
  exit 1
fi

REPO_OWNER="$(printf "%s" "$REPO_URL" | sed -E 's#^https?://[^/]+/([^/]+)/.*#\1#; s#^git@[^:]+:([^/]+)/.*#\1#')"
if [[ -z "$REPO_OWNER" || "$REPO_OWNER" == "$REPO_URL" ]]; then
  REPO_OWNER="unknown"
fi
SSH_KEY_COMMENT="ansible@community-cloud-$REPO_OWNER"

echo "==> Installing dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq git python3-pip python3-venv

echo "==> Installing Ansible..."
sudo pip3 install --break-system-packages ansible 2>/dev/null || sudo pip3 install ansible

echo "==> Creating SSH directory and ed25519 key for Ansible..."
mkdir -p -m 0700 "$(dirname "$SSH_KEY_PATH")"
if [[ ! -f "$SSH_KEY_PATH" ]]; then
  ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "$SSH_KEY_COMMENT"
  chmod 600 "$SSH_KEY_PATH"
  echo "Generated new ed25519 key at $SSH_KEY_PATH"
else
  echo "Key already exists at $SSH_KEY_PATH"
fi

echo "==> Cloning repository..."
sudo mkdir -p "$(dirname "$REPO_PATH")"
if [[ -d "$REPO_PATH/.git" ]]; then
  sudo git -C "$REPO_PATH" pull --rebase
else
  sudo git clone "$REPO_URL" "$REPO_PATH"
fi
sudo chown -R "$(whoami):" "$REPO_PATH"

echo "==> Bootstrap complete. Ansible control node ready."
echo "    Repo: $REPO_PATH"
echo "    SSH key: $SSH_KEY_PATH"
echo "    Public key (add to managed hosts):"
cat "${SSH_KEY_PATH}.pub"
