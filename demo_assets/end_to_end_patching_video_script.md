# End-to-End Patching Demo Video Script (Professional)

## Target Length
- 6 to 8 minutes

## Audience
- IT leadership, ops engineers, security/compliance stakeholders

## Demo Goal
- Show controlled, auditable, and resilient Linux patching with rollback and incident/change integration.

## Opening (0:00 - 0:30)
"In this demo, we’ll walk through a production-style end-to-end patching workflow in Red Hat Ansible Automation Platform. You’ll see how we orchestrate change creation, pre-checks, patching, post-validation, reporting, and automated failure handling with snapshot restore and incident creation."

## Step 1: Workflow Entry - Create CR - Wait (0:30 - 1:00)
Show: AAP Templates -> `End to End Patching` -> Visualizer.
Narration:
"The workflow starts by creating a ServiceNow change request and waiting for approval. This enforces governance before any system change is performed."

## Step 2: Create Snapshot (1:00 - 1:25)
Show: Node `Create Snapshot`.
Narration:
"Before patching, we create infrastructure snapshots. This gives us a guaranteed rollback point and reduces operational risk."

## Step 3: AWS Inventory Sync (Before) (1:25 - 1:45)
Show: `AWS Inventory` sync node.
Narration:
"We refresh cloud inventory to make sure host state and targeting are current before execution."

## Step 4: Pre Patch Task (1:45 - 2:10)
Show: Job output snippets.
Narration:
"Pre-patching tasks validate baseline conditions and capture pre-change context. This improves reliability and auditability."

## Step 5: Pre App Tasks (2:10 - 2:35)
Show: App stop/verification logic.
Narration:
"Application-aware pre-tasks verify app health and stop services gracefully to avoid data corruption during patching."

## Step 6: Apply Patching (2:35 - 3:15)
Show: package update execution results.
Narration:
"We apply OS patches in a controlled playbook stage, with host-level status tracking for success and failure."

## Step 7: Post Patching Task (3:15 - 3:35)
Show: Post-check tasks.
Narration:
"Post-patching checks confirm OS-level consistency and expected completion markers."

## Step 8: Post App Tasks (3:35 - 4:00)
Show: App start and validation tasks.
Narration:
"Services are restarted and validated so we verify business readiness, not just package installation."

## Step 9: Delete Snapshot + Inventory Sync (4:00 - 4:25)
Show: `Delete Snapshot` and second `AWS Inventory` node.
Narration:
"On successful completion, snapshots are cleaned up and inventory is refreshed to keep the environment accurate and cost-efficient."

## Step 10: Generate Report (4:25 - 4:50)
Show: Report job and generated report URL/artifact.
Narration:
"A structured report is generated for operational handoff, audit evidence, and leadership visibility."

## Step 11: Close CR (4:50 - 5:05)
Show: `Close CR` node.
Narration:
"Finally, the approved change is programmatically closed with outcome status, completing the governance loop."

## Failure Path Demo (5:05 - 6:20)
Show: force failure in `Apply Patching` (set `force_failure_apply_patch: true` at launch).
Narration:
"If patching fails, the workflow automatically restores from snapshot, syncs inventory, opens an incident ticket, and preserves traceability. This demonstrates resilient automation, not just task automation."

## Closing (6:20 - 6:45)
"This workflow combines compliance, reliability, and speed. The key value is consistent execution with built-in controls, rollback, and reporting from a single orchestrated pipeline."

## Presenter Tips
- Keep zoom at 110-125% for readability.
- Pause 1 second before each node explanation.
- Use a stable cursor path; avoid rapid mouse movement.
- Highlight labels (`AAP_Patch`) to identify demo assets quickly.
