# PowerShell Module Template

A production-ready PowerShell module template built with the [Sampler](https://github.com/gaelcolas/Sampler) framework. This template provides standardized patterns, comprehensive testing, and CI/CD integration to accelerate your PowerShell module development.

## Features

- **PowerShell 7+ Standards** - Advanced functions, proper ShouldProcess usage, comprehensive validation
- **Sampler Framework** - Industry-standard build system with GitVersion semantic versioning
- **Comprehensive Testing** - Pester v5+ with 85% code coverage threshold, QA tests for ScriptAnalyzer compliance
- **CI/CD Integration** - Pre-configured GitHub Actions and Azure Pipelines workflows
- **Example Functions** - Working examples demonstrating correct patterns (read-only vs state-changing)
- **Quick Setup** - Interactive `Initialize-Template.ps1` script for rapid customization

## Quick Start

### 1. Create Your Module from Template

```powershell
# Clone or download this repository
git clone <your-template-repo-url> MyNewModule
cd MyNewModule

# Run the initialization script
./Initialize-Template.ps1
```

The init script will prompt you for:
- **Module Name** (e.g., `Invoke-MyModule`) - validates approved Verb-Noun pattern
- **Description** - what your module does
- **Author** - your name
- **Company** - your organization
- **GUID** - auto-generated if not provided

### 2. Build Your Module

```powershell
# First build (resolves dependencies)
./build.ps1 -ResolveDependency -tasks build

# Subsequent builds
./build.ps1 -tasks build

# Run tests
./build.ps1 -tasks test

# Lint
Invoke-ScriptAnalyzer -Path source/ -Recurse
```

### 3. Add Your Functions

```powershell
# Add a public function
New-Item -Path source/Public/Get-MyData.ps1 -ItemType File

# Add corresponding test
New-Item -Path tests/Unit/Public/Get-MyData.tests.ps1 -ItemType File
```

Follow the patterns in `Get-Greeting.ps1` (read-only) and `Export-Greeting.ps1` (state-changing with ShouldProcess).

## Directory Structure

```
{{MODULE_NAME}}/
├── .github/
│   ├── copilot-instructions.md           # GitHub Copilot instructions
│   └── workflows/
│       ├── ci.yml                        # GitHub Actions CI (multi-platform)
│       └── release.yml                   # GitHub Actions release to PSGallery
├── .vscode/
│   └── tasks.json                        # VS Code build/test tasks
├── source/
│   ├── {{MODULE_NAME}}.psd1              # Module manifest
│   ├── {{MODULE_NAME}}.psm1              # Root module (dot-sources functions)
│   ├── en-US/
│   │   └── about_{{MODULE_NAME}}.help.txt # About help file
│   ├── Public/                           # Exported functions (one per file)
│   │   ├── Get-Greeting.ps1              # Example read-only function
│   │   └── Export-Greeting.ps1           # Example state-changing function
│   └── Private/                          # Internal helpers (one per file)
│       ├── Format-GreetingMessage.ps1    # Example private function
│       └── Write-ToLog.ps1              # Thin logging wrapper
├── tests/
│   ├── QA/
│   │   └── module.tests.ps1              # ScriptAnalyzer, changelog, help tests
│   └── Unit/
│       ├── Public/
│       │   ├── Get-Greeting.tests.ps1
│       │   └── Export-Greeting.tests.ps1
│       └── Private/
│           ├── Format-GreetingMessage.tests.ps1
│           └── Write-ToLog.tests.ps1
├── azure-pipelines.yml                   # Azure Pipelines (multi-platform, PSGallery deploy)
├── build.ps1                             # Sampler build bootstrap
├── build.yaml                            # Sampler build configuration
├── CHANGELOG.md                          # Keep a Changelog format
├── CLAUDE.md                             # Claude Code context and standards
├── Initialize-Template.ps1               # One-time setup script (removes itself)
├── LICENSE                               # MIT License
├── README.md                             # This file
├── RequiredModules.psd1                  # Build dependencies (pinned version ranges)
├── Resolve-Dependency.ps1                # Dependency resolver
└── Resolve-Dependency.psd1               # Resolver configuration
```

## Patterns Demonstrated

### Get-Greeting (Read-Only Function)

- `[CmdletBinding()]` without ShouldProcess (read-only operations don't need it)
- Pipeline input, `PassThru` for rich object output
- Input validation with `ValidateSet`, `ValidateNotNullOrEmpty`
- Proper `ErrorRecord` construction with `ThrowTerminatingError`

### Export-Greeting (State-Changing Function)

- `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]` - correct use of ShouldProcess
- `-WhatIf` and `-Confirm` support for safe file operations
- `-Force` to overwrite, `-Append` to add to existing files
- `-PassThru` returning `[System.IO.FileInfo]`

### Write-ToLog (Logging)

- Thin wrapper mapping log levels to native PowerShell streams
- INFO/DEBUG -> `Write-Verbose`, WARN -> `Write-Warning`, ERROR -> `Write-Error`, SUCCESS -> `Write-Information`
- Optional `-LogPath` parameter for file logging

## CI/CD Setup

### GitHub Actions

1. **CI Workflow** (`.github/workflows/ci.yml`)
   - Triggers on: push to `main`, pull requests
   - Platforms: Ubuntu, Windows, macOS
   - Steps: Build -> Test -> ScriptAnalyzer -> Code Coverage

2. **Release Workflow** (`.github/workflows/release.yml`)
   - Triggers on: tags matching `v*`
   - Steps: Build -> Test -> Publish to PSGallery -> Create GitHub Release

**Required Secrets:**
- `PSGALLERY_API_KEY` - Your PowerShell Gallery API key

### Azure Pipelines

The template includes `azure-pipelines.yml` with:
- Multi-platform testing: Linux, Windows (PS7), macOS
- Code coverage reporting
- Deploy stage: publishes to PSGallery and GitHub Releases on `main` branch

**Required Variables:**
- `GalleryApiToken` - Your PowerShell Gallery API key
- `GitHubToken` - GitHub PAT for releases

## Testing

```powershell
# Run all tests
./build.ps1 -tasks test

# Run tests directly with Pester
Invoke-Pester

# Run with coverage
Invoke-Pester -CodeCoverage source/**/*.ps1
```

### Test Structure
- **QA Tests** (`tests/QA/module.tests.ps1`) - ScriptAnalyzer compliance, changelog format, help documentation quality
- **Unit Tests** (`tests/Unit/`) - Mirrors source structure with mocked dependencies

## Placeholder Reference

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{MODULE_NAME}}` | Module name | `Invoke-MyModule` |
| `{{MODULE_DESCRIPTION}}` | Module description | `Storage management for Windows Server` |
| `{{AUTHOR}}` | Author name | `John Doe` |
| `{{COMPANY}}` | Company/organization | `Contoso Ltd` |
| `{{MODULE_GUID}}` | Unique module GUID | `12345678-1234-1234-1234-123456789012` |

Files named `TemplateModule.*` will be renamed to your actual module name.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

Built with:
- [Sampler](https://github.com/gaelcolas/Sampler) - PowerShell module build framework
- [Pester](https://github.com/pester/Pester) - PowerShell testing framework
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) - PowerShell linter
- [GitVersion](https://gitversion.net/) - Semantic versioning

## Contributing

1. Fork the template repository
2. Make your improvements
3. Submit a pull request with a clear description

---

**Ready to build your module?** Run `./Initialize-Template.ps1` to get started!
