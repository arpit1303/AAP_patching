# AAP End-to-End Patching Demo

Production-style Red Hat Ansible Automation Platform (AAP) patching workflow for Linux estates, including:

- change request orchestration
- pre/post validation
- application-aware patch windows
- AWS snapshot rollback path
- incident + change closure integration
- Slack notifications for change, incident, and approval events
- report generation

## What This Demo Delivers

- **Governed patching:** starts with change request gate (`Create CR - Wait`)
- **Resilient execution:** snapshots before patching, rollback on failure
- **Operational safety:** pre/post OS and app tasks
- **Traceability:** incident creation on failure path, CR closure on completion
- **Notifications:** ServiceNow approval, incident, and closure events can be mirrored into any Slack workspace through a webhook
- **Visibility:** generated patching report

## Follow This Approach

- Controller-side `extra_vars` are generated from code instead of maintained manually in AAP.
- ServiceNow integration is encapsulated as reusable AAP templates for credential setup and connectivity validation.
- Slack notification delivery is now generic and webhook-based, so any Slack workspace can consume the workflow events without editing role code.
- Local laptop bootstrap is reduced to dependency install, syntax validation, and AAP asset bootstrap through versioned scripts.
- Environment build steps for AWS, host preparation, ServiceNow, and Slack are exposed as `AAP_Patch`-labeled templates rather than tribal knowledge.

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
├── bootstrap_tam_day_assets.yml
├── env_slack_*.yml
├── scripts/
│   ├── setup_local_demo.sh
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
git checkout aap_patch
```

Install required external collections:

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

Or use the local wrapper:

```bash
./scripts/setup_local_demo.sh
```

This runs dependency validation, installs the required collections, and syntax-checks the local bootstrap content.

If you prefer `make`, optional wrapper targets are also provided:

```bash
make deps
make validate
```

## Run From a Fork

Use this minimum path after forking the repository:

1. Fork the repo in GitHub.
2. Clone the fork locally.
3. Run `./scripts/setup_local_demo.sh`.
4. Point AAP project SCM to the fork and branch.
5. Run the local bootstrap command below or launch `Bootstrap AAP_Patch AAP Assets` from AAP.
6. Use the generated `AAP_Patch` environment templates to build AWS, ServiceNow, Slack, and host prep.
7. Launch `End to End Patching`.

The only required external accounts are:

- an AAP controller
- an AWS account with permissions to create keypairs, VPC resources, and EC2 instances
- a ServiceNow instance
- a Slack incoming webhook in the workspace/channel you want to notify

Local bootstrap command:

```bash
export AAP_URL="https://<your-aap-controller>"
export AAP_USER="admin"
export AAP_PASS="<your-password>"
ansible-playbook bootstrap_tam_day_assets.yml \
  -e "aap_url=${AAP_URL}" \
  -e "aap_user=${AAP_USER}" \
  -e "aap_pass=${AAP_PASS}"
```

## Bootstrap AAP Templates + Workflow (AAP Job Template)

Automate bootstrap through an AAP Job Template using playbook `bootstrap_tam_day_assets.yml`.

```bash
# local optional validation run
ansible-playbook bootstrap_tam_day_assets.yml \
  -e "aap_url=https://<your-aap-controller>" \
  -e "aap_user=admin" \
  -e "aap_pass=<your-password>"
```

### Create the bootstrap Job Template in AAP

1. Sync project `TAM_AAP_Patching` (branch `aap_patch`).
2. Create Job Template:
   - Name: `Bootstrap AAP_Patch AAP Assets`
   - Project: `TAM_AAP_Patching`
   - Playbook: `bootstrap_tam_day_assets.yml`
   - Inventory: `Demo Inventory`
   - Execution Environment: `Default execution environment`
   - Options: enable **Prompt on launch** for Variables
3. Add label `AAP_Patch` to the template.
4. Launch with variables:

```yaml
aap_url: "https://<your-aap-controller>"
aap_user: "admin"
aap_pass: "<your-password>"
template_label: "AAP_Patch"
workflow_name: "End to End Patching"
patch_target_hosts: "os_linux"
report_server_host: "rhel9app"
change_environment_name: "Dev"
```

### Create these objects with the bootstrap template

- Project: `AAP_Patch AAP Patching`
  Source: `https://github.com/arpit1303/AAP_patching` branch `aap_patch`
- Job Templates: source-consistent names (`Create Snapshot`, `Apply Patching`, etc.)
- Environment Templates:
  - `Environment | AWS | Create Keypair`
  - `Environment | AWS | Create Network`
  - `Environment | AWS | Create VM`
  - `Environment | Inventory | Set App Deployment`
  - `Environment | Linux | Prepare Web Hosts`
  - `Environment | Linux | Prepare DB Hosts`
  - `Environment | ServiceNow | Configure AAP Credential`
  - `Environment | ServiceNow | Validate Instance`
  - `Environment | Slack | Configure AAP Credential`
  - `Environment | Slack | Validate Webhook`
- Workflow Template: `End to End Patching`
- Label on all above: `AAP_Patch`
- Template-level `extra_vars` that were previously maintained manually in AAP
- Workflow graph edges aligned to end-to-end patching + rollback model

### Use the default template variables

Use the bootstrap automation to write these controller-side `extra_vars` directly into the `AAP_Patch` templates.

- `Create Snapshot`
  Sets `_hosts: os_linux` and initializes `patch_progress` / `patch_stage` for `rhel8app`, `rhel8db`, `rhel9app`, and `rhel9db`.
- `Pre Patch Task`
  Sets `_hosts: os_linux`.
- `Pre App Tasks`
  Sets `_hosts: os_linux`.
- `Post Patching Task`
  Sets `_hosts: os_linux`.
- `Post App Tasks`
  Sets `_hosts: os_linux`.
- `Generate Report`
  Sets `_hosts: os_linux` and `report_server: rhel9app`.
- `Create CR - Wait`
  Sets the ServiceNow `cr_short_description` and `cr_description`.
- `End to End Patching`
  Sets workflow `extra_vars` to:

```yaml
_hosts: os_linux
force_failure_apply_patch: true
```

### Override the default values

You can override these values when launching `Bootstrap AAP_Patch AAP Assets`:

```yaml
patch_target_hosts: "os_linux"
report_server_host: "rhel9app"
cr_short_description: "Patch Change Request rhel8app, rhel8db, rhel9app, rhel9db"
cr_description: "TAM requests rhel8app, rhel8db, rhel9app, rhel9db servers in Dev to patch"
workflow_extra_vars: |
  _hosts: os_linux
  force_failure_apply_patch: true
create_snapshot_extra_vars: |
  _hosts: os_linux
  patch_progress:
    rhel8app: success
    rhel8db: success
    rhel9app: success
    rhel9db: success
  patch_stage:
    rhel8app: snapshot_create
    rhel8db: snapshot_create
    rhel9app: snapshot_create
    rhel9db: snapshot_create
```

## Required AAP Objects (Expected by Bootstrap Playbook)

The bootstrap playbook expects these existing objects in controller:

- Organization: `Ansible Product Demos (APD)`
- Inventories:
  - `Ansible Product Demos Inventory`
  - `Demo Inventory`
- Inventory Source: `AWS Inventory`
- Execution Environments:
  - `Default execution environment`
  - `Cloud Services Execution Environment`

If your controller uses different names, pass overrides as extra vars at launch:

```bash
-e "org_name=..."
-e "inventory_main_name=..."
-e "inventory_local_name=..."
-e "aws_source_name=..."
-e "ee_default_name=..."
-e "ee_cloud_name=..."
```

## Run the Demo

1. In AAP UI, open **Templates**.
2. Filter by label `AAP_Patch`.
3. Launch workflow: `End to End Patching`.
4. Default extra vars:

```yaml
_hosts: os_linux
force_failure_apply_patch: true
```

To demonstrate failure/rollback path:

```yaml
_hosts: os_linux
force_failure_apply_patch: true
```

## Environment Preparation

If you do not already have the APD AWS demo environment, use bootstrap template `Bootstrap AAP_Patch AAP Assets` to create the `AAP_Patch`-labeled setup templates for the required AWS and host preparation work.

Recommended order:

1. `Environment | AWS | Create Keypair`
2. `Environment | AWS | Create Network`
3. `Environment | AWS | Create VM`
4. `Environment | Inventory | Set App Deployment`
5. `Environment | Linux | Prepare Web Hosts`
6. `Environment | Inventory | Set App Deployment`
7. `Environment | Linux | Prepare DB Hosts`
8. `Environment | ServiceNow | Configure AAP Credential`
9. `Environment | ServiceNow | Validate Instance`
10. `Environment | Slack | Configure AAP Credential`
11. `Environment | Slack | Validate Webhook`

### Generate SSH key locally

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/aws-test-key -C "aws-test-key"
```

Use the public key from `~/.ssh/aws-test-key.pub` when launching `Environment | AWS | Create Keypair`.

### Template defaults

- `Environment | AWS | Create Keypair`
  Defaults:

```yaml
create_vm_aws_region: us-east-1
aws_key_name: aws-test-key
aws_keypair_owner: TAM
aws_public_key: ""
```

- `Environment | AWS | Create Network`
  Defaults:

```yaml
create_vm_aws_region: us-east-1
aws_owner_tag: TAM
aws_vpc_name: aws-test-vpc
aws_subnet_name: aws-test-subnet
aws_securitygroup_name: aws-test-sg
```

- `Environment | AWS | Create VM`
  Run once for each VM (`rhel9app`, `rhel9db`, `rhel8app`, `rhel8db`).
  Defaults:

```yaml
create_vm_aws_region: us-east-1
create_vm_vm_name: rhel9app
create_vm_vm_owner: TAM
create_vm_vm_deployment: default
create_vm_vm_purpose: demo
create_vm_vm_environment: Dev
vm_blueprint: rhel9
create_vm_aws_vpc_subnet_name: aws-test-subnet
create_vm_aws_securitygroup_name: aws-test-sg
create_vm_aws_keypair_name: aws-test-key
```

- `Environment | Inventory | Set App Deployment`
  Use once for app hosts and once for DB hosts.
  App example:

```yaml
controller_url: "https://<your-aap-controller>"
controller_user: "admin"
controller_pass: "<your-password>"
inventory_name: "Ansible Product Demos Inventory"
target_hosts: "rhel9app,rhel8app"
app_deployment: "web"
```

  DB example:

```yaml
controller_url: "https://<your-aap-controller>"
controller_user: "admin"
controller_pass: "<your-password>"
inventory_name: "Ansible Product Demos Inventory"
target_hosts: "rhel9db,rhel8db"
app_deployment: "database"
```

- `Environment | Linux | Prepare Web Hosts`
  Installs and starts `httpd`, places a valid `/var/www/html/index.html`, and verifies HTTP `200`.

- `Environment | Linux | Prepare DB Hosts`
  Installs `postgresql-server` and `postgresql-contrib`, initializes the database if needed, and enables `postgresql`.

### Credentials required for setup templates

- AWS templates should be launched with an AWS credential attached.
- Linux host prep templates should be launched with your machine credential for the EC2 hosts.
- `Environment | Inventory | Set App Deployment` uses controller credentials passed at launch as variables.
- `Environment | Slack | Validate Webhook` should be launched with the `Slack Webhook` credential attached, unless `slack_webhook_url` is passed directly at launch.

## ServiceNow Setup

Use the `AAP_Patch` ServiceNow templates to automate AAP credential setup and connectivity validation. Create the ServiceNow SaaS instance separately if you do not already have one.

### Gather these ServiceNow values

If you are following the same demo pattern, use:

- ServiceNow host: `https://dev366437.service-now.com/`
- ServiceNow username: `admin`
- Credential name in AAP: `ServiceNow`
- Credential type in AAP: `ServiceNow` (custom cloud credential type with `SN_HOST`, `SN_USERNAME`, `SN_PASSWORD` environment injection)

Do not expect AAP to reveal the stored ServiceNow password. Obtain it from the instance owner or use your own ServiceNow instance.

### If you need your own ServiceNow instance

Use one of these paths:

- Request an instance from your organization
- Create a ServiceNow Personal Developer Instance (PDI)

Once you have the URL, username, and password, use the templates below.

### Run these ServiceNow templates

- `Environment | ServiceNow | Configure AAP Credential`
  Creates or updates the custom ServiceNow credential type if needed and then creates/updates the `ServiceNow` credential in AAP.
  Defaults:

```yaml
controller_url: "https://<your-aap-controller>"
controller_user: "admin"
controller_pass: "<your-password>"
organization_name: "Ansible Product Demos (APD)"
servicenow_credential_name: "ServiceNow"
servicenow_host: "https://dev366437.service-now.com/"
servicenow_username: "admin"
servicenow_password: "<your-servicenow-password>"
```

- `Environment | ServiceNow | Validate Instance`
  Launch this with the ServiceNow credential attached. It validates API connectivity against `/api/now/table/sys_user`.
  Defaults:

```yaml
servicenow_validate_certs: true
```

### ServiceNow expectations in the patching workflow

- Change request templates use `assignment_group: CAB Approval`
- Incident and change operations are executed through the `servicenow.itsm` collection
- If your instance uses different approval groups or workflow states, adjust the files under `collections/ansible_collections/demo/process/roles/`

## Slack Setup

Slack delivery is now generic. It uses an incoming webhook credential, so the same repo works with any Slack workspace where you can create a webhook.

### Create the Slack webhook

1. Create or select a Slack app in the target workspace.
2. Enable Incoming Webhooks.
3. Add a webhook for the target channel.
4. Copy the webhook URL.
5. Decide whether to keep the default destination channel at the webhook level or override it in AAP with `slack_channel`.

### Run these Slack templates

- `Environment | Slack | Configure AAP Credential`
  Creates or updates the custom `Slack Webhook` credential type and the `Slack Webhook` credential in AAP.
  Defaults:

```yaml
controller_url: "https://<your-aap-controller>"
controller_user: "admin"
controller_pass: "<your-password>"
organization_name: "Ansible Product Demos (APD)"
slack_credential_name: "Slack Webhook"
slack_webhook_url: "https://hooks.slack.com/services/..."
slack_channel: "patching"
slack_username: "AAP"
```

- `Environment | Slack | Validate Webhook`
  Sends a test message to the webhook.
  Defaults:

```yaml
slack_message: "AAP_Patch Slack webhook validation message"
```

### What goes to Slack

When the Slack credential is attached to the workflow-related templates, these events are pushed to Slack:

- change request created and waiting for approval
- change request approved
- incident created
- change request closed

This allows approval and operations status to be followed from Slack while the source of truth remains ServiceNow.

## Step-by-Step Demo Execution

### Scenario 1: Full green-path demo

1. Run all environment templates in the recommended order.
2. Verify the 4 EC2 instances exist in inventory.
3. Verify app hosts have `app_deployment: web` and DB hosts have `app_deployment: database`.
4. Validate ServiceNow connectivity.
5. Validate Slack delivery.
6. Launch `End to End Patching` with:

```yaml
_hosts: os_linux
force_failure_apply_patch: false
```

Expected outcome:

- ServiceNow CR created
- Slack approval/request notifications sent
- snapshots created
- pre/app/post checks complete
- report generated
- CR closed

### Scenario 2: Rollback and incident path

Launch `End to End Patching` with:

```yaml
_hosts: os_linux
force_failure_apply_patch: true
```

Expected outcome:

- patching fails at the controlled failure point
- snapshot restore path runs
- incident is created in ServiceNow
- incident notification is sent to Slack
- report and closure logic complete according to workflow branch design

### Scenario 3: ServiceNow and Slack validation only

1. Launch `Environment | ServiceNow | Configure AAP Credential`
2. Launch `Environment | ServiceNow | Validate Instance`
3. Launch `Environment | Slack | Configure AAP Credential`
4. Launch `Environment | Slack | Validate Webhook`

Use this path to validate integrations before provisioning AWS or running the full patching workflow.

### Scenario 4: AWS and host preparation only

1. Create keypair.
2. Create network.
3. Create four VMs.
4. Set `app_deployment` values.
5. Prepare web hosts.
6. Prepare DB hosts.

Use this when you want to prove the environment automation independently of patching governance.

## Professional Demo Assets

Prepared presentation assets are available in:

- `demo_assets/end_to_end_patching_video_script.md`
- `demo_assets/end_to_end_patching_shot_list.csv`

Use these to record a 6-8 minute demo and insert into Google Slides.

## Troubleshooting

- **Project sync fails (`pathspec aap_patch`)**  
  Ensure branch exists in GitHub and AAP project `scm_branch` is `aap_patch`.

- **Templates not visible in UI**  
  Clear filters and search by label `AAP_Patch`.

- **Bootstrap template fails with missing AAP credentials**  
  Provide `aap_url`, `aap_user`, and `aap_pass` as launch variables.

- **Missing controller objects**  
  Script exits with object name; create it in AAP or override env variable names.

- **Workflow node missing job template**  
  Re-run template `Bootstrap AAP_Patch AAP Assets` (idempotent update path).

- **Slack messages do not appear**  
  Re-run `Environment | Slack | Validate Webhook` and confirm the webhook URL, workspace app permissions, and optional `slack_channel` override.

- **ServiceNow records are created but Slack is silent**  
  Confirm the `Slack Webhook` credential is attached to `Create CR - Wait`, `Create CR - Wait (Slack)`, `Create Incident Ticket`, and `Close CR`.

## Security Notes

- Do not commit AAP, AWS, ServiceNow, or Slack webhook credentials.
- Prefer AAP credentials store and encrypted secrets.
- Rotate demo credentials after workshops.

## Maintainer Flow

```bash
git checkout aap_patch
git pull --rebase
# update files
git add .
git commit -m "Update demo content"
git push origin aap_patch
```
