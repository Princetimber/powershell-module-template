#Requires -Version 7.0

<#
.SYNOPSIS
    Logging module for TemplateModule with single-file appending.

.DESCRIPTION
    Provides centralized logging to a single file with:
    - Single log file (no timestamp in filename)
    - Automatic log rotation when file gets too large
    - Thread-safe writes
    - ANSI color output
    - Sensitive data redaction
#>

# ============================================================================
# LOG FILE CONFIGURATION
# ============================================================================

# Maintain compatibility with existing $Global:LogFile usage
if (-not $Global:LogFile) {
    $Global:LogFile = "$env:TEMP\TemplateModule_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
}

# Use Global variable as the primary log file path (for backward compatibility)
if (-not $script:LogFile) {
    $script:LogFile = $Global:LogFile
}

# Log rotation settings
$script:MaxLogSizeBytes = 10MB  # Rotate when log exceeds this size
$script:MaxLogFiles = 5         # Keep this many rotated logs

$script:LogDirectoryCreated = $false
$script:LogMutex = $null

# ============================================================================
# WRITE-LOG FUNCTION
# ============================================================================

function Write-Log {
    <#
.SYNOPSIS
    Writes a message to a single, persistent log file with timestamp and log level.

.DESCRIPTION
    Thread-safe logging function optimized for PowerShell 7+ with ANSI color support.
    - Appends to a single log file (no timestamp in filename)
    - Automatic log rotation when file gets too large
    - Supports multiple log levels: INFO, DEBUG, WARN, ERROR, SUCCESS
    - Automatically redacts sensitive information
    - Thread-safe for parallel operations

.PARAMETER Message
    The message to log. Sensitive values are automatically redacted.

.PARAMETER Level
    The severity level: INFO, DEBUG, WARN, ERROR, SUCCESS. Default is INFO.

.PARAMETER NoConsole
    Suppress console output. Message will only be written to log file.

.PARAMETER PassThru
    Returns $true if log write succeeded, $false otherwise.

.PARAMETER ErrorRecord
    An ErrorRecord object to log with detailed information.

.EXAMPLE
    Write-Log "Operation started"

.EXAMPLE
    Write-Log "Configuration loaded" -Level DEBUG

.EXAMPLE
    Write-Log "Operation completed successfully" -Level SUCCESS

.EXAMPLE
    Write-Log "Operation failed" -Level ERROR

.EXAMPLE
    try {
        # Some operation
    }
    catch {
        Write-Log -ErrorRecord $_
    }

.NOTES
    Log file location: $script:LogFile
    Supports both syntaxes:
    - New: Write-Log "message" -Level INFO
    - Old: Write-Log -Message "message" -Level INFO

    Suppression: PSAvoidGlobalVars - maintains compatibility with $Global:LogFile.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    param (
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            Position = 0,
            ParameterSetName = 'Message'
        )]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(
            Position = 1,
            ParameterSetName = 'Message'
        )]
        [ValidateSet('INFO', 'DEBUG', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',

        [Parameter(
            Mandatory,
            ParameterSetName = 'ErrorRecord'
        )]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter()]
        [switch]$NoConsole,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        # Sync script-scoped variable with global for backward compatibility
        if ($Global:LogFile -and $script:LogFile -ne $Global:LogFile) {
            $script:LogFile = $Global:LogFile
        }

        # Ensure log directory exists (once per invocation)
        if (-not $script:LogDirectoryCreated) {
            $logDir = Split-Path -Path $script:LogFile -Parent

            if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
                try {
                    $null = New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop
                }
                catch [System.IO.IOException] {
                    # Directory may have been created by another process
                    if (-not (Test-Path -LiteralPath $logDir)) {
                        throw
                    }
                }
            }
            $script:LogDirectoryCreated = $true
        }

        # Initialize mutex for thread safety (reuse existing if available)
        if (-not $script:LogMutex) {
            $script:LogMutex = [System.Threading.Mutex]::new($false, "Global\TemplateModuleLog")
        }
    }

    process {
        # Process ErrorRecord if provided
        if ($PSCmdlet.ParameterSetName -eq 'ErrorRecord') {
            $Message = $ErrorRecord.Exception.Message
            $Level = 'ERROR'

            # Add additional error details
            $errorDetails = @"
Exception Type: $($ErrorRecord.Exception.GetType().FullName)
Category: $($ErrorRecord.CategoryInfo.Category)
Target: $($ErrorRecord.TargetObject)
"@

            if ($ErrorRecord.InvocationInfo) {
                $errorDetails += @"

Location: $($ErrorRecord.InvocationInfo.ScriptName):$($ErrorRecord.InvocationInfo.ScriptLineNumber)
Command: $($ErrorRecord.InvocationInfo.Line.Trim())
"@
            }

            if ($ErrorRecord.Exception.InnerException) {
                $errorDetails += @"

Inner Exception: $($ErrorRecord.Exception.InnerException.Message)
"@
            }

            # Log main message first, then details as DEBUG
            Write-Log -Message $Message -Level 'ERROR' -PassThru:$PassThru
            Write-Log -Message $errorDetails -Level 'DEBUG' -PassThru:$PassThru
            return
        }

        # Redact sensitive information from log messages (case-insensitive)
        $sanitizedMessage = $Message

        # Pattern 1: key=value format
        $sanitizedMessage = $sanitizedMessage -replace '(?i)(password|token|key|secret|apikey|api_key|access_key|auth)=\S+', '$1=***REDACTED***'

        # Pattern 2: JSON format
        $sanitizedMessage = $sanitizedMessage -replace '(?i)(password|token|key|secret|apikey|api_key|access_key|auth)"\s*:\s*"[^"]*"', '$1": "***REDACTED***"'

        # Pattern 3: XML/HTML format
        $sanitizedMessage = $sanitizedMessage -replace '(?i)<(password|token|key|secret|apikey|api_key|access_key|auth)>[^<]*<', '<$1>***REDACTED***<'

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $entry = "[$timestamp] [$Level] $sanitizedMessage"

        $success = $true

        if ($PSCmdlet.ShouldProcess($script:LogFile, "Write log entry: $Level")) {
            # Thread-safe file write using mutex
            try {
                $null = $script:LogMutex.WaitOne()

                # Check if log rotation is needed (inside mutex to prevent race conditions)
                if ((Test-Path -LiteralPath $script:LogFile) -and
                    (Get-Item -LiteralPath $script:LogFile).Length -gt $script:MaxLogSizeBytes) {

                    Write-Verbose "Log file exceeds $($script:MaxLogSizeBytes / 1MB)MB, rotating..."
                    Invoke-LogRotation
                }

                # UTF-8 without BOM is default in PowerShell 7+
                # IMPORTANT: Using Add-Content appends to existing file
                Add-Content -LiteralPath $script:LogFile -Value $entry -ErrorAction Stop
            }
            catch {
                $errorMsg = "Failed to write log entry to '{0}': {1}" -f $script:LogFile, $_.Exception.Message
                Write-Warning $errorMsg
                $success = $false
            }
            finally {
                if ($script:LogMutex) {
                    $script:LogMutex.ReleaseMutex()
                }
            }
        }

        # Console output with ANSI colors (PowerShell 7+)
        if (-not $NoConsole) {
            switch ($Level) {
                'ERROR' {
                    Write-Host "$($PSStyle.Foreground.Red)✗ $sanitizedMessage$($PSStyle.Reset)"
                }
                'WARN'  {
                    Write-Host "$($PSStyle.Foreground.Yellow)⚠ $sanitizedMessage$($PSStyle.Reset)"
                }
                'SUCCESS' {
                    Write-Host "$($PSStyle.Foreground.Green)✓ $sanitizedMessage$($PSStyle.Reset)"
                }
                'DEBUG' {
                    Write-Verbose -Message $sanitizedMessage
                }
                default {
                    Write-Host "$($PSStyle.Foreground.Cyan)ℹ $sanitizedMessage$($PSStyle.Reset)"
                }
            }
        }

        if ($PassThru) {
            return $success
        }
    }

    end {
        # Cleanup is handled by caller or module removal
    }
}

# ============================================================================
# LOG ROTATION FUNCTION
# ============================================================================

function Invoke-LogRotation {
    <#
.SYNOPSIS
    Rotates log files when they exceed the maximum size.

.DESCRIPTION
    Renames current log to .1, shifts existing rotated logs up, and removes oldest.
    Example: module.log -> module.log.1
             module.log.1 -> module.log.2
             etc.
#>
    [CmdletBinding()]
    param()

    try {
        # Don't rotate if file doesn't exist
        if (-not (Test-Path -LiteralPath $script:LogFile)) {
            return
        }

        # Remove oldest log file if it exists
        $oldestLog = "$script:LogFile.$script:MaxLogFiles"
        if (Test-Path -LiteralPath $oldestLog) {
            Remove-Item -LiteralPath $oldestLog -Force -ErrorAction SilentlyContinue
        }

        # Shift existing rotated logs up
        for ($i = $script:MaxLogFiles - 1; $i -ge 1; $i--) {
            $currentLog = "$script:LogFile.$i"
            $nextLog = "$script:LogFile.$($i + 1)"

            if (Test-Path -LiteralPath $currentLog) {
                Move-Item -LiteralPath $currentLog -Destination $nextLog -Force -ErrorAction SilentlyContinue
            }
        }

        # Rotate current log to .1
        Move-Item -LiteralPath $script:LogFile -Destination "$script:LogFile.1" -Force -ErrorAction Stop

        Write-Verbose "Log rotated: $script:LogFile -> $script:LogFile.1"
    }
    catch {
        Write-Warning "Failed to rotate log file: $($_.Exception.Message)"
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-ErrorLog {
    <#
.SYNOPSIS
    Safely logs error details without JSON serialization issues.

.PARAMETER ErrorRecord
    The error record to log (typically $_)

.PARAMETER Message
    Custom error message prefix

.PARAMETER IncludeStackTrace
    Include stack trace in the log output

.EXAMPLE
    try {
        # Some operation
    }
    catch {
        Write-ErrorLog -ErrorRecord $_
    }
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter()]
        [string]$Message,

        [Parameter()]
        [switch]$IncludeStackTrace
    )

    # Primary error message
    $errorMsg = if ($Message) {
        "$Message $($ErrorRecord.Exception.Message)"
    } else {
        $ErrorRecord.Exception.Message
    }

    Write-Log -Message $errorMsg -Level 'ERROR'

    # Detailed error information (only with -Verbose)
    Write-Log -Message "Error Type: $($ErrorRecord.Exception.GetType().FullName)" -Level 'DEBUG'
    Write-Log -Message "Error Category: $($ErrorRecord.CategoryInfo.Category)" -Level 'DEBUG'

    if ($ErrorRecord.CategoryInfo.TargetName) {
        Write-Log -Message "Target: $($ErrorRecord.CategoryInfo.TargetName)" -Level 'DEBUG'
    }

    if ($ErrorRecord.InvocationInfo) {
        Write-Log -Message "Location: $($ErrorRecord.InvocationInfo.ScriptName):$($ErrorRecord.InvocationInfo.ScriptLineNumber)" -Level 'DEBUG'
        Write-Log -Message "Command: $($ErrorRecord.InvocationInfo.Line.Trim())" -Level 'DEBUG'
    }

    if ($ErrorRecord.Exception.InnerException) {
        Write-Log -Message "Inner Exception: $($ErrorRecord.Exception.InnerException.Message)" -Level 'DEBUG'
    }

    if ($IncludeStackTrace -and $ErrorRecord.ScriptStackTrace) {
        Write-Log -Message "Stack Trace:`n$($ErrorRecord.ScriptStackTrace)" -Level 'DEBUG'
    }
}

function Get-LogFilePath {
    <#
.SYNOPSIS
    Gets the current log file path.

.EXAMPLE
    $logPath = Get-LogFilePath
    Write-Host "Logging to: $logPath"
#>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return $script:LogFile
}

function Set-LogFilePath {
    <#
.SYNOPSIS
    Sets a custom log file path.

.PARAMETER Path
    Full path to the log file.

.PARAMETER Force
    Create the directory if it doesn't exist.

.EXAMPLE
    Set-LogFilePath -Path "C:\Logs\module.log"

.EXAMPLE
    Set-LogFilePath -Path "$env:ProgramData\MyModule\operations.log" -Force
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [switch]$Force
    )

    if ($PSCmdlet.ShouldProcess($Path, "Set log file path")) {
        $logDir = Split-Path -Path $Path -Parent

        if ($Force -and $logDir -and -not (Test-Path -LiteralPath $logDir)) {
            $null = New-Item -Path $logDir -ItemType Directory -Force
        }

        $script:LogFile = $Path
        $Global:LogFile = $Path  # Maintain backward compatibility
        $script:LogDirectoryCreated = $false  # Force directory check on next write
        Write-Verbose "Log file path set to: $Path"
    }
}

function Clear-LogFile {
    <#
.SYNOPSIS
    Clears the current log file.

.PARAMETER Archive
    Archive the current log before clearing.

.EXAMPLE
    Clear-LogFile

.EXAMPLE
    Clear-LogFile -Archive
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter()]
        [switch]$Archive
    )

    if (-not (Test-Path -LiteralPath $script:LogFile)) {
        Write-Verbose "Log file does not exist: $script:LogFile"
        return
    }

    if ($PSCmdlet.ShouldProcess($script:LogFile, "Clear log file")) {
        if ($Archive) {
            $archiveName = "$script:LogFile.$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
            Copy-Item -LiteralPath $script:LogFile -Destination $archiveName
            Write-Verbose "Log archived to: $archiveName"
        }

        Clear-Content -LiteralPath $script:LogFile
        Write-Log "===== Log file cleared =====" "INFO"
    }
}

function Get-LogFileSize {
    <#
.SYNOPSIS
    Gets the current log file size.

.EXAMPLE
    $size = Get-LogFileSize
    Write-Host "Log file is $($size / 1MB) MB"
#>
    [CmdletBinding()]
    [OutputType([long])]
    param()

    if (Test-Path -LiteralPath $script:LogFile) {
        return (Get-Item -LiteralPath $script:LogFile).Length
    }
    return 0
}
