#Requires -Version 7.0

function Test-PreflightCheck {
    <#
    .SYNOPSIS
        Validates system prerequisites for Active Directory Domain Services installation.

    .DESCRIPTION
        Performs comprehensive preflight validation checks to ensure the system meets all requirements
        for installing and configuring an Active Directory Domain Controller. This includes:
        
        - Administrative privilege verification
        - Windows Server platform and SKU validation
        - Required Windows Features installation status
        - Filesystem path existence and accessibility
        - Disk space capacity requirements
        
        The function is designed for enterprise environments with enhanced error reporting,
        smart drive selection, and detailed metrics logging.

    .PARAMETER RequiredModule
        Array of Windows Feature names required for domain controller installation.
        Default: @("AD-Domain-Services")
        
        Validates that each feature is installed. If not, provides actionable guidance
        with a list of available domain-related features.

    .PARAMETER RequiredPaths
        Array of filesystem paths that must exist and be accessible.
        Default: @() (empty array)
        
        If empty, the function performs smart drive selection and validates the drive
        with the most available free space meets minimum capacity requirements.
        
        For each path, validates existence and checks that the parent drive has
        sufficient free space.

    .PARAMETER MinDiskSpaceGB
        Minimum required free disk space in gigabytes for each validated drive.
        Default: 4 GB
        
        Valid range: 1-999 GB

    .PARAMETER PassThru
        Returns a detailed PSCustomObject with validation results and metrics.
        
        Without this switch, the function returns a simple boolean value.
        With this switch, returns an object containing:
        - Success status
        - Counts of modules and paths checked
        - Disk capacity metrics
        - Timestamp

    .EXAMPLE
        Test-PreflightCheck
        
        Performs default validation with AD-Domain-Services feature check and automatic
        drive selection. Returns $true if all checks pass.

    .EXAMPLE
        Test-PreflightCheck -RequiredModule @("AD-Domain-Services", "DNS") -MinDiskSpaceGB 10
        
        Validates that both AD-Domain-Services and DNS features are installed, and that
        the system has at least 10 GB of free disk space.

    .EXAMPLE
        Test-PreflightCheck -RequiredPaths @("C:\NTDS", "D:\Logs") -PassThru
        
        Validates that both paths exist with sufficient disk space, and returns a detailed
        validation object with metrics.

    .EXAMPLE
        $result = Test-PreflightCheck -RequiredModule @("RSAT-AD-PowerShell") -PassThru
        if ($result.Success) {
            Write-Host "Validation passed. Checked $($result.ModulesChecked) modules."
        }
        
        Uses PassThru to get detailed results and conditionally process them.

    .OUTPUTS
        System.Boolean
            Returns $true if all validation checks pass, $false otherwise (default behavior).
        
        PSCustomObject (with -PassThru)
            Returns detailed validation results with the following properties:
            - PSTypeName: 'Invoke-ADDSDomainController.PreflightResult'
            - Success: Boolean indicating overall validation status
            - ModulesChecked: Count of Windows Features validated
            - PathsChecked: Count of filesystem paths validated
            - TotalDiskSpaceGB: Total free disk space across all checked drives
            - MinDiskSpaceRequired: Minimum disk space requirement (GB)
            - Timestamp: DateTime of validation completion

    .NOTES
        Requirements:
        - Windows Server operating system (Server SKU required)
        - Administrative privileges (elevation required)
        - PowerShell 7.0 or higher
        
        This is a private helper function used internally by public module functions.
        
        The function uses Write-Log for enterprise-grade logging with automatic
        sensitive data redaction and thread-safe file operations.
    #>
    
    [CmdletBinding()]
    [OutputType([bool], ParameterSetName = 'Default')]
    [OutputType([PSCustomObject], ParameterSetName = 'PassThru')]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $RequiredModule = @("AD-Domain-Services"),

        [Parameter(Position = 1)]
        [AllowEmptyCollection()]
        [string[]]
        $RequiredPaths = @(),

        [Parameter(Position = 2)]
        [ValidateRange(1, 999)]
        [int]
        $MinDiskSpaceGB = 4,

        [Parameter()]
        [switch]
        $PassThru
    )

    Write-Log -Message "Starting preflight validation checks" -Level INFO

    # Guardrails: Platform validation
    if (-not $IsWindows) {
        $msg = "This function requires Windows Server."
        Write-Log -Message $msg -Level ERROR
        throw $msg
    }

    # Guardrails: Elevation check
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $msg = "This function requires administrative privileges. Please run as Administrator."
        Write-Log -Message $msg -Level ERROR
        throw $msg
    }

    # Guardrails: Windows Server SKU validation
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        if ($os.ProductType -ne 3) {  # 3 = Server
            $msg = "This function requires Windows Server (detected: $($os.Caption))."
            Write-Log -Message $msg -Level ERROR
            throw $msg
        }
        Write-Log -Message "Platform validated: $($os.Caption)" -Level SUCCESS
    }
    catch {
        Write-Log -Message "Failed to validate platform: $($_.Exception.Message)" -Level ERROR
        throw
    }

    # Initialize metrics
    $totalChecks = 0
    $passedChecks = 0
    $totalDiskSpaceGB = 0

    # Check required Windows Features
    Write-Log -Message "Checking required Windows Features: $($RequiredModule -join ', ')" -Level INFO
    foreach ($Module in $RequiredModule) {
        $totalChecks++
        
        try {
            $feature = Get-WindowsFeature -Name $Module -ErrorAction Stop
            
            if (-not $feature.Installed) {
                # Enhanced error message with available options
                $allFeatures = Get-WindowsFeature | Where-Object { $_.Name -like "*Domain*" -or $_.Name -like "*AD*" }
                $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
                $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }
                
                $errorMsg = "Required Windows Feature '$Module' is not installed."
                
                if ($allFeatures) {
                    $featureList = $allFeatures | Select-Object -First 10 | ForEach-Object {
                        $status = if ($_.Installed) { "Installed" } else { "Available" }
                        "  ${bullet} $($_.Name) - $status"
                    }
                    $errorMsg += "`n`nSample domain-related features:`n$($featureList -join "`n")"
                    
                    if ($allFeatures.Count -gt 10) {
                        $errorMsg += "`n  ... and $($allFeatures.Count - 10) more"
                    }
                }
                
                $errorMsg += "`n`n${tip} Tip: Install with 'Install-WindowsFeature -Name $Module -IncludeManagementTools'"
                
                Write-Log -Message $errorMsg -Level ERROR
                throw $errorMsg
            }
            
            Write-Log -Message "Required Windows Feature '$Module' is installed" -Level SUCCESS
            $passedChecks++
        }
        catch [System.Exception] {
            Write-Log -Message "Error checking Windows Feature '$Module': $($_.Exception.Message)" -Level ERROR
            throw
        }
    }

    # Smart behavior: Auto-select drive if no paths specified
    if ($RequiredPaths.Count -eq 0) {
        Write-Log -Message "No paths specified, performing smart drive selection" -Level INFO
        
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt ($MinDiskSpaceGB * 1GB) }
        
        if ($drives) {
            $selected = $drives | Sort-Object -Property @(
                @{Expression = {$_.Free}; Descending = $true}
            ) | Select-Object -First 1
            
            $freeGB = [Math]::Round($selected.Free / 1GB, 2)
            $totalDiskSpaceGB += $freeGB
            
            Write-Log -Message "Auto-selected drive $($selected.Name): with $freeGB GB free (largest available)" -Level INFO
            $totalChecks++
            $passedChecks++
        }
        else {
            $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
            $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }
            
            $allDrives = Get-PSDrive -PSProvider FileSystem
            $driveList = $allDrives | ForEach-Object {
                $freeGB = [Math]::Round($_.Free / 1GB, 2)
                "  ${bullet} $($_.Name): - $freeGB GB free"
            }
            
            $errorMsg = "No drives found with at least $MinDiskSpaceGB GB of free space."
            $errorMsg += "`n`nAvailable drives:`n$($driveList -join "`n")"
            $errorMsg += "`n`n${tip} Tip: Free up disk space or reduce MinDiskSpaceGB requirement"
            
            Write-Log -Message $errorMsg -Level ERROR
            throw $errorMsg
        }
    }

    # Check required paths
    if ($RequiredPaths.Count -gt 0) {
        Write-Log -Message "Checking required paths: $($RequiredPaths -join ', ')" -Level INFO
        
        foreach ($Path in $RequiredPaths) {
            $totalChecks++
            
            if (-not (Test-Path -Path $Path)) {
                $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
                $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }
                
                $parentPath = Split-Path -Path $Path -Parent
                $errorMsg = "Required path '$Path' does not exist."
                
                if ($parentPath -and (Test-Path -Path $parentPath)) {
                    $existingItems = Get-ChildItem -Path $parentPath -ErrorAction SilentlyContinue | Select-Object -First 5
                    if ($existingItems) {
                        $itemList = $existingItems | ForEach-Object {
                            "  ${bullet} $($_.FullName)"
                        }
                        $errorMsg += "`n`nExisting items in parent directory:`n$($itemList -join "`n")"
                    }
                }
                
                $errorMsg += "`n`n${tip} Tip: Create the path with 'New-Item -Path `"$Path`" -ItemType Directory -Force'"
                
                Write-Log -Message $errorMsg -Level ERROR
                throw $errorMsg
            }
            
            Write-Log -Message "Required path '$Path' exists" -Level SUCCESS
            
            # Check disk space for the path's drive
            $DriveLetter = [System.IO.Path]::GetPathRoot($Path) -replace ':\\$', ''
            $Drive = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -eq "${DriveLetter}:\" }
            
            if ($null -ne $Drive) {
                $freeGB = [Math]::Round($Drive.Free / 1GB, 2)
                $totalDiskSpaceGB += $freeGB
                
                if ($Drive.Free -lt ($MinDiskSpaceGB * 1GB)) {
                    $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
                    $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }
                    
                    $errorMsg = "Insufficient disk space on drive $($Drive.Name): (${freeGB} GB free, ${MinDiskSpaceGB} GB required)."
                    
                    $allDrives = Get-PSDrive -PSProvider FileSystem
                    $driveList = $allDrives | ForEach-Object {
                        $driveGB = [Math]::Round($_.Free / 1GB, 2)
                        $status = if ($_.Free -ge ($MinDiskSpaceGB * 1GB)) { "✓ Sufficient" } else { "✗ Insufficient" }
                        "  ${bullet} $($_.Name): - $driveGB GB free - $status"
                    }
                    
                    $errorMsg += "`n`nAll drives:`n$($driveList -join "`n")"
                    $errorMsg += "`n`n${tip} Tip: Free up disk space or use a different drive"
                    
                    Write-Log -Message $errorMsg -Level ERROR
                    throw $errorMsg
                }
                
                Write-Log -Message "Drive $($Drive.Name): has sufficient free space (${freeGB} GB free)" -Level SUCCESS
                $passedChecks++
            }
        }
    }

    # Capacity metrics reporting
    $successRate = if ($totalChecks -gt 0) { [Math]::Round(($passedChecks / $totalChecks) * 100, 2) } else { 100 }
    Write-Log -Message "Preflight validation completed - Total: $totalChecks, Passed: $passedChecks, Failed: $($totalChecks - $passedChecks), Success Rate: $successRate%" -Level SUCCESS

    # Return results
    if ($PassThru) {
        return [PSCustomObject]@{
            PSTypeName           = 'Invoke-ADDSDomainController.PreflightResult'
            Success              = $true
            ModulesChecked       = $RequiredModule.Count
            PathsChecked         = $RequiredPaths.Count
            TotalDiskSpaceGB     = [Math]::Round($totalDiskSpaceGB, 2)
            MinDiskSpaceRequired = $MinDiskSpaceGB
            Timestamp            = Get-Date
        }
    }
    
    return $true
}