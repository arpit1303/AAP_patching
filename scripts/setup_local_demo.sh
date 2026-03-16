#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd git
require_cmd bash
require_cmd curl
require_cmd jq
require_cmd ansible-playbook
require_cmd ansible-galaxy

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP:-/tmp/ansible-local}"
export ANSIBLE_REMOTE_TEMP="${ANSIBLE_REMOTE_TEMP:-/tmp/ansible-remote}"

echo "Validating local Ansible content"
ansible-playbook --syntax-check "${ROOT_DIR}/bootstrap_tam_day_assets.yml"
ansible-playbook --syntax-check "${ROOT_DIR}/env_slack_configure_aap_credential.yml"
ansible-playbook --syntax-check "${ROOT_DIR}/env_slack_validate_webhook.yml"

echo "Installing required Ansible collections"
ansible-galaxy collection install -r "${ROOT_DIR}/collections/requirements.yml"

cat <<'EOF'
Local prerequisites are ready.

Next steps:
1. Export AAP credentials if you want to run bootstrap locally:
   export AAP_URL="https://<your-aap-controller>"
   export AAP_USER="<your-aap-username>"
   export AAP_PASS="<your-password>"
2. Bootstrap AAP assets:
   ansible-playbook bootstrap_tam_day_assets.yml \
     -e "aap_url=${AAP_URL}" \
     -e "aap_user=${AAP_USER}" \
     -e "aap_pass=${AAP_PASS}"
3. In AAP, launch the AAP_Patch environment templates to build AWS, ServiceNow, Slack, and host setup.
EOF
