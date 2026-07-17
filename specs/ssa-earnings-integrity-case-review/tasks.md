# Tasks: SSA Earnings Integrity Case Review

## 0. Planning and Setup

- T001: Confirm discovery responses with stakeholders
  - Owner: Product lead
  - Done when: Discovery answers are approved for implementation
- T002: Validate local prerequisites with bootstrap script 00
  - Owner: Builder
  - Done when: All checks show PASS
- T003: Run authentication bootstrap script 10 for target environment
  - Owner: Builder
  - Done when: az account and pac auth profile are verified

## 1. Schema Build (Dataverse First)

- T010: Finalize minimum viable table list for Phase 1 case lifecycle
  - Owner: Solution architect
  - Done when: Table scope is locked for build iteration 1
- T011: Author table payload files in payloads/table-*.json
  - Owner: Dataverse builder
  - Done when: Payload files pass JSON validation
- T012: Run script 20 to build tables
  - Owner: Dataverse builder
  - Done when: Script exits with zero failed count
- T013: Author columns payload files in payloads/columns-*.json
  - Owner: Dataverse builder
  - Done when: Required columns are defined for all Phase 1 tables
- T014: Run script 30 to build columns
  - Owner: Dataverse builder
  - Done when: Script exits with zero failed count
- T015: Author relationship payload files in payloads/relationships-*.json
  - Owner: Dataverse builder
  - Done when: Lookup and parent-child mappings are defined and reviewed
- T016: Run script 40 to build relationships
  - Owner: Dataverse builder
  - Done when: Script exits with zero failed count

## 2. Solution Assembly and App Layer

- T020: Ensure target solution exists in environment
  - Owner: Builder
  - Done when: Solution unique name is confirmed
- T021: Run script 50 to add components to solution
  - Owner: Builder
  - Done when: Script exits with zero failed count
- T022: Configure initial forms and views payload assumptions
  - Owner: App designer
  - Done when: Required analyst and supervisor views are defined
- T023: Run script 60 to build forms and views
  - Owner: Builder
  - Done when: Script exits with zero failed count
- T024: Define supervisor report web resource and placement on the case form
  - Owner: App designer
  - Done when: The report surface is specified and aligned to case review needs
- T025: Run script 70 to build web resources
  - Owner: Builder
  - Done when: Script exits with zero failed count and the report web resource is added to the solution

## 3. Validation

- T030: Verify tables in Maker portal
  - Owner: QA/Builder
  - Done when: All expected tables are visible
- T031: Verify forms/views support case workflow
  - Owner: QA/Builder
  - Done when: Analyst and supervisor tasks are executable in UI
- T032: Execute demo walkthrough with seeded records
  - Owner: Demo lead
  - Done when: End-to-end scenario reaches one of the intended dispositions
- T033: Verify report web resource renders summary content correctly
  - Owner: QA/Builder
  - Done when: Supervisor summary content is visible and accurate in the form experience

## 4. ALM and Source Control

- T040: Export unmanaged solution
  - Owner: Builder
  - Done when: Export zip exists under out/
- T041: Unpack solution to source folder
  - Owner: Builder
  - Done when: Source files exist under `solutions/{solution-name}/`
- T042: Commit implementation artifacts
  - Owner: Builder
  - Done when: Commit is created without environment-local files
- T043: Pack and import to next environment (if requested)
  - Owner: Builder
  - Done when: Import succeeds and artifacts are available

## 5. Documentation

- T050: Update docs/build-log.md with decisions, steps, and validation evidence
  - Owner: Builder
  - Done when: Another team member can repeat the build from docs

## 6. Deferred Backlog (Post-Phase 1)

- T900: Add AI-assisted case summarization and next-best-action guidance
- T901: Add advanced risk scoring and routing automation
- T902: Add external system integration adapters
- T903: Add production hardening checklist and compliance evidence pack
