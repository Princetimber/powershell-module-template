#Requires -Version 7.0

<#
.SYNOPSIS
    Initializes the PowerShell module template with your module name, author, and description.

.DESCRIPTION
    This script customizes the template by:
    - Prompting for module name, description, author, and company
    - Validating the module name follows PowerShell Verb-Noun conventions
    - Generating a unique GUID for the module
    - Replacing all {{PLACEHOLDER}} tokens in file content
    - Renaming TemplateModule.* files to your actual module name
    - Updating CHANGELOG.md with your module name
    - Optionally creating secrets.local.ps1 scoped to a single publish target (PSGallery or GitHub)
    - Removing itself after successful completion

    Run this script once after cloning the template, then start building your module.

.PARAMETER ModuleName
    The name of your PowerShell module. Must follow PowerShell Verb-Noun naming conventions.
    Example: Invoke-Storage, Get-MyData, Set-Configuration

.PARAMETER Description
    A brief description of what your module does.

.PARAMETER Author
    The author name (will appear in module manifest and LICENSE).

.PARAMETER Company
    Your company or organization name.

.PARAMETER ModuleGuid
    Optional. A GUID for your module. If not provided, one will be generated automatically.

.PARAMETER Publish
    Optional. Specifies a single publish destination. Accepted values: PSGallery, GitHub.
    When provided, creates a secrets.local.ps1 file containing only the credential required
    for that target. This file is gitignored and used when running the matching build task locally:
      PSGallery → ./build.ps1 -tasks publish_psgallery
      GitHub    → ./build.ps1 -tasks publish_github

.PARAMETER GalleryApiKey
    Optional. Your PowerShell Gallery API key. Only used when -Publish PSGallery is specified.
    If omitted, you will be prompted interactively.
    Obtain from: https://www.powershellgallery.com/account/apikeys

.PARAMETER GitHubToken
    Optional. A GitHub Personal Access Token with 'repo' scope. Only used when -Publish GitHub
    is specified. If omitted, you will be prompted interactively.
    Generate at: https://github.com/settings/tokens

.PARAMETER WhatIf
    Shows what changes would be made without actually making them.

.EXAMPLE
    ./Initialize-Template.ps1

    Runs interactively, prompting for all required information.

.EXAMPLE
    ./Initialize-Template.ps1 -ModuleName "Invoke-MyModule" -Description "My awesome module" -Author "John Doe" -Company "Contoso"

    Runs non-interactively with all parameters specified.

.EXAMPLE
    ./Initialize-Template.ps1 -Publish PSGallery

    Initializes the template and creates secrets.local.ps1 with your PSGallery API key.
    Prompts interactively if -GalleryApiKey is not supplied.

.EXAMPLE
    ./Initialize-Template.ps1 -Publish GitHub

    Initializes the template and creates secrets.local.ps1 with your GitHub PAT.
    Prompts interactively if -GitHubToken is not supplied.

.EXAMPLE
    ./Initialize-Template.ps1 -Publish PSGallery -GalleryApiKey "abc123"

    Fully non-interactive initialization for PSGallery publishing.

.EXAMPLE
    ./Initialize-Template.ps1 -Publish GitHub -GitHubToken "ghp_xyz"

    Fully non-interactive initialization for GitHub Release publishing.

.EXAMPLE
    ./Initialize-Template.ps1 -WhatIf

    Preview mode - shows what changes would be made without making them.

.NOTES
    This script removes itself after successful completion.
    Make sure to commit any changes to git after initialization.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $ModuleName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $Description,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $Author,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $Company,

    [Parameter()]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]
    $ModuleGuid,

    [Parameter()]
    [ValidateSet('PSGallery', 'GitHub')]
    [string]
    $Publish,

    [Parameter()]
    [string]
    $GalleryApiKey,

    [Parameter()]
    [string]
    $GitHubToken
)

#region Helper Functions

function Test-ApprovedVerb {
    param([string]$Name)
    
    if ($Name -notmatch '^[A-Z][a-z]+-[A-Z]') {
        return $false
    }
    
    $verb = $Name -replace '-.*$', ''
    $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
    
    return $verb -in $approvedVerbs
}

function Write-ColorMessage {
    param(
        [string]$Message,
        [string]$Type = 'Info'  # Info, Success, Warning, Error
    )
    
    $symbol = switch ($Type) {
        'Success' { if ($PSStyle) { "$($PSStyle.Foreground.Green)✓$($PSStyle.Reset)" } else { '✓' } }
        'Warning' { if ($PSStyle) { "$($PSStyle.Foreground.Yellow)⚠$($PSStyle.Reset)" } else { '⚠' } }
        'Error'   { if ($PSStyle) { "$($PSStyle.Foreground.Red)✗$($PSStyle.Reset)" } else { '✗' } }
        default   { if ($PSStyle) { "$($PSStyle.Foreground.Cyan)ℹ$($PSStyle.Reset)" } else { 'ℹ' } }
    }
    
    Write-Host "$symbol $Message"
}

#endregion

#region Main Script

try {
    $scriptPath = $PSCommandPath
    $templateRoot = Split-Path -Parent $scriptPath
    
    Write-ColorMessage "PowerShell Module Template Initialization" -Type Info
    Write-Host ""
    
    # Prompt for missing parameters
    if (-not $ModuleName) {
        do {
            $ModuleName = Read-Host "Module Name (e.g., Invoke-MyModule, Get-MyData)"
            
            if (-not $ModuleName) {
                Write-ColorMessage "Module name is required." -Type Error
                continue
            }
            
            if (-not (Test-ApprovedVerb -Name $ModuleName)) {
                Write-ColorMessage "Module name must follow PowerShell Verb-Noun naming convention with an approved verb." -Type Error
                Write-ColorMessage "Examples: Invoke-MyModule, Get-MyData, Set-Configuration" -Type Info
                Write-Host "  Approved verbs: $(((Get-Verb).Verb | Select-Object -First 10) -join ', '), ..." -ForegroundColor Gray
                $ModuleName = $null
            }
        } while (-not $ModuleName)
    } else {
        if (-not (Test-ApprovedVerb -Name $ModuleName)) {
            throw "Module name '$ModuleName' must follow PowerShell Verb-Noun naming convention with an approved verb."
        }
    }
    
    if (-not $Description) {
        do {
            $Description = Read-Host "Description (what does your module do?)"
            if (-not $Description) {
                Write-ColorMessage "Description is required." -Type Error
            }
        } while (-not $Description)
    }
    
    if (-not $Author) {
        do {
            $Author = Read-Host "Author Name"
            if (-not $Author) {
                Write-ColorMessage "Author name is required." -Type Error
            }
        } while (-not $Author)
    }
    
    if (-not $Company) {
        do {
            $Company = Read-Host "Company/Organization"
            if (-not $Company) {
                Write-ColorMessage "Company name is required." -Type Error
            }
        } while (-not $Company)
    }
    
    if (-not $ModuleGuid) {
        $ModuleGuid = [guid]::NewGuid().ToString()
        Write-ColorMessage "Generated GUID: $ModuleGuid" -Type Info
    }
    
    # Confirm before proceeding
    Write-Host ""
    Write-Host "Template will be initialized with:" -ForegroundColor Cyan
    Write-Host "  Module Name : $ModuleName" -ForegroundColor Gray
    Write-Host "  Description : $Description" -ForegroundColor Gray
    Write-Host "  Author      : $Author" -ForegroundColor Gray
    Write-Host "  Company     : $Company" -ForegroundColor Gray
    Write-Host "  GUID        : $ModuleGuid" -ForegroundColor Gray
    Write-Host ""
    
    if (-not $WhatIfPreference) {
        $confirm = Read-Host "Continue? (Y/n)"
        if ($confirm -and $confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-ColorMessage "Initialization cancelled by user." -Type Warning
            return
        }
    }
    
    # Define replacement mappings
    $replacements = @{
        '{{MODULE_NAME}}'        = $ModuleName
        '{{MODULE_DESCRIPTION}}' = $Description
        '{{AUTHOR}}'             = $Author
        '{{COMPANY}}'            = $Company
        '{{MODULE_GUID}}'        = $ModuleGuid
        'TemplateModule'         = $ModuleName
    }
    
    # Get all text files (exclude binary files and git folder)
    $textExtensions = @('*.ps1', '*.psm1', '*.psd1', '*.md', '*.txt', '*.yml', '*.yaml', '*.json')
    $filesToUpdate = Get-ChildItem -Path $templateRoot -Recurse -File -Include $textExtensions |
        Where-Object { $_.FullName -notlike '*\.git\*' -and $_.FullName -notlike '*\output\*' }
    
    Write-Host ""
    Write-ColorMessage "Updating $($filesToUpdate.Count) files..." -Type Info
    
    $updatedCount = 0
    foreach ($file in $filesToUpdate) {
        if ($PSCmdlet.ShouldProcess($file.FullName, "Replace placeholders")) {
            $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
            $originalContent = $content
            
            foreach ($key in $replacements.Keys) {
                $content = $content -replace [regex]::Escape($key), $replacements[$key]
            }
            
            if ($content -ne $originalContent) {
                Set-Content -Path $file.FullName -Value $content -NoNewline -ErrorAction Stop
                $updatedCount++
                Write-Host "  Updated: $($file.Name)" -ForegroundColor Gray
            }
        }
    }
    
    Write-ColorMessage "Updated $updatedCount files." -Type Success
    
    # Rename TemplateModule files
    Write-Host ""
    Write-ColorMessage "Renaming TemplateModule files to $ModuleName..." -Type Info
    
    $filesToRename = Get-ChildItem -Path $templateRoot -Recurse -File |
        Where-Object { $_.Name -like '*TemplateModule*' -and $_.FullName -notlike '*\.git\*' }
    
    foreach ($file in $filesToRename) {
        $newName = $file.Name -replace 'TemplateModule', $ModuleName
        $newPath = Join-Path -Path $file.DirectoryName -ChildPath $newName
        
        if ($PSCmdlet.ShouldProcess($file.FullName, "Rename to $newName")) {
            Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop
            Write-Host "  Renamed: $($file.Name) → $newName" -ForegroundColor Gray
        }
    }
    
    Write-ColorMessage "Renamed $($filesToRename.Count) files." -Type Success

    # Create secrets.local.ps1 scoped to the chosen publish target
    if ($Publish) {
        Write-Host ""
        Write-ColorMessage "Setting up publish credentials for $Publish (secrets.local.ps1)..." -Type Info

        $secretsLines = @(
            "# secrets.local.ps1 — gitignored, never commit this file.",
            "# Generated by Initialize-Template.ps1 for Publish: $Publish",
            "#",
            "# Load credentials into your session before publishing:",
            "#   . ./secrets.local.ps1",
            "#   ./build.ps1 -tasks $(if ($Publish -eq 'PSGallery') { 'publish_psgallery' } else { 'publish_github' })",
            ""
        )

        if ($Publish -eq 'PSGallery') {
            if (-not $GalleryApiKey) {
                do {
                    $GalleryApiKey = Read-Host "PSGallery API Key (from https://www.powershellgallery.com/account/apikeys)"
                    if (-not $GalleryApiKey) {
                        Write-ColorMessage "PSGallery API Key is required for -Publish PSGallery." -Type Error
                    }
                } while (-not $GalleryApiKey)
            }
            $secretsLines += "`$env:PSGALLERY_API_KEY = '$GalleryApiKey'"
        }
        elseif ($Publish -eq 'GitHub') {
            if (-not $GitHubToken) {
                do {
                    $GitHubToken = Read-Host "GitHub PAT with 'repo' scope (from https://github.com/settings/tokens)"
                    if (-not $GitHubToken) {
                        Write-ColorMessage "GitHub token is required for -Publish GitHub." -Type Error
                    }
                } while (-not $GitHubToken)
            }
            $secretsLines += "`$env:GITHUB_TOKEN = '$GitHubToken'"
        }

        $secretsDest = Join-Path -Path $templateRoot -ChildPath 'secrets.local.ps1'

        if ($PSCmdlet.ShouldProcess($secretsDest, "Create secrets.local.ps1 for $Publish")) {
            Set-Content -Path $secretsDest -Value ($secretsLines -join "`n") -NoNewline -ErrorAction Stop
            Write-ColorMessage "Created secrets.local.ps1 (gitignored — never commit this file)." -Type Success
        }
    }

    # Verify no placeholders remain
    Write-Host ""
    Write-ColorMessage "Verifying all placeholders were replaced..." -Type Info
    
    $remainingPlaceholders = Get-ChildItem -Path $templateRoot -Recurse -File -Include $textExtensions |
        Where-Object { $_.FullName -notlike '*\.git\*' -and $_.FullName -notlike '*\output\*' } |
        Select-String -Pattern '\{\{[A-Z_]+\}\}' -SimpleMatch:$false
    
    if ($remainingPlaceholders) {
        Write-ColorMessage "Warning: Found remaining placeholders in:" -Type Warning
        $remainingPlaceholders | ForEach-Object {
            Write-Host "  $($_.Filename): $($_.Line.Trim())" -ForegroundColor Yellow
        }
    } else {
        Write-ColorMessage "All placeholders successfully replaced." -Type Success
    }
    
    # Final message
    Write-Host ""
    Write-ColorMessage "Template initialization complete!" -Type Success
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review the generated files" -ForegroundColor Gray
    Write-Host "  2. Run: ./build.ps1 -ResolveDependency -tasks build" -ForegroundColor Gray
    Write-Host "  3. Run: ./build.ps1 -tasks test" -ForegroundColor Gray
    Write-Host "  4. Start adding your functions to source/Public/" -ForegroundColor Gray
    Write-Host "  5. Commit your changes to git" -ForegroundColor Gray
    if ($Publish) {
        $publishTask = if ($Publish -eq 'PSGallery') { 'publish_psgallery' } else { 'publish_github' }
        Write-Host ""
        Write-Host "To publish your module to $Publish:" -ForegroundColor Cyan
        Write-Host "  . ./secrets.local.ps1                      # load credentials" -ForegroundColor Gray
        Write-Host "  ./build.ps1 -tasks build                   # build the module" -ForegroundColor Gray
        Write-Host "  ./build.ps1 -tasks $publishTask" -ForegroundColor Gray
        Write-Host "  NOTE: secrets.local.ps1 is gitignored — do not commit it." -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Remove this script
    if (-not $WhatIfPreference) {
        Write-ColorMessage "Removing initialization script..." -Type Info
        if ($PSCmdlet.ShouldProcess($scriptPath, "Remove initialization script")) {
            Remove-Item -Path $scriptPath -Force -ErrorAction Stop
            Write-ColorMessage "Initialization script removed." -Type Success
        }
    } else {
        Write-ColorMessage "WhatIf: Would remove initialization script." -Type Info
    }
    
} catch {
    Write-ColorMessage "Initialization failed: $($_.Exception.Message)" -Type Error
    Write-Host ""
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

#endregion
