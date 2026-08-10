# plan.md

## Build Approach

- Platform area: Dynamics 365 Customer Service
- Environment: <https://healthconnectcenter.crm.dynamics.com>
- Solution type: Unmanaged
- Anchor model: OOB Case (`incident`) as the primary lifecycle record

## Proposed Workstreams

1. Discovery review and approval
2. Dataverse schema expansion (review type, referral source, allegation type, risk/confidence, outcome fields)
3. Forms/views/pages/app experience design aligned to case anchor
4. Flow/copilot automation design with AI-assisted triage and human-review guardrails
5. Demo data planning
6. Solution export/unpack/git workflow
7. Validation and handoff
8. Choice visual semantics: apply accessible colors to each custom choice option and retain Fluent icon mappings for a future custom grid renderer.
9. Case lifecycle BPF: create, activate, solution-install, and expose the Earnings Fraud Case Review BPF for `incident`.

## Earnings Fraud Case Review BPF Design

- Process name: `Earnings Fraud Case Review`
- Base table: OOB Case (`incident`)
- Target solution: `FederalEarningsFraud`
- Target app: Earnings Integrity V2 Demo App
- Completion: manual BPF Finish after a human records case disposition and final determination; do not automatically resolve the Case.

### Stages and routing

1. Intake — review type, referral source, allegation type, and discrepancy type.
2. Risk Triage — risk rating, risk score, confidence level, human-review requirement, and supervisor-review requirement.
3. Evidence Validation — evidence status, identity validation, and beneficiary response status.
4. Earnings Analysis — fraud likelihood and confidence score, with related records reviewed from Case-form subgrids.
5. Conditional Supervisor Review — only when `earnint_supervisorreviewrequired = Yes`; requires `earnint_supervisorapproval`.
6. Disposition — requires `earnint_casedisposition` and `earnint_finaldetermination`.
7. Complete Review — no automation; analyst finishes the BPF.

Use one boolean predicate for the conditional path. Do not add compound AI/risk-score branch logic. AI output fields are informational and cannot be required steps, approval gates, or autonomous decision inputs.

### Installation approach

1. Create the BPF in the Power Apps process designer within `FederalEarningsFraud`, then activate it.
2. Enable it for Case records in the Earnings Integrity V2 Demo App and publish the app.
3. Run `100-install-earnings-fraud-case-bpf.ps1` to verify the activated category-4 workflow is based on `incident` and add it idempotently as solution component type 29.
4. Export/unpack the unmanaged solution so the BPF workflow and process-stage artifacts are versioned; then pack/import for portability validation.

The installer deliberately validates and solution-installs an existing designer-authored process. It does not create unsupported `workflow.clientdata` or process-stage serialization through the Web API.

## Risks to Resolve

- Confirm environment availability and permissions.
- Confirm entity scope and artifact count.
- Confirm whether demo data must be scripted or manual.
- Confirm report scope for critical tables and report placement decisions.
- Keep automation messaging non-adjudicative; avoid implying AI makes final determinations.

## Validation Plan

- Verify artifacts in Maker portal.
- Verify solution export/unpack succeeds.
- Verify git changes are reviewable.
- Verify import into target environment succeeds.
- Verify new option-set values appear on forms and map correctly in web resources.
- Verify AI flow template fields and prompt outputs match payload schema.
- Verify all custom choice options have a non-empty semantic color and that the icon mapping report covers every option.
- Verify the active BPF workflow has category 4, primary entity `incident`, and solution component type 29 membership in `FederalEarningsFraud`.
- Test the Yes route through Supervisor Review and the No route directly to Disposition in the model-driven app.
- Verify BPF completion leaves the Case state unchanged.
