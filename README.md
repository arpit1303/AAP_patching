# AAP End-to-End Patching Demo

Production-style Red Hat Ansible Automation Platform (AAP) patching workflow for Linux estates, including:

- change request orchestration
- pre/post validation
- application-aware patch windows
- AWS snapshot rollback path
- incident + change closure integration
- report generation

This repository is based on the working demo pattern from `christiancruz11/aap_patching` and adapted for `tam_arpit` workflows and `TAM_DAY` labeling in AAP.

## What This Demo Delivers

- **Governed patching:** starts with change request gate (`Create CR - Wait`)
- **Resilient execution:** snapshots before patching, rollback on failure
- **Operational safety:** pre/post OS and app tasks
- **Traceability:** incident creation on failure path, CR closure on completion
- **Visibility:** generated patching report

## Workflow Stages

The `End to End Patching` workflow orchestrates these templates:

1. `Create CR - Wait`
2. `Create Snapshot`
3. `AWS Inventory` sync
4. `Pre Patch Task`
5. `Pre App Tasks`
6. `Apply Patching`
7. `Post Patching Task`
8. `Post App Tasks`
9. `Delete Snapshot`
10. `Generate Report`
11. `Close CR`

Failure branches trigger:

1. `Restore Snapshot`
2. inventory sync
3. `Create Incident Ticket`

## Repository Layout

```text
.
├── apply_patching.yml
├── pre_patch_tasks.yml
├── pre_app_tasks.yml
├── post_patch_tasks.yml
├── post_app_tasks.yml
├── generate_report.yml
├── snapshot_*.yml
├── snow_*.yml
├── collections/
│   └── ansible_collections/demo/...
├── scripts/
│   └── setup_tam_day_aap.sh
└── demo_assets/
    ├── end_to_end_patching_video_script.md
    └── end_to_end_patching_shot_list.csv
```

## Prerequisites (Any Local Laptop)

You can run from macOS, Linux, or Windows with WSL2.

### Required tools

- `git`
- `bash`
- `curl`
- `jq`
- `ansible-core` (recommended)
- `ansible-galaxy` (recommended)

### Verify tools

```bash
git --version
bash --version
curl --version
jq --version
ansible --version
```

## Quick Start (Local Clone)

```bash
git clone https://github.com/arpit1303/AAP_patching.git
cd AAP_patching
git checkout tam_arpit
```

Install required external collections:

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

## Bootstrap AAP Templates + Workflow

Use the provided script to create/update AAP assets with source-consistent names and `TAM_DAY` label.

```bash
chmod +x scripts/setup_tam_day_aap.sh

export AAP_URL="https://<your-aap-controller>"
export AAP_USER="admin"
export AAP_PASS="<your-password>"

./scripts/setup_tam_day_aap.sh
```

### What the bootstrap script creates

- Project: `TAM_DAY AAP Patching`
- Job Templates: source-consistent names (`Create Snapshot`, `Apply Patching`, etc.)
- Workflow Template: `End to End Patching`
- Label on all above: `TAM_DAY`
- Workflow graph edges aligned to end-to-end patching + rollback model

## Required AAP Objects (Expected by Script)

The script expects these existing objects in controller:

- Organization: `Ansible Product Demos (APD)`
- Inventories:
  - `Ansible Product Demos Inventory`
  - `Demo Inventory`
- Inventory Source: `AWS Inventory`
- Execution Environments:
  - `Default execution environment`
  - `Cloud Services Execution Environment`

If your controller uses different names, override environment variables before script run:

```bash
export ORG_NAME="..."
export INVENTORY_MAIN_NAME="..."
export INVENTORY_LOCAL_NAME="..."
export AWS_SOURCE_NAME="..."
export EE_DEFAULT_NAME="..."
export EE_CLOUD_NAME="..."
```

## Run the Demo

1. In AAP UI, open **Templates**.
2. Filter by label `TAM_DAY`.
3. Launch workflow: `End to End Patching`.
4. Default extra vars:

```yaml
_hosts: os_linux
force_failure_apply_patch: false
```

To demonstrate failure/rollback path:

```yaml
_hosts: os_linux
force_failure_apply_patch: true
```

## Professional Demo Assets

Prepared presentation assets are available in:

- `demo_assets/end_to_end_patching_video_script.md`
- `demo_assets/end_to_end_patching_shot_list.csv`

Use these to record a 6-8 minute demo and insert into Google Slides.

## Troubleshooting

- **Project sync fails (`pathspec tam_arpit`)**  
  Ensure branch exists in GitHub and AAP project `scm_branch` is `tam_arpit`.

- **Templates not visible in UI**  
  Clear filters and search by label `TAM_DAY`.

- **Script fails on macOS bash**  
  Current script is bash-3 compatible; rerun from repo root.

- **Missing controller objects**  
  Script exits with object name; create it in AAP or override env variable names.

- **Workflow node missing job template**  
  Re-run `./scripts/setup_tam_day_aap.sh` (idempotent update path).

## Security Notes

- Do not commit AAP, AWS, or ServiceNow credentials.
- Prefer AAP credentials store and encrypted secrets.
- Rotate demo credentials after workshops.

## Maintainer Flow

```bash
git checkout tam_arpit
git pull --rebase
# update files
git add .
git commit -m "Update demo content"
git push origin tam_arpit
```
