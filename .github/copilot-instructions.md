# GitHub Copilot Repository Instructions

## Repository Overview

This repository contains production-grade PowerShell automation following enterprise standards, with a focus on:

* Enterprise PowerShell module development ({{MODULE_NAME}})
* Microsoft 365 Security (Defender XDR, Defender for Endpoint, Defender for Office 365, Defender for Identity) where applicable
* Microsoft Purview (DLP, sensitivity labels, information protection) where applicable
* Entra ID (Azure AD) identity operations (users, groups, apps, conditional access) where applicable
* Microsoft Graph automation (Graph SDK, REST where needed) where applicable
* Windows / Windows Server systems administration where applicable
* Reusable PowerShell modules and automation patterns

Primary language: PowerShell
Target platform: Windows Server / Windows Client / Hybrid M365
Standards: Enterprise-grade, security-first automation

---

## How to Work in This Repository

### Always Do First

* Review `README.md`, module docs, and any runbooks in `/docs`.
* Follow established module/function patterns in this repository.
* Reuse existing helper functions and common patterns (logging, auth, retries).
* Never introduce new frameworks or patterns without clear justification.

---

## Environment Setup

Required tools:

* PowerShell 7.x (preferred) or Windows PowerShell 5.1 (only where required)
* PSScriptAnalyzer v5+
* Pester v5+
* Git
* Sampler framework (for module projects)
* Microsoft Graph PowerShell SDK (`Microsoft.Graph` modules) where used

Optional but common:

* `Microsoft.Graph.Beta` (only if explicitly needed and documented)
* `Az.*` modules (only when interacting with Azure resources)
* SecretManagement (`Microsoft.PowerShell.SecretManagement`, `SecretStore` or other vault extension)

Bootstrap:

```powershell
Install-Module PSScriptAnalyzer -Force
Install-Module Pester -Force
Install-Module Sampler -Force
Install-Module Microsoft.Graph -Force
Install-Module Microsoft.PowerShell.SecretManagement -Force
```

---

## Build / Run

### Modules

```powershell
Invoke-Build
```

### Scripts

* Run in non-production environment first.
* Use `-WhatIf` and `-Confirm` patterns where destructive.
* Validate authentication context (tenant, scopes, environment) before executing changes.

---

## Test

All public functions must include Pester tests.

Run tests:

```powershell
Invoke-Pester
```

Requirements:

* Minimum 80% coverage (where practical)
* Critical paths tested
* Negative/failure scenarios included
* Graph calls mocked (no live tenant dependence unless explicitly labeled as integration tests)

---

## Lint / Format

All PowerShell must pass:

```powershell
Invoke-ScriptAnalyzer -Recurse
```

Rules:

* No suppressed rules without justification and comments
* No unresolved warnings
* Follow approved verb-noun naming (`Get-`, `Set-`, `New-`, `Remove-`, `Invoke-`, `Test-`, etc.)
* Avoid reformatting unrelated files

---

## Project Layout

Typical (Modules):

```
/source
  /Public
  /Private
  *.psm1
  *.psd1
/tests
/build
/docs (optional)
```

Key Locations:

* Public functions: `source/Public`
* Private helpers: `source/Private`
* Tests: `tests/`
* Build pipeline: `Invoke-Build` / `build.*` / CI workflows in `.github/workflows`

---

## Engineering Standards

### PowerShell Design

All code must:

* Be modular and single-responsibility
* Stay under ~100 lines per function where practical
* Support pipeline input when useful
* Include comment-based help for public functions
* Be idempotent where feasible (safe re-runs)

### Parameter Design

* Use `[CmdletBinding(SupportsShouldProcess)]` for any change-making operations.
* Use `ValidateSet`, `ValidatePattern`, `ValidateNotNullOrEmpty` appropriately.
* Prefer explicit `-TenantId`, `-Environment`, `-ScopeSet` parameters when auth context matters.
* Never rely on ambient global state without documenting it.

### Error Handling

* Use structured `try/catch/finally`
* Throw meaningful exceptions (actionable messages)
* Never suppress errors silently
* Include context (tenant, user, resource id, request id) *without* leaking secrets

### Logging

* Structured logging preferred (timestamp, level, operation, correlation id)
* Never log secrets, tokens, full auth headers, private keys, or raw PII dumps
* If output includes identities, prefer object IDs or masked identifiers unless required

### Security

Mandatory rules:

* Never hardcode credentials, secrets, tokens, or tenant-specific secrets
* Prefer SecretManagement / Key Vault / environment-secured secrets
* Validate all input (especially identifiers and file paths)
* Apply least privilege: request minimum Graph scopes/permissions needed
* Avoid unsafe patterns (`Invoke-Expression`, untrusted string interpolation)
* Handle PII carefully; minimize collection and retention

---

## Microsoft Graph / Entra / Defender Tuning

### Authentication & Scopes

* Prefer Graph SDK (`Connect-MgGraph`) with **explicit scopes** or app-based auth where documented.
* Always document required scopes/permissions in:

  * function help (`.PARAMETER` / notes), and/or
  * `README.md` / `/docs/auth.md`
* Do not request broad scopes by default (e.g., `Directory.ReadWrite.All`) unless strictly required.

### Graph SDK Usage Standards

* Prefer `Get-Mg*`, `New-Mg*`, `Update-Mg*`, `Remove-Mg*` over raw REST.
* If using REST (`Invoke-MgGraphRequest`), include:

  * endpoint
  * method
  * expected status codes
  * pagination behavior
  * throttling/backoff handling

### Throttling, Paging, and Reliability

* Implement retry with exponential backoff for Graph throttling (429) and transient failures (5xx).
* Handle pagination (`@odata.nextLink`) for list operations.
* Be explicit about consistency levels if needed (e.g., advanced queries), and document why.

### Tenant Safety / Change Control

* For change operations:

  * require confirmation patterns (`SupportsShouldProcess`)
  * support `-WhatIf`
  * provide dry-run output (what would change)
* Always protect against "wrong tenant" errors:

  * validate tenant context at runtime (tenant ID / domain)
  * optionally require `-TenantId` for high-risk operations

### Data Handling

* Avoid exporting sensitive tenant data by default.
* When exporting:

  * support `-OutputPath`
  * use safe formats (CSV/JSON) with minimal fields
  * avoid PII unless explicitly required by the user
  * include redaction options when feasible

### Microsoft Defender Considerations

* Prefer official APIs/SDKs where available and supported.
* Ensure scripts that gather diagnostics avoid collecting secrets.
* When interacting with Defender endpoints/policies:

  * include clear prerequisites and permissions
  * document any latency expectations (policy propagation, telemetry delay)

---

## Testing Standards (Graph/M365)

* Unit tests must mock Graph calls (no real tenant dependency).
* Integration tests (if present) must be explicitly labeled and opt-in (e.g., `-Tag Integration`).
* Include tests for:

  * invalid input
  * auth failure
  * throttling path
  * empty dataset (no results)
  * pagination (multi-page)

---

## Automation Patterns

Preferred patterns:

* Advanced functions (`[CmdletBinding()]`)
* Parameter validation + strongly typed inputs where practical
* SupportsShouldProcess for destructive actions
* Dependency injection via parameters (clients, endpoints, env)
* Non-interactive behavior for automation (no prompts in CI)

Avoid:

* Hardcoded paths
* Global mutable state
* Silent failures
* Assumptions about tenant/environment

---

## Documentation

All public functions must include:

* Synopsis + Description
* Parameter docs
* Examples (including auth requirements)
* Notes (permissions/scopes, safety cautions)

Modules should include:

* README.md
* Usage examples
* Dependency list
* Required Graph scopes/permissions (if applicable)

---

## Pull Request Expectations

Before proposing changes:

* Tests pass
* ScriptAnalyzer clean
* No secrets introduced
* Docs updated
* Clear commit messages

PRs should include:

* Summary of change
* Testing performed
* Risk/impact

---

## Copilot Behavior Guidelines

When working in this repository, Copilot must:

* Follow existing patterns before creating new ones
* Prioritize security and stability
* Prefer clarity over cleverness
* Ask for clarification if requirements are ambiguous
* Never assume production access
* Never generate insecure defaults
* For Graph: explicitly state required scopes/permissions and handle throttling/paging

If instructions conflict with code, prefer existing repo patterns.

Only search the codebase if this file lacks required information.
