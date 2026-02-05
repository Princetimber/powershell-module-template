#Requires -Version 7.0

function Invoke-ResourceModule {
    <#
    .SYNOPSIS
        Installs required PowerShell modules from PSGallery with enterprise-grade validation and verification.

    .DESCRIPTION
        Performs idempotent installation of PowerShell modules from the PSGallery repository
        with comprehensive error handling, verification, and metrics reporting.
        
        Key features:
        - Idempotent operation (skips already-installed modules in the specified scope)
        - Automatic PSGallery trust state management (saves and restores original state)
        - Smart scope selection with elevation detection
        - Post-installation verification
        - Enhanced error messages with suggestions for similar modules
        - Detailed metrics reporting (installed/skipped/failed counts, elapsed time)
        - Support for WhatIf/Confirm operations
        
        The function validates module names for security, checks elevation requirements for
        AllUsers scope, and provides actionable error messages when installation fails.

    .PARAMETER Name
        Array of PowerShell module names to install from PSGallery.
        Default: @('Microsoft.PowerShell.SecretManagement', 'Az.KeyVault')
        
        Module names are validated to contain only alphanumeric characters, dots, dashes,
        and underscores to prevent injection attacks.

    .PARAMETER Scope
        Installation scope for the modules.
        Valid values: 'CurrentUser', 'AllUsers'
        Default: 'CurrentUser'
        
        - CurrentUser: Installs to user profile (no elevation required)
        - AllUsers: Installs system-wide (requires administrative privileges)
        
        The function automatically checks for elevation when AllUsers scope is specified.

    .PARAMETER PassThru
        Returns detailed PSCustomObject array with installation results for each module.
        
        Without this switch, the function returns nothing on success.
        With this switch, returns an array of objects containing:
        - Name: Module name
        - Action: 'Installed', 'Skipped', or 'Failed'
        - Version: Module version
        - Scope: Installation scope
        - ErrorMessage: Error details (if Action = 'Failed')

    .PARAMETER Force
        Suppresses confirmation prompts for automation scenarios.
        
        Sets $ConfirmPreference to 'None' for the duration of the function.

    .EXAMPLE
        Invoke-ResourceModule
        
        Installs default modules (SecretManagement and Az.KeyVault) to CurrentUser scope.
        Skips modules that are already installed.

    .EXAMPLE
        Invoke-ResourceModule -Name @("Pester", "PSScriptAnalyzer") -Scope AllUsers
        
        Installs Pester and PSScriptAnalyzer to AllUsers scope (requires elevation).
        Prompts for confirmation before each installation.

    .EXAMPLE
        Invoke-ResourceModule -Name @("Az.Accounts", "Az.Resources") -PassThru -Force
        
        Installs Az modules to CurrentUser scope without confirmation prompts,
        and returns detailed results for each module.

    .EXAMPLE
        $results = Invoke-ResourceModule -Name "InvalidModuleName" -PassThru
        $results | Where-Object { $_.Action -eq 'Failed' }
        
        Attempts to install a module and captures detailed error information,
        including suggestions for similar module names in PSGallery.

    .OUTPUTS
        None (default behavior)
            Function completes silently on success, throws on failure.
        
        PSCustomObject[] (with -PassThru)
            Returns array of installation result objects with properties:
            - Name: String - Module name
            - Action: String - 'Installed', 'Skipped', or 'Failed'
            - Version: Version - Module version (if successful)
            - Scope: String - Installation scope
            - ErrorMessage: String - Error details (only if Action = 'Failed')

    .NOTES
        Requirements:
        - PowerShell 7.0 or higher
        - Internet connectivity to PSGallery
        - Administrative privileges if using -Scope AllUsers
        
        This is a private helper function used internally by public module functions.
        
        The function temporarily sets PSGallery as trusted if needed, but always
        restores the original trust state on completion (even if errors occur).
        
        Module installation is verified post-operation to ensure modules are actually
        available in the specified scope.
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void], ParameterSetName = 'Default')]
    [OutputType([PSCustomObject[]], ParameterSetName = 'PassThru')]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            foreach ($moduleName in $_) {
                if ($moduleName -notmatch '^[a-zA-Z0-9\.\-_]+$') {
                    throw "Invalid module name '$moduleName'. Must contain only alphanumeric, dot, dash, or underscore characters."
                }
            }
            $true
        })]
        [string[]]
        $Name = @('Microsoft.PowerShell.SecretManagement', 'Az.KeyVault'),

        [Parameter()]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]
        $Scope = 'CurrentUser',

        [Parameter()]
        [switch]
        $PassThru,

        [Parameter()]
        [switch]
        $Force
    )

    # Suppress confirmation prompts if Force specified
    if ($Force) {
        $ConfirmPreference = 'None'
    }

    Write-Log -Message "Starting module installation process for $($Name.Count) module(s)" -Level INFO

    # Guardrails: Elevation check for AllUsers scope
    if ($Scope -eq 'AllUsers') {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isElevated) {
            $msg = "Scope 'AllUsers' requires administrative privileges. Use '-Scope CurrentUser' or run as Administrator."
            Write-Log -Message $msg -Level ERROR
            throw $msg
        }
        
        Write-Log -Message "Running with elevation detected. Using scope '$Scope'" -Level INFO
    }
    else {
        Write-Log -Message "Using scope '$Scope' (no administrative privileges required)" -Level INFO
    }

    # Initialize metrics
    $startTime = Get-Date
    $installedCount = 0
    $skippedCount = 0
    $failedCount = 0
    $results = @()

    # Check and save PSGallery trust state
    try {
        $psGallery = Get-PSResourceRepository -Name PSGallery -ErrorAction Stop
    }
    catch {
        $msg = "Failed to access PSGallery repository: $($_.Exception.Message)"
        Write-Log -Message $msg -Level ERROR
        throw $msg
    }

    $originalTrustState = $psGallery.Trusted

    try {
        # Set PSGallery as trusted if needed (will be restored in finally block)
        if (-not $psGallery.Trusted) {
            Write-Log -Message "PSGallery is not trusted. Temporarily setting as trusted for this operation" -Level WARN
            Set-PSResourceRepository -Name PSGallery -Trusted -ErrorAction Stop
        }

        # Process each module
        foreach ($moduleName in $Name) {
            
            if (-not $PSCmdlet.ShouldProcess($moduleName, "Install PowerShell module to scope '$Scope'")) {
                Write-Log -Message "Skipped module '$moduleName' (WhatIf or user declined)" -Level INFO
                $skippedCount++
                
                if ($PassThru) {
                    $results += [PSCustomObject]@{
                        PSTypeName   = 'Invoke-ADDSDomainController.ModuleResult'
                        Name         = $moduleName
                        Action       = 'Skipped'
                        Version      = $null
                        Scope        = $Scope
                        ErrorMessage = 'WhatIf or user declined confirmation'
                    }
                }
                continue
            }

            try {
                # Check if module already installed in the specified scope
                $existingModule = Get-InstalledPSResource -Name $moduleName -ErrorAction SilentlyContinue |
                    Where-Object { 
                        if ($Scope -eq 'AllUsers') {
                            $_.InstalledLocation -like "*ProgramFiles*" -or $_.InstalledLocation -like "*Program Files*"
                        }
                        else {
                            $_.InstalledLocation -like "*$env:USERPROFILE*"
                        }
                    } |
                    Select-Object -First 1

                if ($existingModule) {
                    Write-Log -Message "Module '$moduleName' already installed in scope '$Scope' (v$($existingModule.Version))" -Level SUCCESS
                    $skippedCount++
                    
                    if ($PassThru) {
                        $results += [PSCustomObject]@{
                            PSTypeName   = 'Invoke-ADDSDomainController.ModuleResult'
                            Name         = $moduleName
                            Action       = 'Skipped'
                            Version      = $existingModule.Version
                            Scope        = $Scope
                            ErrorMessage = $null
                        }
                    }
                    continue
                }

                # Install module
                Write-Log -Message "Installing module '$moduleName' from PSGallery to scope '$Scope'" -Level INFO
                
                Install-PSResource -Name $moduleName -Repository PSGallery -Scope $Scope -Confirm:$false -TrustRepository -ErrorAction Stop

                # Verification: Confirm installation succeeded
                $installedModule = Get-InstalledPSResource -Name $moduleName -ErrorAction SilentlyContinue |
                    Where-Object { 
                        if ($Scope -eq 'AllUsers') {
                            $_.InstalledLocation -like "*ProgramFiles*" -or $_.InstalledLocation -like "*Program Files*"
                        }
                        else {
                            $_.InstalledLocation -like "*$env:USERPROFILE*"
                        }
                    } |
                    Select-Object -First 1

                if (-not $installedModule) {
                    throw "Module '$moduleName' installation reported success but module not found in scope '$Scope'"
                }

                Write-Log -Message "Module '$moduleName' installed successfully (v$($installedModule.Version))" -Level SUCCESS
                $installedCount++
                
                if ($PassThru) {
                    $results += [PSCustomObject]@{
                        PSTypeName   = 'Invoke-ADDSDomainController.ModuleResult'
                        Name         = $moduleName
                        Action       = 'Installed'
                        Version      = $installedModule.Version
                        Scope        = $Scope
                        ErrorMessage = $null
                    }
                }
            }
            catch {
                # Enhanced error message with similar modules
                $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
                $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }
                
                $errorMsg = "Failed to install module '$moduleName': $($_.Exception.Message)"
                
                # Try to find similar modules in PSGallery
                try {
                    $similarModules = Find-PSResource -Name "*$moduleName*" -Repository PSGallery -ErrorAction SilentlyContinue |
                        Select-Object -First 5
                    
                    if ($similarModules) {
                        $moduleList = $similarModules | ForEach-Object {
                            "  ${bullet} $($_.Name) (v$($_.Version))"
                        }
                        $errorMsg += "`n`nSimilar modules in PSGallery:`n$($moduleList -join "`n")"
                        
                        if ($similarModules.Count -eq 5) {
                            $errorMsg += "`n  ... search for more with 'Find-PSResource -Name *$moduleName*'"
                        }
                    }
                }
                catch {
                    # Silently continue if similar module search fails - non-critical operation
                    Write-Log -Message "Could not search for similar modules: $($_.Exception.Message)" -Level DEBUG
                }
                
                $errorMsg += "`n`n${tip} Tip: Verify module name with 'Find-PSResource -Name $moduleName'"
                $errorMsg += "`n${tip} Tip: Check network connectivity and PSGallery availability"
                $errorMsg += "`n${tip} Tip: Ensure PSGallery is registered with 'Get-PSResourceRepository'"
                
                Write-Log -Message $errorMsg -Level ERROR
                $failedCount++
                
                if ($PassThru) {
                    $results += [PSCustomObject]@{
                        PSTypeName   = 'Invoke-ADDSDomainController.ModuleResult'
                        Name         = $moduleName
                        Action       = 'Failed'
                        Version      = $null
                        Scope        = $Scope
                        ErrorMessage = $_.Exception.Message
                    }
                }
                else {
                    throw $errorMsg
                }
            }
        }
    }
    finally {
        # Always restore original PSGallery trust state
        if ($originalTrustState -ne $psGallery.Trusted) {
            try {
                Set-PSResourceRepository -Name PSGallery -Trusted:$originalTrustState -ErrorAction Stop
                Write-Log -Message "Restored PSGallery trust state to original setting (Trusted: $originalTrustState)" -Level INFO
            }
            catch {
                Write-Log -Message "Warning: Failed to restore PSGallery trust state: $($_.Exception.Message)" -Level WARN
            }
        }
    }

    # Capacity metrics reporting
    $elapsedTime = (Get-Date) - $startTime
    $totalModules = $Name.Count
    $successRate = if ($totalModules -gt 0) { [Math]::Round((($installedCount + $skippedCount) / $totalModules) * 100, 2) } else { 100 }
    
    Write-Log -Message "Module installation summary - Total: $totalModules, Installed: $installedCount, Skipped: $skippedCount, Failed: $failedCount, Success Rate: $successRate%, Time: $([Math]::Round($elapsedTime.TotalSeconds, 2))s" -Level SUCCESS

    # Return results if PassThru specified
    if ($PassThru) {
        return $results
    }
}