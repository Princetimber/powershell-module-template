---
applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"
---

## PowerShell Enterprise Standards (repo-wide for PS files)

This repository follows enterprise-ready PowerShell standards. All code must meet these criteria before merge.

### 1. Core Standards

- **PS7+ Required**: `#Requires -Version 7.0` at top of all files
- **Advanced Functions**: `[CmdletBinding()]` with clear parameter sets
- **SupportsShouldProcess**: Required for any state-changing operation
- **OutputType**: `[OutputType([Type])]` with specific types, never `[void]` for public functions
- **Idempotency**: Safe re-runs must not cause drift or duplicate objects
- **Input Validation**: Mandatory (`ValidateSet`, `ValidatePattern`, `ValidateNotNullOrEmpty`, `ValidateRange`)
- **Position Attributes**: `[Parameter(Position = 0)]` for primary parameters

### 2. Multi-Line Parameter Declarations

✅ **Required Format:**
```powershell
[Parameter(Position = 0, Mandatory)]
[ValidateNotNullOrEmpty()]
[string]
$ParameterName
```

❌ **Not Allowed:**
```powershell
[Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $ParameterName
```

### 3. Comment-Based Help (All Public Functions)

**Required Sections:**
- `.SYNOPSIS` - One-line summary
- `.DESCRIPTION` - Multi-paragraph detailed explanation
- `.PARAMETER` - Every parameter documented (purpose, valid values, impact)
- `.EXAMPLE` - Minimum 3 examples (basic, intermediate, advanced)
- `.OUTPUTS` - What gets returned and when
- `.NOTES` - Permissions, caveats, ScriptAnalyzer suppressions

### 4. Enterprise Logging Standards

**Use Write-Log Pattern (see Write-Log.ps1 reference):**
```powershell
Write-Log -Message "Operation starting" -Level INFO
Write-Log -Message "Warning detected" -Level WARN
Write-Log -Message "Operation succeeded" -Level SUCCESS
Write-Log -Message "Operation failed: $($_.Exception.Message)" -Level ERROR
```

**Logging Requirements:**
- Thread-safe (mutex)
- Automatic rotation (10MB threshold, 5 rotated files)
- Sensitive data redaction
- PSStyle console output with symbols (✗, ⚠, ✓, ℹ)
- UTF-8 without BOM
- No secrets logged

### 5. PSStyle Usage Standards

✅ **Correct - Console Output Only:**
```powershell
Write-Host "$($PSStyle.Foreground.Green)✓ Success$($PSStyle.Reset)"
```

✅ **Correct - Fallback in Thrown Errors/Logs:**
```powershell
$bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
throw "Error`n  ${bullet} Tip: Try this"
```

❌ **Incorrect - Direct in Thrown Errors:**
```powershell
throw "$($PSStyle.Foreground.Red)Error$($PSStyle.Reset)"  # ANSI codes in logs!
```

**Rule:** PSStyle must have fallback when used in any string that will be logged, thrown, or returned.

### 6. Parameter Patterns

**PassThru (Optional for functions returning objects):**
```powershell
[Parameter()][switch]$PassThru

if ($PassThru) {
    return [PSCustomObject]@{
        PSTypeName = '{{MODULE_NAME}}.ResultType'
        Property1  = $value1
    }
}
return $minimalOutput  # e.g., string, char, ID
```

**Force (Required for operations with confirmations):**
```powershell
[Parameter()][switch]$Force

if ($Force) {
    $ConfirmPreference = 'None'
}
```

### 7. Error Handling & Enhanced Messages

**Show Available Options on Errors:**
```powershell
$items = Get-AvailableItems
if (-not $items) {
    $allItems = Get-AllItems
    $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
    $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }
    
    $errorMsg = "No items available."
    if ($allItems) {
        $itemList = $allItems | ForEach-Object {
            "  ${bullet} $($_.Name) - Status: $($_.Status)"
        }
        $errorMsg += "`n`nItems detected:`n$($itemList -join "`n")"
        $errorMsg += "`n`n${tip} Tip: Items must meet criteria X."
    }
    throw $errorMsg
}
```

### 8. Smart Behavior & Capacity Reporting

**Multi-Criteria Selection with Logging:**
```powershell
$selected = $items | 
    Sort-Object -Property @(
        @{Expression = {$_.Priority -eq 'High'}; Descending = $true},
        @{Expression = {$_.Size}; Descending = $true},
        @{Expression = {$_.Name}; Ascending = $true}
    ) |
    Select-Object -First $Count

$info = $selected | ForEach-Object { "$($_.Name) ($($_.Size))" }
Write-Log -Message "Selected $Count of $($items.Count): $($info -join ', ')" -Level INFO
```

**Capacity Metrics:**
```powershell
$totalGB = [Math]::Round($totalCapacity / 1GB, 2)
$usableGB = [Math]::Round($usableCapacity / 1GB, 2)
Write-Log -Message "Capacity - Total: $totalGB GB, Usable: $usableGB GB" -Level INFO
```

### 9. Security & Best Practices

- **Never hardcode**: secrets, tokens, tenant IDs, or endpoints
- **Use SecretManagement**: environment vars, or injected parameters
- **Avoid unsafe execution**: `Invoke-Expression`, untrusted string expansion
- **Error handling**: `try/catch/finally`, throw actionable errors, never swallow exceptions
- **Elevation checks**: Where appropriate (system config, privileged operations)
- **Platform validation**: Verify OS/SKU requirements

### 10. ScriptAnalyzer Compliance

**Target: 0 warnings** before every commit:
```powershell
Invoke-ScriptAnalyzer -Path source/ -Recurse -Settings PSGallery
```

**Approved Suppressions (with documented reason):**
```powershell
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
# Reason: Required for $global:IsWindows platform detection

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
# Reason: Private helper - public wrapper has ShouldProcess

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
# Reason: Function name accurately describes behavior
```

### 11. Microsoft Graph / Entra / Defender

- Always document required scopes/permissions in comment-based help + README
- Implement throttling handling (429) and transient retries (5xx) with exponential backoff
- Handle pagination (`@odata.nextLink`) for list operations
- Validate tenant context at runtime, prefer explicit `-TenantId` for risky operations

### 12. Pre-Commit Checklist

- [ ] `#Requires -Version 7.0` at top
- [ ] Multi-line parameter declarations
- [ ] `[OutputType()]` with specific type
- [ ] Complete comment-based help (all sections)
- [ ] All parameters have validation attributes
- [ ] `SupportsShouldProcess` for state-changing operations
- [ ] `PassThru` parameter where returning objects makes sense
- [ ] `Force` parameter for operations requiring confirmation
- [ ] Enhanced error messages with available options
- [ ] PSStyle usage follows fallback pattern
- [ ] Logging uses Write-Log with appropriate levels
- [ ] ScriptAnalyzer: 0 warnings
- [ ] Idempotency validated

### Enterprise Features Scorecard (Target: 11/11)

**Core (Must Have):**
- [ ] Guardrails integration (elevation, validation)
- [ ] Comprehensive validation (input, dependencies, health)
- [ ] ShouldProcess support (-WhatIf/-Confirm)
- [ ] Full idempotency (safe re-runs)
- [ ] Verification (confirms operations succeeded)
- [ ] ScriptAnalyzer clean (0 warnings)

**Enhanced UX (Should Have):**
- [ ] PassThru support (rich objects)
- [ ] Force parameter (suppress confirmations)
- [ ] Enhanced error messages (actionable guidance)
- [ ] Smart behavior (optimal selection/defaults)

**Operational Excellence (Nice to Have):**
- [ ] Capacity reporting (metrics logged)
- [ ] Helper functions (info, removal, status)

---

**Reference Implementation:** Write-Log.ps1 (enterprise-grade logging)
