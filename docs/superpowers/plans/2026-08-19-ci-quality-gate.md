# CI Quality Gate Implementation Plan

> **Execution note:** Implemented inline in this worktree with a verification checkpoint after each task.

**Goal:** Add a reproducible GitHub Actions quality gate that runs Echo Village's existing Windows Godot validation and publishes the generated test report.

**Architecture:** Keep `run_echo_village.bat --test` as the single source of truth for local and CI verification. The workflow downloads the pinned official Godot 4.5.2 Windows runtime into the runner temp directory, exposes it through `GODOT_EXECUTABLE`, runs the batch gate, and uploads the report with `if: always()`.

**Tech Stack:** GitHub Actions, Windows PowerShell, Godot 4.5.2-stable, existing PowerShell/BAT validators.

## Global Constraints

- Keep Godot compatibility at 4.2+ and verify with Godot 4.5.2-stable.
- Do not commit Godot binaries, `.godot` cache files, user saves, or CI logs.
- Do not duplicate the test assertions outside `tests/test_runner.gd`.
- CI permissions remain `contents: read`; no secrets or network services beyond the pinned official runtime download.

---

### Task 1: Add the workflow contract

**Files:**
- Create: `.github/workflows/ci.yml`
- Test: `tools/validate_project.ps1` plus workflow text assertions in the verification command.

**Interfaces:**
- Consumes: `run_echo_village.bat --test`, `GODOT_EXECUTABLE`, `tests/simulation_test_report.json`.
- Produces: GitHub check named `Echo Village CI` and artifact `echo-village-test-report`.

- [x] **Step 1: Write the workflow** with `windows-latest`, `contents: read`, push／PR／manual triggers, pinned Godot URL, batch test invocation, and always-uploaded report.
- [x] **Step 2: Validate required workflow strings** with PowerShell assertions for the trigger, permission, runner, pinned tag, `GODOT_EXECUTABLE`, batch command, `TEST_RESULT`, and artifact path.
- [x] **Step 3: Confirm no secret-like placeholders** with a repository scan excluding generated report data.

### Task 2: Document the development quality gate

**Files:**
- Modify: `README.md`
- Modify: `docs/test_plan.md`
- Create: `docs/superpowers/specs/2026-08-19-ci-quality-gate-design.md`

**Interfaces:**
- Consumes: workflow behavior from Task 1.
- Produces: reviewer-facing instructions for local and CI verification.

- [x] **Step 1: Add a CI badge and workflow section** explaining push／PR triggers, Godot version pin, and report artifact.
- [x] **Step 2: Update the test plan** to include the CI quality gate without changing the gameplay test count.
- [x] **Step 3: Run markdown and placeholder checks** before staging.

### Task 3: Full verification and delivery

**Files:**
- Verify: `.github/workflows/ci.yml`, `run_echo_village.bat`, `tools/validate_project.ps1`, `tests/simulation_test_report.json`.

- [x] **Step 1: Run `tools/validate_project.ps1` and the full bounded Godot suite** with the installed Godot executable.
- [x] **Step 2: Run `run_echo_village.bat --test` and require exit code 0, `TEST_RESULT passed=86 failed=0`, and no script/load errors.
- [x] **Step 3: Run `git diff --check`, stage only useful project files, commit, push, and compare local／remote SHA.
