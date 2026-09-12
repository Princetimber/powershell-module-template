#Requires -Version 7.0

function Format-GreetingMessage {
    # Formats Name into a greeting string per Style (Formal/Casual/Professional).
    # Called only by the public Get-Greeting; ShouldProcess is handled there.
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('\S')]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('Formal', 'Casual', 'Professional')]
        [string]
        $Style = 'Professional'
    )

    $trimmedName = $Name.Trim()

    $greeting = switch ($Style) {
        'Formal' { "Good day, $trimmedName." }
        'Casual' { "Hey $trimmedName!" }
        'Professional' { "Hello $trimmedName, welcome." }
    }

    Write-ToLog -Message "Formatted greeting: Style=$Style, Name=$trimmedName" -Level DEBUG

    return $greeting
}
