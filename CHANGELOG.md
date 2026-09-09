# Changelog for {{MODULE_NAME}}

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Brought `Initialize-Template.ps1` to zero baseline ScriptAnalyzer findings
  (was 153). 107 were fixed mechanically -- 71
  `PSAvoidUsingDoubleQuotesForConstantString`, 31 `PSAvoidTrailingWhitespace`,
  and 5 layout findings (`PSPlaceCloseBrace`, `PSUseConsistentWhitespace`,
  `PSUseConsistentIndentation`). The remaining 46 are `PSAvoidUsingWriteHost`,
  suppressed in this one file via `SuppressMessageAttribute` with a written
  justification: the script is an interactive bootstrapper that prompts with
  `Read-Host`, writes coloured status output for a human at a terminal, and
  deletes itself on completion, so the rule's rationale ("invisible to capture,
  redirection, and tests") does not apply. `PSAvoidUsingWriteHost` remains a
  hard rule for module code in `PSScriptAnalyzerSettings.psd1` -- it was not
  added to `ExcludeRules`. Verified by re-running the script end to end: the
  GUID substitution, placeholder replacement, file renames, coloured output,
  and self-removal all behave as before.

- Pinned `Pester` to `[6.0,7.0)` in `RequiredModules.psd1`. The previous
  `[5.6,6.0)` range explicitly excluded Pester 6, so a dependency resolve
  could never pick up the current major version. Verified: the range resolves
  to 6.1.0 on PSGallery, Sampler's Pester task requires only `>= 4.0` with no
  upper bound, and the suite passes unchanged when run under Pester 6.1.0
  (107 tests, 0 failures, 94.54% coverage).

- Formatted `source/TemplateModule.psd1` and `RequiredModules.psd1` to the
  baseline ruleset introduced in the change below. The stock
  `New-ModuleManifest` layout left the module manifest with 97 violations
  (`PSUseConsistentIndentation`, `PSAlignAssignmentStatement`,
  `PSPlaceCloseBrace`) and `RequiredModules.psd1` with 11
  (`PSAlignAssignmentStatement`). Both changes are whitespace-only; the
  hashtables parse to identical keys and values.

- The `lint` job in `.github/workflows/ci.yml` now runs the repo baseline
  (`PSScriptAnalyzerSettings.psd1`) recursively over `source/` in addition to
  the existing stricter `-Settings PSGallery` pass, and reports both before
  failing. The QA suite only feeds exported function `.ps1` files to
  ScriptAnalyzer, so nothing in CI had ever applied the baseline to the module
  manifest, which is why the 97 violations above accumulated unnoticed.

- The `lint` job's two ScriptAnalyzer passes were folded into a single step
  that begins with `Import-Module PSScriptAnalyzer -MinimumVersion 1.25.0`.
  Each GitHub Actions `run:` block is a fresh shell, so an import performed in
  the install step would not have applied to the steps that actually lint;
  doing it in the linting step means an older copy preinstalled on the runner
  image cannot win on `PSModulePath`, and the job fails loudly if only an
  older version is available. `RequiredModules.psd1` raises its ScriptAnalyzer
  floor from `[1.22,2.0)` to `[1.25,2.0)` to match (resolves to 1.25.0).

- Expanded `PSScriptAnalyzerSettings.psd1` from a minimal exclude-only config
  to a comprehensive baseline ruleset covering security, `ShouldProcess`
  enforcement, OTBS formatting, and comment-based help, targeting
  PowerShell 7.4.

### Fixed

- Made the QA `Should pass Script Analyzer for <Name>` test and the CI `lint`
  job resilient to an upstream PSScriptAnalyzer 1.25.0 bug: `Invoke-ScriptAnalyzer`
  intermittently throws `NullReferenceException` (it reproduces with the default
  ruleset and no settings file, and the failure count varies across identical
  runs). Both call sites now retry that specific exception up to three times and
  rethrow afterwards. `-ErrorAction Stop` was added, which matters in its own
  right: without it the crash was a *non-terminating* error, so `$pssaResult`
  stayed `$null` and satisfied `Should -BeNullOrEmpty` -- the analyzer could
  silently report "no findings" for a file it never analysed. Only
  `NullReferenceException` is caught, so genuine analyzer failures and real rule
  violations still fail. Verified by fault injection in both directions: a
  first-attempt crash passes on retry, a persistent crash still fails.

- `Initialize-Template.ps1` set the module GUID with a `(?m)^GUID\s*=` regex
  that assumed the manifest key started at column 0. Formatting the manifest
  to the baseline (above) indents and pads that key, which silently broke the
  substitution, so every initialized module would have kept the template's
  fixed GUID. The pattern now captures leading whitespace and alignment
  padding and preserves both.

- Removed the broken project-level `PostToolUse` ScriptAnalyzer hook from
  `.claude/settings.json`. The hook's `pwsh` script was wrapped in double
  quotes while the hook itself runs via `sh -c "<command>"`, which expanded
  `$files` and stripped the inner double quotes before `pwsh` ever parsed the
  script, corrupting `if ($files)` into `if ()` and throwing a `ParserError`
  on every `Edit`/`Write`. An equivalent, correctly single-quoted hook has
  been configured at the user level instead, so linting on `.ps1`/`.psm1`
  changes continues without the quoting bug or duplicate execution.

- Restored a passing `main` build: the checked-in `output/` build artifact used
  during local verification of the prior `Removed` change had gone stale before
  `Write-ToLog`'s Bearer-token and unquoted `key: value` redaction patterns were
  added, masking a real regression — removing the dead logging helpers' tests
  also dropped code coverage below the 85% threshold. Added targeted Pester
  coverage for previously-untested `Write-ToLog`/`Invoke-LogRotation` error
  paths (mutex-acquire timeout, log-write failure, rotation failure, directory-
  creation race, `ErrorRecord` invocation/inner-exception detail) and for
  `Get-Greeting`'s `ThrowTerminatingError` branch, bringing coverage to ~94.5%.

### Removed

- Removed `.github/copilot-instructions.md` along with the references to it in
  `README.md` (directory tree), `AGENTS.md`, and `CLAUDE.md` -- the latter's
  `## Further Reference` section went with it, as that was its only entry. This
  also clears the last stray `{{MODULE_NAME}}` placeholder that survived
  `Initialize-Template.ps1`, since the token lived in that file.

- Removed `Write-ErrorLog`, `Get-LogFilePath`, `Get-LogFileSize`, `Set-LogFilePath`,
  and `Clear-LogFile` from `source/Private` along with their dedicated Pester
  tests. None of these functions were ever called by the module's public or
  private code — they existed only to be unit-tested, and `Write-ErrorLog`
  duplicated logic already handled by `Write-ToLog`'s own `ErrorRecord`
  parameter set. `Write-ToLog` (the module's standard logger) and
  `Invoke-LogRotation` (invoked from within `Write-ToLog`) are unchanged.

### Security

- Restricted the opencode GitHub Actions workflow to trusted commenters (repo
  owner, org members, invited collaborators). Previously any user could comment
  `/oc` on a public issue or PR to run the agent with `ANTHROPIC_API_KEY` and an
  OIDC token in scope. Also pinned the third-party opencode action to an immutable
  release commit (v1.18.9) instead of the mutable `@latest` branch.

### Fixed

- Enabled PSResourceGet so the NuGet version ranges in RequiredModules.psd1 resolve
  on a clean machine (the legacy PowerShellGet path could not parse them), and
  declared the transitive build dependencies (Configuration, Metadata, Plaster,
  PowerShellForGitHub) so ModuleBuilder and the Sampler tasks import cleanly.
- Shipped a valid module GUID in the source manifest so the un-initialized template
  builds in CI; Initialize-Template regenerates a unique GUID on init.
- Scoped the QA per-function help, unit-test, and ScriptAnalyzer checks to exported
  (public) functions, matching the convention that private functions carry no
  comment-based help. The QA ScriptAnalyzer check now honours PSScriptAnalyzerSettings.psd1.
- Hardened the ModuleFast dependency bootstrap to fetch over HTTPS with an
  HTML-interstitial and byte-decoding guard before executing the script.
- Corrected release pipelines to invoke the defined `publish_psgallery` workflow.
- Made template token replacement literal and escaped apostrophes in generated
  single-quoted secret assignments.
- Made source module imports fail fast when a private or public script cannot load.
- Corrected private script filenames to match their function names exactly.
- Replaced copied logging identifiers with template-specific file and mutex names.
- Made the Initialize-Template `.git`/`output` exclusions cross-platform; the previous
  backslash-only globs never matched on macOS/Linux, so those paths were not excluded.
- Extended Write-ToLog secret redaction to also cover Bearer tokens and unquoted
  `key: value` pairs (in addition to the existing key=value, JSON, and XML forms).

### Added

- Export-Greeting public function demonstrating correct ShouldProcess usage for
  state-changing operations (file writes with -WhatIf, -Confirm, -Force, -Append,
  -PassThru support).
- Clear-LogFile private function — clears the active log file with optional
  timestamped archive backup before clearing. ConfirmImpact=High always prompts
  unless -Force or -Confirm:$false is passed.
- Get-LogFilePath private function — returns the current module-scoped log file
  path ($script:LogFile) for inspection or use in external scripts.
- Get-LogFileSize private function — returns the current log file size in bytes;
  returns 0 if the log file does not yet exist.
- Invoke-LogRotation private function — rotates log files by shifting numbered
  backups up (log.5 removed, log.4 shifted to log.5, continuing through log to
  log.1). Called inside the
  Write-ToLog mutex; not intended for direct use.
- Set-LogFilePath private function — sets the module-scoped log file path with
  absolute-path validation; -Force creates the destination directory on demand.
  Also updates $Global:LogFile for backward compatibility.
- Write-ErrorLog private function — convenience wrapper around Write-ToLog for
  ErrorRecord objects. Logs the main message at ERROR level; exception type,
  category, location, and inner exception at DEBUG. -IncludeStackTrace appends
  the PowerShell script stack trace.

### Changed

- Updated `.claude/settings.json` PostToolUse hook to pass `-Settings PSScriptAnalyzerSettings.psd1`
  to `Invoke-ScriptAnalyzer`, ensuring the project-local ruleset is applied on every file edit
  inside Claude Code.
- Rebuilt Write-ToLog as a production-grade, thread-safe logging framework:
  - Named mutex (Global\TemplateModuleLog) prevents concurrent write
    corruption across threads and runspaces.
  - Auto-rotates at 10 MB, keeping up to 5 numbered backup files.
  - Redacts passwords, tokens, keys, and secrets in key=value, JSON, and XML/HTML
    formats before writing.
  - ANSI colour console output via PSStyle (7.2+) with escape-code fallback.
  - Dedicated ErrorRecord parameter set for structured exception logging.
  - Wrapper functions (Test-PathWrapper, Add-ContentWrapper, Get-ItemWrapper,
    New-ItemDirectoryWrapper) isolate I/O calls for Pester mockability.
  - Mutex is disposed on PowerShell exit via Register-EngineEvent.
- Removed ShouldProcess from Get-Greeting — read-only functions should not use
  SupportsShouldProcess. Removed Force parameter accordingly.
- Replaced string-throw error handling in Get-Greeting with proper ErrorRecord
  construction via ThrowTerminatingError.
- Replaced AllowEmptyString with ValidateNotNullOrEmpty and ValidatePattern on
  Format-GreetingMessage Name parameter.
- Pinned dependency versions in RequiredModules.psd1 using version ranges instead
  of 'latest'.
- Consolidated AI agent documentation: removed .github/instructions/ directory
  (5 files) and tests/tests.instructions.md, trimmed copilot-instructions.md.
- Updated README, CLAUDE.md, and help text to reflect all changes.

### Removed

- Windows PowerShell 5.1 test job from azure-pipelines.yml (contradicts PS 7.0
  requirement in #Requires).
- .github/instructions/ directory and tests/tests.instructions.md.
- Classes/ directory reference from documentation (directory did not exist).
