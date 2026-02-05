# PowerShell Module Template

A production-ready PowerShell module template built with the [Sampler](https://github.com/gaelcolas/Sampler) framework. This template provides enterprise-grade standards, comprehensive testing, and CI/CD integration to accelerate your PowerShell module development.

## ✨ Features

- **Enterprise PowerShell Standards** - PS7+, advanced functions, SupportsShouldProcess, comprehensive validation
- **Sampler Framework** - Industry-standard build system with GitVersion semantic versioning
- **Comprehensive Testing** - Pester v5+ with 85% code coverage threshold, QA tests for ScriptAnalyzer compliance
- **CI/CD Integration** - Pre-configured GitHub Actions and Azure Pipelines workflows
- **AI Agent Instructions** - Complete `.github/instructions/` files for GitHub Copilot and Claude Code
- **Example Functions** - Working examples with enterprise patterns (logging, error handling, idempotency)
- **Thread-Safe Logging** - Enterprise-grade `Write-Log` with rotation, redaction, and PSStyle output
- **Quick Setup** - Interactive `Initialize-Template.ps1` script for rapid customization

## 🚀 Quick Start

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

The script will:
- Replace all `{{PLACEHOLDER}}` tokens in file content
- Rename `Invoke-ADDSDomainController.*` files to your module name
- Update CHANGELOG.md with your module name
- Remove itself after completion

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

Follow the patterns in `Get-Greeting.ps1` and `Get-Greeting.tests.ps1` for enterprise standards.

## 📁 Directory Structure

```
Invoke-ADDSDomainController/
├── .github/
│   ├── copilot-instructions.md           # GitHub Copilot instructions
│   ├── instructions/                     # Path-scoped AI agent instructions
│   │   ├── powershell.instructions.md    # Enterprise PowerShell standards
│   │   ├── source.instructions.md        # Source code standards
│   │   ├── build.instructions.md         # Build system guidance
│   │   ├── ci.instructions.md            # CI/CD patterns
│   │   └── docs.instructions.md          # Documentation standards
│   └── workflows/
│       ├── ci.yml                        # GitHub Actions CI (multi-platform)
│       └── release.yml                   # GitHub Actions release to PSGallery
├── .vscode/
│   └── tasks.json                        # VS Code build/test tasks
├── source/
│   ├── Invoke-ADDSDomainController.psd1              # Module manifest
│   ├── Invoke-ADDSDomainController.psm1              # Root module (dot-sources functions)
│   ├── en-US/
│   │   └── about_Invoke-ADDSDomainController.help.txt # About help file
│   ├── Public/                           # Exported functions (one per file)
│   │   └── Get-Greeting.ps1              # Example public function
│   └── Private/                          # Internal helpers (one per file)
│       ├── Format-GreetingMessage.ps1    # Example private function
│       └── Write-Log.ps1                 # Enterprise logging (502 lines)
├── tests/
│   ├── tests.instructions.md             # Testing standards
│   ├── QA/
│   │   └── module.tests.ps1              # ScriptAnalyzer, changelog, help tests
│   └── Unit/
│       ├── Public/
│       │   └── Get-Greeting.tests.ps1    # Unit tests for Get-Greeting
│       └── Private/
│           ├── Format-GreetingMessage.tests.ps1
│           └── Write-Log.tests.ps1
├── .gitattributes
├── .gitignore
├── azure-pipelines.yml                   # Azure Pipelines (multi-platform, PSGallery deploy)
├── build.ps1                             # Sampler build bootstrap (487 lines)
├── build.yaml                            # Sampler build configuration
├── CHANGELOG.md                          # Keep a Changelog format
├── CLAUDE.md                             # Claude Code context and standards
├── codecov.yml                           # Code coverage configuration
├── GitVersion.yml                        # Semantic versioning configuration
├── Initialize-Template.ps1               # One-time setup script (removes itself)
├── LICENSE                               # MIT License
├── README.md                             # This file
├── RequiredModules.psd1                  # Build dependencies (Sampler, Pester, etc.)
├── Resolve-Dependency.ps1                # Dependency resolver (1076 lines)
└── Resolve-Dependency.psd1               # Resolver configuration
```

## 🎯 Enterprise Standards Included

### Core Standards (Must Have)
- ✅ **Guardrails Integration** - Elevation checks, environment validation
- ✅ **Comprehensive Validation** - Input validation, dependency checks, health status
- ✅ **ShouldProcess Support** - `-WhatIf` and `-Confirm` support
- ✅ **Full Idempotency** - Safe re-runs without drift or duplicates
- ✅ **Verification** - Confirms operations succeeded
- ✅ **ScriptAnalyzer Clean** - 0 warnings target

### Enhanced UX (Should Have)
- ✅ **PassThru Support** - Returns rich objects when requested
- ✅ **Force Parameter** - Suppresses confirmations for automation
- ✅ **Enhanced Error Messages** - Shows available options with actionable guidance
- ✅ **Smart Behavior** - Optimal defaults with logged rationale

### Operational Excellence (Nice to Have)
- ✅ **Capacity Reporting** - Metrics logged for operations
- ✅ **Helper Functions** - Info, removal, status check patterns

**Target: 11/11 features for production modules**

## 🔧 CI/CD Setup

### GitHub Actions

The template includes two workflows:

1. **CI Workflow** (`.github/workflows/ci.yml`)
   - Triggers on: push to `main`, pull requests
   - Platforms: Ubuntu, Windows, macOS
   - Steps: Build → Test → ScriptAnalyzer → Code Coverage

2. **Release Workflow** (`.github/workflows/release.yml`)
   - Triggers on: tags matching `v*`
   - Steps: Build → Test → Publish to PSGallery → Create GitHub Release

**Required Secrets:**
- `PSGALLERY_API_KEY` - Your PowerShell Gallery API key

### Azure Pipelines

The template includes `azure-pipelines.yml` with:
- Multi-platform testing: Linux, Windows PS7, Windows PS5.1, macOS
- Code coverage reporting to Codecov
- Deploy stage: publishes to PSGallery and GitHub Releases on `main` branch

**Required Variables:**
- `GalleryApiToken` - Your PowerShell Gallery API key
- `GitHubToken` - GitHub PAT for releases

## 📚 Example Functions

### Get-Greeting (Public Function)

Demonstrates:
- Advanced function with `[CmdletBinding(SupportsShouldProcess)]`
- `[OutputType()]` declaration
- Complete comment-based help
- Multi-line parameter declarations
- Input validation (`ValidateSet`, `ValidateNotNullOrEmpty`)
- `PassThru` and `Force` parameters
- Enterprise logging with `Write-Log`
- Idempotency pattern
- PSStyle-safe error messages

### Write-Log (Private Function)

Enterprise-grade logging with:
- Thread-safe operation using mutex
- Automatic rotation (10MB threshold, 5 rotated files)
- Sensitive data redaction (3 regex patterns)
- PSStyle console output with symbols (✗, ⚠, ✓, ℹ)
- Multiple log levels (ERROR, WARN, SUCCESS, INFO, DEBUG)
- ErrorRecord parameter set for detailed diagnostics
- Helper functions included

## 🧪 Testing

The template includes comprehensive test examples:

```powershell
# Run all tests
./build.ps1 -tasks test

# Run tests directly with Pester
Invoke-Pester

# Run with coverage
Invoke-Pester -CodeCoverage source/**/*.ps1
```

### Test Structure
- **QA Tests** (`tests/QA/module.tests.ps1`) - Validates:
  - ScriptAnalyzer compliance (0 warnings)
  - Changelog format
  - Help documentation quality
  - Manifest validity

- **Unit Tests** (`tests/Unit/`) - Mirrors source structure:
  - Public function tests with mocked dependencies
  - Private function tests
  - Parameter validation tests
  - WhatIf support tests
  - Error handling tests

## 📖 AI Agent Instructions

The template includes comprehensive AI agent instructions:

- **CLAUDE.md** - High-level context, structure, conventions for Claude Code
- **.github/copilot-instructions.md** - GitHub Copilot-specific instructions
- **.github/instructions/** - Path-scoped instructions:
  - `powershell.instructions.md` - Enterprise PowerShell standards (12 sections)
  - `source.instructions.md` - Module source standards (11 sections)
  - `build.instructions.md` - Build system guidance
  - `ci.instructions.md` - CI/CD patterns
  - `docs.instructions.md` - Documentation standards
- **tests/tests.instructions.md** - Pester testing standards

These files ensure consistent code quality when working with AI coding assistants.

## 🔄 Placeholder Reference

The following placeholders are used throughout the template:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `Invoke-ADDSDomainController` | Module name | `Invoke-MyModule` |
| `This module will orchestrate the installation and configuration of a root domain controller in a forest programmatically using carefully curated PowerShell commands. It would simplify this process as much as possible and as safely as possible.` | Module description | `Storage management for Windows Server` |
| `Olamide Olaleye` | Author name | `John Doe` |
| `Fountview Enterprise Solutions` | Company/organization | `Contoso Ltd` |
| `2dd186f4-06e5-48fb-bc6e-be5c5eb1a84d` | Unique module GUID | `12345678-1234-1234-1234-123456789012` |

Additionally, files named `Invoke-ADDSDomainController.*` will be renamed to your actual module name.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

Built with:
- [Sampler](https://github.com/gaelcolas/Sampler) - PowerShell module build framework
- [Pester](https://github.com/pester/Pester) - PowerShell testing framework
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) - PowerShell linter
- [GitVersion](https://gitversion.net/) - Semantic versioning

## 🤝 Contributing

This template is designed to be cloned and customized for your own modules. If you find improvements that would benefit others, consider contributing back!

1. Fork the template repository
2. Make your improvements
3. Submit a pull request with a clear description

---

**Ready to build your module?** Run `./Initialize-Template.ps1` to get started! 🚀
