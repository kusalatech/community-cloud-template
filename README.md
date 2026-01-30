# Community Cloud — Kusala Studio

Community cloud automation for [Kusala Studio](https://kusala.studio), provisioned with Ansible and driven from GitHub Actions via `gcloud compute ssh`. Licensed under **AGPLv3**.

## Overview

- **Ansible** lives in `ansible/` and runs on a dedicated **Ansible control node** (GCP VM).
- The **GitHub shared runner** never holds SSH keys to your hosts. It authenticates to GCP and runs Ansible by connecting to the control node with **`gcloud compute ssh`** (IAM-based; safe for a public repo).
- The control node is provisioned with an **ed25519 SSH key** used by Ansible to manage other hosts.

## Getting started

1. **Bootstrap GCP and GitHub** (one-time): from the repo root, with [gcloud](https://cloud.google.com/sdk/docs/install) and [GitHub CLI](https://cli.github.com/) installed and authenticated:
   ```bash
   GCP_PROJECT_ID=your-project make bootstrap
   ```
   This creates the GCP service account, a JSON key, and sets **GCP_SA_KEY**/**GCP_PROJECT_ID** in this repository’s GitHub Actions secrets via `gh secret set`. Run `make help` for targets.

2. **Provision the Ansible control node**: in GitHub, run **Actions → Provision Ansible control node → Run workflow** (or push to `main` after changing the provision workflow or bootstrap script).

3. **Run Ansible**: push changes under `ansible/`, or run **Actions → Run Ansible → Run workflow**.

## Repository layout

```
.
├── Makefile                     # bootstrap = create SA + set GCP_SA_KEY via gh
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   │       └── all.yml
│   ├── playbooks/
│   │   └── site.yml
│   ├── roles/
│   └── scripts/
│       └── bootstrap-control-node.sh
├── utils/
│   └── provision-github-sa.sh   # used by make bootstrap
.github/workflows/
├── provision-control-node.yml   # Create GCP VM, install Ansible, generate ed25519 key
└── run-ansible.yml              # gcloud compute ssh → control node → ansible-playbook
```

## GitHub secrets (required)

Configure these in **Settings → Secrets and variables → Actions**:

| Secret           | Description |
|------------------|-------------|
| `GCP_PROJECT_ID` | GCP project ID |
| `GCP_SA_KEY`     | JSON key for a service account that can create VMs and use `gcloud compute ssh` |
| `GCP_REGION`     | (Optional) Region, e.g. `us-central1`. Default: `us-central1` |
| `GCP_ZONE`       | (Optional) Zone override, e.g. `us-central1-a`. If set, it wins over `GCP_REGION`. |
| `GCP_INSTANCE_NAME` | (Optional) Control node VM name. Default: `ansible-control` |

The service account should have at least:

- Compute Instance Admin (v1) or equivalent (create/describe instances)
- Compute Security Admin (create/describe firewall rules)
- Service Account User (to SSH as the VM’s SA)
- Or a custom role that allows `compute.instances.create`, `compute.instances.get`, `compute.instances.use` (for SSH), and `compute.firewalls.create`/`compute.firewalls.get`

## Workflows

### 1. Provision Ansible control node

**Workflow:** `provision-control-node.yml`

- Creates a GCP VM (Debian 12, `e2-micro` by default) if it doesn’t exist.
- Runs `ansible/scripts/bootstrap-control-node.sh` on the VM to:
  - Install Ansible
  - Generate an ed25519 SSH key at `~/.ssh/ansible_ed25519` (for Ansible to manage other hosts)
  - Clone this repo to `/opt/community-cloud`

**When it runs:** On push to `main` when the workflow or bootstrap script change, or manually via **Actions → Provision Ansible control node → Run workflow**.

### 2. Run Ansible

**Workflow:** `run-ansible.yml`

- Authenticates to GCP, then runs:
  - `gcloud compute ssh <control-node> --command="cd /opt/community-cloud && git pull && ansible-playbook <playbook>"`
- So the **runner** only uses GCP credentials; the **control node** holds the repo and the ed25519 key.

**When it runs:** On push to `main` when files under `ansible/` change, or manually with an optional playbook path (default: `ansible/playbooks/site.yml`).

## Local / manual usage

After the control node exists:

```bash
# From a machine with gcloud and access to the project
export GCP_PROJECT_ID=your-project
export REGION=us-central1
export INSTANCE=ansible-control

ZONE="$(gcloud compute zones list --filter="region:($REGION) AND status=UP" --format="value(name)" | head -n 1)"
gcloud compute ssh "$INSTANCE" --zone="$ZONE" --project="$GCP_PROJECT_ID" \
  --command="cd /opt/community-cloud && git pull && ansible-playbook ansible/playbooks/site.yml"
```

To use the control node’s ed25519 key for other hosts, add `~/.ssh/ansible_ed25519.pub` (from the control node) to `authorized_keys` on those hosts.

## License

This project is licensed under the **GNU Affero General Public License v3** (AGPLv3). See [LICENSE](LICENSE) and [https://www.gnu.org/licenses/agpl-3.0.html](https://www.gnu.org/licenses/agpl-3.0.html).
