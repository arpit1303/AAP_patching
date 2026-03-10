#!/usr/bin/env bash
set -euo pipefail

# Replicates the source TAM demo assets in a target AAP controller with TAM_DAY naming.

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd curl
require_cmd jq

AAP_URL="${AAP_URL:-https://aap-aap.apps.cluster-slps4-1.dynamic.redhatworkshops.io}"
AAP_USER="${AAP_USER:-admin}"
AAP_PASS="${AAP_PASS:-}"

ORG_NAME="${ORG_NAME:-Ansible Product Demos (APD)}"
PROJECT_NAME="${PROJECT_NAME:-TAM_DAY AAP Patching}"
PROJECT_SCM_URL="${PROJECT_SCM_URL:-https://github.com/christiancruz11/aap_patching.git}"
PROJECT_SCM_BRANCH="${PROJECT_SCM_BRANCH:-tam}"

INVENTORY_MAIN_NAME="${INVENTORY_MAIN_NAME:-Ansible Product Demos Inventory}"
INVENTORY_LOCAL_NAME="${INVENTORY_LOCAL_NAME:-Demo Inventory}"
AWS_SOURCE_NAME="${AWS_SOURCE_NAME:-AWS Inventory}"

EE_DEFAULT_NAME="${EE_DEFAULT_NAME:-Default execution environment}"
EE_CLOUD_NAME="${EE_CLOUD_NAME:-Cloud Services Execution Environment}"

WF_NAME="${WF_NAME:-TAM_DAY | End to End Patching}"
WF_EXTRA_VARS="${WF_EXTRA_VARS:-_hosts: os_linux
force_failure_apply_patch: false}"

if [[ -z "${AAP_PASS}" ]]; then
  echo "Set AAP_PASS before running (example: export AAP_PASS='...')." >&2
  exit 1
fi

api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"

  if [[ -n "$body" ]]; then
    curl -sk -u "${AAP_USER}:${AAP_PASS}" \
      -H "Content-Type: application/json" \
      -X "$method" \
      -d "$body" \
      "${AAP_URL}${path}"
  else
    curl -sk -u "${AAP_USER}:${AAP_PASS}" \
      -H "Content-Type: application/json" \
      -X "$method" \
      "${AAP_URL}${path}"
  fi
}

lookup_id_by_name() {
  local endpoint="$1"
  local name="$2"
  api GET "${endpoint}?page_size=200" | jq -r --arg n "$name" '.results[] | select(.name == $n) | .id' | head -n1
}

ensure_project() {
  local project_id
  project_id="$(lookup_id_by_name "/api/controller/v2/projects/" "${PROJECT_NAME}")"

  local payload
  payload="$(jq -n \
    --arg name "${PROJECT_NAME}" \
    --arg scm_url "${PROJECT_SCM_URL}" \
    --arg scm_branch "${PROJECT_SCM_BRANCH}" \
    --argjson org_id "${ORG_ID}" \
    --argjson ee_id "${EE_DEFAULT_ID}" \
    '{
      name: $name,
      organization: $org_id,
      scm_type: "git",
      scm_url: $scm_url,
      scm_branch: $scm_branch,
      scm_update_on_launch: true,
      default_environment: $ee_id
    }')"

  if [[ -z "${project_id}" ]]; then
    project_id="$(api POST "/api/controller/v2/projects/" "${payload}" | jq -r '.id')"
    echo "Created project: ${PROJECT_NAME} (id=${project_id})"
  else
    api PATCH "/api/controller/v2/projects/${project_id}/" "${payload}" >/dev/null
    echo "Updated project: ${PROJECT_NAME} (id=${project_id})"
  fi

  PROJECT_ID="${project_id}"
  api POST "/api/controller/v2/projects/${PROJECT_ID}/update/" >/dev/null || true
}

ensure_jt() {
  local name="$1"
  local playbook="$2"
  local inventory_id="$3"
  local ee_id="$4"
  local limit="$5"

  local jt_id
  jt_id="$(lookup_id_by_name "/api/controller/v2/job_templates/" "${name}")"

  local payload
  if [[ "${ee_id}" == "null" ]]; then
    payload="$(jq -n \
      --arg name "$name" \
      --arg playbook "$playbook" \
      --arg limit "$limit" \
      --argjson inventory "$inventory_id" \
      --argjson project "$PROJECT_ID" \
      '{
        name: $name,
        job_type: "run",
        inventory: $inventory,
        project: $project,
        playbook: $playbook,
        limit: $limit
      }')"
  else
    payload="$(jq -n \
      --arg name "$name" \
      --arg playbook "$playbook" \
      --arg limit "$limit" \
      --argjson inventory "$inventory_id" \
      --argjson project "$PROJECT_ID" \
      --argjson ee "$ee_id" \
      '{
        name: $name,
        job_type: "run",
        inventory: $inventory,
        project: $project,
        playbook: $playbook,
        execution_environment: $ee,
        limit: $limit
      }')"
  fi

  if [[ -z "${jt_id}" ]]; then
    jt_id="$(api POST "/api/controller/v2/job_templates/" "${payload}" | jq -r '.id')"
    echo "Created JT: ${name} (id=${jt_id})"
  else
    api PATCH "/api/controller/v2/job_templates/${jt_id}/" "${payload}" >/dev/null
    echo "Updated JT: ${name} (id=${jt_id})"
  fi

  JT_IDS["$name"]="${jt_id}"
}

ensure_workflow() {
  local wf_id
  wf_id="$(lookup_id_by_name "/api/controller/v2/workflow_job_templates/" "${WF_NAME}")"

  local payload
  payload="$(jq -n \
    --arg name "${WF_NAME}" \
    --argjson org "${ORG_ID}" \
    --arg extra_vars "${WF_EXTRA_VARS}" \
    '{
      name: $name,
      organization: $org,
      ask_variables_on_launch: true,
      extra_vars: $extra_vars
    }')"

  if [[ -z "${wf_id}" ]]; then
    wf_id="$(api POST "/api/controller/v2/workflow_job_templates/" "${payload}" | jq -r '.id')"
    echo "Created workflow: ${WF_NAME} (id=${wf_id})"
  else
    api PATCH "/api/controller/v2/workflow_job_templates/${wf_id}/" "${payload}" >/dev/null
    echo "Updated workflow: ${WF_NAME} (id=${wf_id})"
  fi

  WF_ID="${wf_id}"
}

delete_existing_nodes() {
  local ids
  ids="$(api GET "/api/controller/v2/workflow_job_templates/${WF_ID}/workflow_nodes/?page_size=200" | jq -r '.results[].id')"
  if [[ -n "${ids}" ]]; then
    while IFS= read -r id; do
      api DELETE "/api/controller/v2/workflow_job_template_nodes/${id}/" >/dev/null
    done <<< "${ids}"
  fi
}

create_node() {
  local key="$1"
  local ujt_id="$2"
  local identifier="$3"
  local payload
  payload="$(jq -n --argjson u "$ujt_id" --arg i "$identifier" '{unified_job_template:$u,identifier:$i}')"
  local node_id
  node_id="$(api POST "/api/controller/v2/workflow_job_templates/${WF_ID}/workflow_nodes/" "${payload}" | jq -r '.id')"
  NODE_IDS["$key"]="${node_id}"
}

link_nodes() {
  local from_key="$1"
  local relation="$2"
  local to_key="$3"
  local from_id="${NODE_IDS[$from_key]}"
  local to_id="${NODE_IDS[$to_key]}"
  api POST "/api/controller/v2/workflow_job_template_nodes/${from_id}/${relation}/" "$(jq -n --argjson id "$to_id" '{id:$id}')" >/dev/null
}

declare -A JT_IDS
declare -A NODE_IDS

ORG_ID="$(lookup_id_by_name "/api/controller/v2/organizations/" "${ORG_NAME}")"
INV_MAIN_ID="$(lookup_id_by_name "/api/controller/v2/inventories/" "${INVENTORY_MAIN_NAME}")"
INV_LOCAL_ID="$(lookup_id_by_name "/api/controller/v2/inventories/" "${INVENTORY_LOCAL_NAME}")"
AWS_SOURCE_ID="$(lookup_id_by_name "/api/controller/v2/inventory_sources/" "${AWS_SOURCE_NAME}")"
EE_DEFAULT_ID="$(lookup_id_by_name "/api/controller/v2/execution_environments/" "${EE_DEFAULT_NAME}")"
EE_CLOUD_ID="$(lookup_id_by_name "/api/controller/v2/execution_environments/" "${EE_CLOUD_NAME}")"

for required in ORG_ID INV_MAIN_ID INV_LOCAL_ID AWS_SOURCE_ID EE_DEFAULT_ID EE_CLOUD_ID; do
  if [[ -z "${!required}" ]]; then
    echo "Missing required controller object: ${required}" >&2
    exit 1
  fi
done

ensure_project

ensure_jt "TAM_DAY | Create Snapshot" "snapshot_create.yml" "${INV_MAIN_ID}" "${EE_CLOUD_ID}" ""
ensure_jt "TAM_DAY | Pre Patch Task" "pre_patch_tasks.yml" "${INV_MAIN_ID}" "${EE_DEFAULT_ID}" ""
ensure_jt "TAM_DAY | Pre App Tasks" "pre_app_tasks.yml" "${INV_MAIN_ID}" "${EE_DEFAULT_ID}" ""
ensure_jt "TAM_DAY | Apply Patching" "apply_patching.yml" "${INV_MAIN_ID}" "${EE_DEFAULT_ID}" ""
ensure_jt "TAM_DAY | Post Patching Task" "post_patch_tasks.yml" "${INV_MAIN_ID}" "null" ""
ensure_jt "TAM_DAY | Post App Tasks" "post_app_tasks.yml" "${INV_MAIN_ID}" "null" ""
ensure_jt "TAM_DAY | Delete Snapshot" "snapshot_delete.yml" "${INV_MAIN_ID}" "${EE_CLOUD_ID}" ""
ensure_jt "TAM_DAY | Generate Report" "generate_report.yml" "${INV_MAIN_ID}" "${EE_DEFAULT_ID}" ""
ensure_jt "TAM_DAY | Create CR - Wait" "snow_create_cr_wait.yml" "${INV_LOCAL_ID}" "null" "localhost"
ensure_jt "TAM_DAY | Create Incident Ticket" "snow_create_ticket.yml" "${INV_MAIN_ID}" "null" "os_linux"
ensure_jt "TAM_DAY | Close CR" "snow_close_cr.yml" "${INV_LOCAL_ID}" "${EE_DEFAULT_ID}" ""
ensure_jt "TAM_DAY | Restore Snapshot" "snapshot_restore.yml" "${INV_MAIN_ID}" "${EE_CLOUD_ID}" ""
ensure_jt "TAM_DAY | Create CR - Wait (Slack)" "snow_create_cr_slack_wait.yml" "${INV_LOCAL_ID}" "${EE_DEFAULT_ID}" "localhost"

ensure_workflow
delete_existing_nodes

create_node "create_cr_wait" "${JT_IDS["TAM_DAY | Create CR - Wait"]}" "tam-day-create-cr-wait"
create_node "create_snapshot" "${JT_IDS["TAM_DAY | Create Snapshot"]}" "tam-day-create-snapshot"
create_node "sync_before" "${AWS_SOURCE_ID}" "tam-day-aws-sync-before"
create_node "pre_patch" "${JT_IDS["TAM_DAY | Pre Patch Task"]}" "tam-day-pre-patch"
create_node "pre_app" "${JT_IDS["TAM_DAY | Pre App Tasks"]}" "tam-day-pre-app"
create_node "apply_patch" "${JT_IDS["TAM_DAY | Apply Patching"]}" "tam-day-apply-patching"
create_node "post_patch" "${JT_IDS["TAM_DAY | Post Patching Task"]}" "tam-day-post-patching"
create_node "post_app" "${JT_IDS["TAM_DAY | Post App Tasks"]}" "tam-day-post-app"
create_node "delete_snapshot" "${JT_IDS["TAM_DAY | Delete Snapshot"]}" "tam-day-delete-snapshot"
create_node "generate_report" "${JT_IDS["TAM_DAY | Generate Report"]}" "tam-day-generate-report"
create_node "close_cr" "${JT_IDS["TAM_DAY | Close CR"]}" "tam-day-close-cr"
create_node "incident_early" "${JT_IDS["TAM_DAY | Create Incident Ticket"]}" "tam-day-incident-early"
create_node "restore_snapshot" "${JT_IDS["TAM_DAY | Restore Snapshot"]}" "tam-day-restore-snapshot"
create_node "sync_after" "${AWS_SOURCE_ID}" "tam-day-aws-sync-after"
create_node "incident_after_restore" "${JT_IDS["TAM_DAY | Create Incident Ticket"]}" "tam-day-incident-after-restore"

link_nodes "create_cr_wait" "success_nodes" "create_snapshot"

link_nodes "create_snapshot" "always_nodes" "sync_before"
link_nodes "create_snapshot" "failure_nodes" "incident_early"

link_nodes "sync_before" "always_nodes" "pre_patch"
link_nodes "sync_before" "failure_nodes" "incident_early"

link_nodes "pre_patch" "success_nodes" "pre_app"
link_nodes "pre_patch" "failure_nodes" "incident_early"

link_nodes "pre_app" "success_nodes" "apply_patch"
link_nodes "pre_app" "failure_nodes" "incident_early"

link_nodes "apply_patch" "success_nodes" "post_patch"
link_nodes "apply_patch" "failure_nodes" "restore_snapshot"

link_nodes "post_patch" "success_nodes" "post_app"
link_nodes "post_patch" "failure_nodes" "restore_snapshot"

link_nodes "post_app" "success_nodes" "delete_snapshot"
link_nodes "post_app" "success_nodes" "sync_after"
link_nodes "post_app" "failure_nodes" "restore_snapshot"

link_nodes "delete_snapshot" "always_nodes" "generate_report"

link_nodes "restore_snapshot" "always_nodes" "sync_after"
link_nodes "restore_snapshot" "always_nodes" "incident_after_restore"

link_nodes "sync_after" "always_nodes" "generate_report"

link_nodes "generate_report" "always_nodes" "close_cr"

echo
echo "TAM_DAY assets are ready in ${AAP_URL}:"
echo "- Project: ${PROJECT_NAME}"
echo "- Workflow: ${WF_NAME}"
echo "- Job templates: ${#JT_IDS[@]}"
