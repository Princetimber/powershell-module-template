# Changelog for {{MODULE_NAME}}

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Export-Greeting public function demonstrating correct ShouldProcess usage for
  state-changing operations (file writes with -WhatIf, -Confirm, -Force, -Append,
  -PassThru support).

### Changed

- Simplified Write-ToLog from 490-line logging framework to thin wrapper (~65 lines)
  mapping log levels to native PowerShell streams (Write-Verbose, Write-Warning,
  Write-Error, Write-Information).
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
- Thread-safe mutex, log rotation, sensitive data redaction, ANSI/PSStyle output,
  ErrorRecord parameter set, and 6 helper functions from Write-ToLog.
- .github/instructions/ directory and tests/tests.instructions.md.
- Classes/ directory reference from documentation (directory did not exist).
