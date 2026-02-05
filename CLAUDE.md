# CLAUDE.md

Project context for Claude Code and AI agents.

## Project Overview

PowerShell module template built with the **Sampler** framework. This template serves as a starting point for creating enterprise-grade PowerShell modules with:

- **Standardized structure** following Sampler conventions
- **Comprehensive testing** with Pester v5+
- **CI/CD integration** for GitHub Actions and Azure Pipelines
- **Code quality enforcement** via ScriptAnalyzer and code coverage
- **Complete documentation** with instruction files for AI agents

After cloning, run `Initialize-Template.ps1` to customize the template with your module name, author, and description.

## Module Structure (Sampler Layout)

```
Invoke-ADDSDomainController/
├── source/
│   ├── Invoke-ADDSDomainController.psd1      # Module manifest
│   ├── Invoke-ADDSDomainController.psm1      # Dot-sources Public/ and Private/
│   ├── Public/                   # Exported functions (one per file)
│   ├── Private/                  # Internal helper functions (one per file)
│   ├── Classes/                  # PowerShell classes (numbered for load order)
│   └── en-US/                    # Help files
├── tests/
│   ├── QA/                       # ScriptAnalyzer, changelog, help quality
│   │   └── module.tests.ps1
│   └── Unit/
│       ├── Public/               # Tests mirror source/Public/
│       └── Private/              # Tests mirror source/Private/
├── build.ps1
├── build.yaml
└── RequiredModules.psd1
```

## Common Commands

```powershell
# First build (resolves dependencies)
./build.ps1 -ResolveDependency -tasks build

# Subsequent builds
./build.ps1 -tasks build

# Run tests
./build.ps1 -tasks test
# or directly:
Invoke-Pester

# Lint
Invoke-ScriptAnalyzer -Path source/ -Recurse

# Package
./build.ps1 -tasks pack
```

## Coding Conventions

- **One function per file**, filename matches function name exactly (e.g., `Get-Greeting.ps1`)
- **Advanced functions**: always use `[CmdletBinding()]`
- **SupportsShouldProcess**: required for any state-changing operation
- **Comment-based help**: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE` on all public functions
- **Input validation**: mandatory — use `ValidateSet`, `ValidatePattern`, `ValidateNotNullOrEmpty`
- **Error handling**: `try/catch/finally`, throw actionable errors, never swallow exceptions
- **Naming**: PascalCase for functions (approved Verb-Noun), PascalCase for parameters, camelCase for local variables
- **No hardcoded secrets** — use SecretManagement module or environment variables
- **Never use `Invoke-Expression`**
- **Graph API** (if applicable): handle throttling (429), transient retries (5xx) with backoff, and pagination (`@odata.nextLink`)

## Testing Conventions

- **Pester v5+** with `BeforeDiscovery`/`BeforeAll`/`Describe`/`It` structure
- Test file structure mirrors source structure
- Mock all external dependencies (Graph API, OS commands, etc.)
- QA tests validate: changelog format, ScriptAnalyzer compliance, help documentation quality
- **85% code coverage threshold** (configured in `build.yaml`)

## CI/CD

- **GitHub Actions** (`.github/workflows/ci.yml` and `release.yml`)
  - CI: Runs on push to main and PRs
  - Matrix testing: Linux, Windows, macOS
  - Release: Publishes to PSGallery and GitHub Releases on tag `v*`

- **Azure Pipelines** (`azure-pipelines.yml`)
  - Stages: Build → Test (multi-platform: Linux, Windows PS7, Windows PS5.1, macOS) → Code Coverage → Deploy
  - Deploy publishes to PSGallery and GitHub Releases on `main` branch

## AI Agent Operating Principles

- Make the smallest safe change that achieves the goal
- Prefer extending existing patterns over introducing new architecture
- Maintain security-first defaults at all times
- Never introduce secrets, tokens, or credentials into code or tests
- Avoid collecting, logging, or exporting sensitive data by default

## AI Agent Workflow Rules

1. **Discover**
   - Read `README.md`, existing module docs, and relevant scripts
   - Identify existing patterns for logging, error handling, auth, retries, and tests

2. **Plan**
   - State proposed approach and affected files
   - Identify required permissions/scopes if Graph/M365 changes are involved
   - Identify tests that should be added/updated

3. **Implement**
   - Follow PowerShell advanced function patterns
   - Use `SupportsShouldProcess` for change operations
   - Add safe input validation and clear error messages
   - Handle Graph throttling (429), transient failures (5xx), and pagination (if applicable)

4. **Validate**
   - Run lint and tests:
     - `Invoke-ScriptAnalyzer -Path source/ -Recurse`
     - `Invoke-Pester`
   - If integration tests exist, they must be opt-in and clearly labeled

5. **Document**
   - Update help/examples when behavior changes
   - Document required Graph scopes/permissions and any operational caveats

## Prohibited Actions

- Do not add or request broad Graph scopes by default
- Do not use `Invoke-Expression` or unsafe string execution
- Do not assume the agent has access to live systems or production environments
- Do not add telemetry, background network calls, or external dependencies without explicit documentation

## Output Expectations

- Produce review-ready PowerShell: readable, testable, idempotent
- Keep changes minimal; avoid drive-by refactors
- If requirements are unclear, ask concise clarifying questions rather than guessing

## Further Reference

- `.github/copilot-instructions.md` — GitHub Copilot-specific instructions
- `.github/instructions/` — path-specific standards for PowerShell, source, build, CI, and docs
- `tests/tests.instructions.md` — Pester testing standards
