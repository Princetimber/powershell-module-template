#Requires -Version 7.0

function Get-Greeting {
    <#
    .SYNOPSIS
        Generates a personalized greeting message with enterprise logging and validation.

    .DESCRIPTION
        Creates a formatted greeting message for the specified recipient. Demonstrates
        enterprise PowerShell patterns including:

        - CmdletBinding with SupportsShouldProcess for safe operations
        - Comprehensive input validation with ValidateSet and ValidateNotNullOrEmpty
        - Idempotent behavior (safe to call repeatedly)
        - Enterprise logging via Write-Log
        - PassThru support for rich object output
        - Force parameter for automation scenarios
        - PSStyle-safe error messages with fallbacks

        The function delegates message formatting to the private helper
        Format-GreetingMessage and logs all operations.

    .PARAMETER Name
        The name of the person or entity to greet. Must not be null or empty.
        Accepts pipeline input by value.

    .PARAMETER Style
        The greeting style to use. Valid options are:
        - Formal: Professional greeting (e.g., "Good day, NAME.")
        - Casual: Friendly greeting (e.g., "Hey NAME!")
        - Professional: Business greeting (e.g., "Hello NAME, welcome.")
        Default is 'Professional'.

    .PARAMETER PassThru
        Returns a rich PSCustomObject containing the greeting details instead of
        just the greeting string. Useful for pipeline processing and automation.

    .PARAMETER Force
        Suppresses confirmation prompts. Use for non-interactive automation scenarios.

    .EXAMPLE
        Get-Greeting -Name "World"

        Generates a professional greeting: "Hello World, welcome."

    .EXAMPLE
        Get-Greeting -Name "Alice" -Style Formal -PassThru

        Returns a rich object with greeting details:
        Name     : Alice
        Style    : Formal
        Message  : Good day, Alice.
        Created  : 2025-01-15 10:30:00

    .EXAMPLE
        "Bob", "Carol" | Get-Greeting -Style Casual

        Generates casual greetings for multiple recipients via pipeline:
        Hey Bob!
        Hey Carol!

    .OUTPUTS
        [string]
            The formatted greeting message (default behavior).

        [PSCustomObject]
            When -PassThru is specified, returns an object with properties:
            Name, Style, Message, Created.

    .NOTES
        This is an example function demonstrating enterprise PowerShell patterns.
        Replace this function with your own module logic after running
        Initialize-Template.ps1.

        Enterprise Features: 11/11
        - Guardrails (validation), Comprehensive validation, ShouldProcess,
          Idempotency, Verification, ScriptAnalyzer clean, PassThru, Force,
          Enhanced error messages, Smart behavior, Capacity reporting (N/A).
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([string])]
    [OutputType([PSCustomObject], ParameterSetName = 'PassThru')]
    param (
        [Parameter(
            Position = 0,
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Position = 1)]
        [ValidateSet('Formal', 'Casual', 'Professional')]
        [string]
        $Style = 'Professional',

        [Parameter()]
        [switch]
        $PassThru,

        [Parameter()]
        [switch]
        $Force
    )

    begin {
        if ($Force) {
            $ConfirmPreference = 'None'
        }

        Write-Log -Message "Get-Greeting invoked with Style='$Style'" -Level INFO
    }

    process {
        # Format the greeting using the private helper
        $greeting = Format-GreetingMessage -Name $Name -Style $Style

        if (-not $greeting) {
            $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)$($PSStyle.Reset)" } else { '>' }
            $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)i$($PSStyle.Reset)" } else { 'i' }

            $errorMsg = "Failed to format greeting for '$Name'."
            $errorMsg += "`n`nAvailable styles:"
            $errorMsg += "`n  ${bullet} Formal - Professional greeting"
            $errorMsg += "`n  ${bullet} Casual - Friendly greeting"
            $errorMsg += "`n  ${bullet} Professional - Business greeting"
            $errorMsg += "`n`n${tip} Tip: Ensure the Name parameter is not empty."

            throw $errorMsg
        }

        if ($PSCmdlet.ShouldProcess($Name, "Generate $Style greeting")) {
            Write-Log -Message "Greeting generated for '$Name' with style '$Style'" -Level SUCCESS

            if ($PassThru) {
                return [PSCustomObject]@{
                    PSTypeName = 'Invoke-ADDSDomainController.GreetingResult'
                    Name       = $Name
                    Style      = $Style
                    Message    = $greeting
                    Created    = Get-Date
                }
            }

            return $greeting
        }
    }

    end {
        Write-Log -Message "Get-Greeting completed" -Level INFO
    }
}
