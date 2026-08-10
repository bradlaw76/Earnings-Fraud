# Project Guidelines

## Primary Workflow
This repository is a guided Power Platform and Dynamics 365 wizard for VS Code.
When users ask how to use the repo, default to a beginner-safe, step-by-step flow.
Always require planning before build implementation:
- Ask discovery questions first.
- Create or update `spec.md`, `plan.md`, and `tasks.md` before recommending build scripts.
- Only move to bootstrap scripts after requirements and tasks are clear.

## Wizard Behavior
When helping in chat:
- Act like a facilitator, not just a command generator.
- Ask one discovery question at a time when the user is exploring a new app or demo.
- Explain unfamiliar concepts the first time they appear: PAC CLI, Dataverse, solution, unpack/pack, managed vs unmanaged.
- Include validation checkpoints after major actions.
- Prefer the repo guidance in `docs/onboarding.md`, `README.md`, and `requirements/` over inventing new flows.

## Build Sequence
Use this build sequence unless the user has a documented reason to change it:
1. Clone/open repo
2. Install required extensions/tools
3. Run `00-prereq-check.ps1`
4. Run `10-auth-connect.ps1`
5. Complete Spec Kit planning
6. Run scripts `20`, `30`, `40`, `50`, `60` in order
7. Verify in Maker portal
8. Export, unpack, commit, pack, import, validate

## Documentation References
Use and reference these files when relevant:
- `README.md`
- `docs/onboarding.md`
- `docs/build-log.md`
- `requirements/how-to-build-dynamics-model-driven-apps-wizard.md`
- `requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md`

## Editing Expectations
Keep repo changes minimal and practical.
Do not skip beginner explanations.
Do not recommend running build scripts before planning is complete.

## BPF Authoring Guardrails (General)
Use these rules for any wizard-generated Business Process Flow, regardless of scenario, table design, or demo style.

### Start from the planning documents
- Derive BPF stages, branch logic, and required data steps from `spec.md`, `plan.md`, and `tasks.md` before creating the flow.
- Require explicit definitions for: stage names/order, branch predicates, required human decision points, and completion behavior.
- Do not begin BPF implementation if branch criteria are still ambiguous.

### Avoid high-risk implementation patterns
- Do not treat "workflow is active" as completion. Active status alone can still hide broken internals.
- Do not treat "in solution" as completion. Solution membership does not guarantee usable stage/branch content.
- Do not clone unrelated BPF payloads and leave source fields/labels in place.
- Do not patch only one payload surface (`clientdata` only). If editing by API, keep `clientdata`, `uidata`, and `xaml` aligned.
- Do not do naive string replacements for field names. Replace longest keys first to avoid substring collisions.
- Do not bind data steps to fields that do not exist on the BPF primary table.

### What works reliably
- Use a two-phase pattern:
	1. Create/activate base BPF in designer.
	2. Run deterministic validation and targeted repair scripts.
- Add a structural validator that checks at minimum:
	- active state
	- solution membership
	- stage count threshold
	- condition count threshold
	- step count sanity
- Verify field existence from Dataverse metadata before applying step mappings.
- Keep data-step mappings deterministic and scriptable so they can be replayed for any design.
- Update stage labels and step labels separately from data bindings; label layers and bindings can drift independently.
- Publish after updates and then verify app linkage (`appmodulecomponents`) for workflow component type 29.

### Error handling and resilience
- Handle Dataverse customization locks (`0x80071151`) with retry/backoff instead of failing fast.
- If designer automation is unstable or partially broken, switch to API/script remediation and re-validate.
- If patching causes invalid attribute errors, stop and inspect exact offending field names before retrying.

### Required evidence before declaring done
- Validation script returns PASS with documented thresholds.
- BPF is active and in the intended solution.
- BPF is linked to the intended app module.
- Stage/condition/step summary is captured in the build log.
- Any threshold decisions (for example 6 vs 7 stages) are explicitly documented in tasks and log entries.