#Requires -Version 7.0

function Write-ToLog {
    <#
    .SYNOPSIS
        Writes a log message to the appropriate PowerShell output stream.

    .DESCRIPTION
        Thin logging wrapper that maps log levels to native PowerShell streams.
        INFO and DEBUG map to Write-Verbose, WARN to Write-Warning, ERROR to
        Write-Error, and SUCCESS to Write-Information. Optionally appends
        timestamped entries to a file via the LogPath parameter.

    .PARAMETER Message
        The message to log. Must not be null or empty.

    .PARAMETER Level
        The severity level: INFO, DEBUG, WARN, ERROR, SUCCESS. Default is INFO.

    .PARAMETER LogPath
        Optional file path to append a timestamped log entry to.

    .EXAMPLE
        Write-ToLog 'Operation started'

        Writes 'Operation started' to the Verbose stream at INFO level.

    .EXAMPLE
        Write-ToLog 'Something went wrong' ERROR

        Writes a non-terminating error with the message to the Error stream.

    .EXAMPLE
        Write-ToLog 'Task complete' SUCCESS -LogPath './app.log'

        Writes to the Information stream and appends a timestamped entry to app.log.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('INFO', 'DEBUG', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',

        [Parameter()]
        [string]$LogPath
    )

    process {
        switch ($Level) {
            'INFO'    { Write-Verbose -Message $Message }
            'DEBUG'   { Write-Verbose -Message $Message }
            'WARN'    { Write-Warning -Message $Message }
            'ERROR'   { Write-Error -Message $Message -ErrorAction Continue }
            'SUCCESS' { Write-Information -MessageData $Message -InformationAction Continue }
        }

        if ($LogPath) {
            $entry = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
            Add-Content -LiteralPath $LogPath -Value $entry -ErrorAction Stop
        }
    }
}
