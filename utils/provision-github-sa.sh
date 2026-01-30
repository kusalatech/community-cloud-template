#!/bin/sh

usage() {
  cat <<'EOF'
Usage: provision-github-sa.sh [OPTIONS]

Create a GCP service account for GitHub Actions (Ansible control workflows),
grant it Compute Instance Admin, Compute Security Admin, and Service Account
User roles, create a JSON key, and set it as the GCP_SA_KEY repository secret
using GitHub CLI.

Requires:
  GCP_PROJECT_ID    GCP project ID (environment variable).
  gh                GitHub CLI, installed and authenticated (gh auth login).

Options:
  -h, --help        Show this help and exit.

Example:
  GCP_PROJECT_ID=my-project ./provision-github-sa.sh
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

PROJECT_ID=${GCP_PROJECT_ID:?GCP_PROJECT_ID is required}
SA_EMAIL="github-ansible-control@${PROJECT_ID}.iam.gserviceaccount.com"

# Create the service account (ignore error if already exists)
gcloud iam service-accounts create github-ansible-control \
  --project="$PROJECT_ID" \
  --display-name="GitHub Actions Ansible control" \
  2>/dev/null || true

# Grant roles
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/compute.instanceAdmin.v1"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/compute.securityAdmin"

# Create key to a temp file, push to GitHub secrets, then remove key
KEY_FILE=$(mktemp -t gcp-sa-key.XXXXXX.json)
trap 'rm -f "$KEY_FILE"' EXIT

gcloud iam service-accounts keys create "$KEY_FILE" \
  --project="$PROJECT_ID" \
  --iam-account="$SA_EMAIL"

gh secret set GCP_SA_KEY < "$KEY_FILE"
gh secret set GCP_PROJECT_ID -b "$PROJECT_ID"

echo "GCP_SA_KEY has been set in this repository's secrets."
