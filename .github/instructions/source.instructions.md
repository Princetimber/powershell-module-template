---
applyTo: "source/**/*.ps1,source/**/*.psm1"
---

## Module Source Standards (source/)

This module follows enterprise-ready PowerShell standards. All source code must meet 11/11 enterprise features before merge.

### 1. Public Functions (source/Public/)

**Required Elements:**
- Advanced Function standards: `[CmdletBinding(SupportsShouldProcess)]` for state-changing operations
- `[OutputType([SpecificType])]` - Never `[void]` for public functions
- Complete comment-based help (see powershell.instructions.md for full requirements)
- Multi-line parameter declarations with validation attributes
- Position attributes for primary parameters
- PassThru support where returning objects makes sense
- Force parameter for operations requiring confirmation

**Example Structure:**
```powershell
#Requires -Version 7.0

function Verb-Noun {
    <#
    .SYNOPSIS / .DESCRIPTION / .PARAMETER / .EXAMPLE / .OUTPUTS / .NOTES
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([TypeName])]
    param(
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $PrimaryParam,
        
        [Parameter()][switch]$PassThru,
        [Parameter()][switch]$Force
    )
    
    if ($Force) { $ConfirmPreference = 'None' }
    
    if ($PSCmdlet.ShouldProcess($Target, $Operation)) {
        Write-Log -Message "Operation starting" -Level INFO
        # Implementation
        Write-Log -Message "Operation completed" -Level SUCCESS
        
        if ($PassThru) { return $richObject }
        return $minimalOutput
    }
}
```

### 2. Private Functions (source/Private/)

**Standards:**
- Same code quality as public functions
- ShouldProcess handled by public wrapper (can be suppressed)
- Must be mockable for testing
- Log all significant operations
- Return appropriate types (never rely on implicit returns)

**Approved Private Functions:**
- **Write-Log.ps1** - Enterprise logging (thread-safe, rotation, redaction, PSStyle)
- **Helper functions** - Info, removal, status checks
- **Validation functions** - Preflight, health checks
- **Selection functions** - Smart algorithms with logging

### 3. Idempotency Requirements

**All state-changing functions must be idempotent:**
```powershell
# Check if resource exists
$existing = Get-Resource -Name $Name -ErrorAction SilentlyContinue

if ($existing) {
    Write-Log -Message "Resource '$Name' already exists" -Level INFO
    
    # Validate configuration matches expectations
    if ($existing.Property -ne $ExpectedValue) {
        throw "Configuration mismatch. Expected: $ExpectedValue, Actual: $($existing.Property)"
    }
    
    if ($PassThru) { return $existing }
    return $existing.Id
}

# Create new resource
$resource = New-Resource @params
Write-Log -Message "Resource '$Name' created" -Level SUCCESS

if ($PassThru) { return $resource }
return $resource.Id
```

**Key Principles:**
- Repeated runs must not cause drift or duplicate objects
- Validate existing resources match expected configuration
- Return existing resources when appropriate
- Log idempotent operations clearly

### 4. External Calls & Abstraction

**All external calls must be abstracted and mockable:**
- Graph API calls → wrapper functions
- REST endpoints → dedicated helper functions
- Active Directory → abstracted cmdlets
- System tools → callable separately

**Example:**
```powershell
# Good - testable/mockable
function Get-ExternalResource {
    # Abstraction allows mocking in tests
}

# Use in main function
$resource = Get-ExternalResource
```

### 5. Enterprise Logging (Write-Log.ps1 Pattern)

**All significant operations must be logged:**
```powershell
Write-Log -Message "Starting operation: $Operation" -Level INFO
Write-Log -Message "Warning: Condition detected" -Level WARN
Write-Log -Message "Operation completed successfully" -Level SUCCESS
Write-Log -Message "Operation failed: $($_.Exception.Message)" -Level ERROR
```

**Write-Log Features (Reference Implementation):**
- Thread-safe using mutex
- Automatic rotation (10MB threshold, 5 rotated files)
- Sensitive data redaction (3 regex patterns)
- PSStyle console output with symbols (✗, ⚠, ✓, ℹ)
- Multiple log levels (ERROR, WARN, SUCCESS, INFO, DEBUG)
- ErrorRecord parameter set for detailed diagnostics
- Helper functions (Write-ErrorLog, Get-LogFilePath, Clear-LogFile, etc.)

### 6. Enhanced Error Messages

**Show available options when operations fail:**
```powershell
$items = Get-AvailableItems -Criteria $Criteria

if (-not $items) {
    $allItems = Get-AllItems
    $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
    $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }
    
    $errorMsg = "No items matching criteria found."
    
    if ($allItems) {
        $itemList = $allItems | ForEach-Object {
            "  ${bullet} $($_.Name) - Status: $($_.Status), Available: $($_.IsAvailable)"
        }
        $errorMsg += "`n`nItems detected:`n$($itemList -join "`n")"
        $errorMsg += "`n`n${tip} Tip: Items must meet criteria X to be available."
    }
    
    throw $errorMsg
}
```

### 7. Smart Selection & Metrics Reporting

**Multi-Criteria Selection with Rationale:**
```powershell
# Smart selection: priority-based sorting
$selected = $items | 
    Sort-Object -Property @(
        @{Expression = {$_.Priority -eq 'High'}; Descending = $true},  # Priority 1
        @{Expression = {$_.Value}; Descending = $true},                # Priority 2
        @{Expression = {$_.Name}; Ascending = $true}                   # Priority 3 (deterministic)
    ) |
    Select-Object -First $Count

# Log selection rationale
$info = $selected | ForEach-Object {
    "$($_.Name) (Priority: $($_.Priority), Value: $($_.Value))"
}
Write-Log -Message "Auto-selected $Count of $($items.Count) items: $($info -join ', ')" -Level INFO
```

**Metrics Reporting:**
```powershell
$totalCount = $items.Count
$processedCount = ($items | Where-Object {$_.Status -eq 'Processed'}).Count
$failedCount = ($items | Where-Object {$_.Status -eq 'Failed'}).Count
$successRate = if ($totalCount -gt 0) { [Math]::Round(($processedCount / $totalCount) * 100, 2) } else { 0 }

Write-Log -Message "Metrics - Total: $totalCount, Processed: $processedCount, Failed: $failedCount, Success Rate: $successRate%" -Level INFO
```

### 8. Security Standards

- **Never hardcode**: tenant IDs, secrets, endpoints, or credentials
- **Elevation checks**: Validate admin privileges where required
- **Platform validation**: Verify OS/SKU meets requirements
- **Input sanitization**: Validate all external input
- **Sensitive data redaction**: Use Write-Log's automatic redaction
- **Secure defaults**: Fail closed, require explicit opt-in for risky operations

### 9. Sampler Compatibility

- Do not break build.ps1 or build.yaml conventions
- Keep module manifest metadata consistent
- Update RequiredModules.psd1 when adding dependencies
- Maintain GitVersion.yml compatibility
- Ensure codecov.yml configuration remains valid

### 10. Enterprise Features Scorecard (11/11 Required)

**Core Requirements (6):**
- [ ] **Guardrails integration** - Requires elevation, validates environment
- [ ] **Comprehensive validation** - Input validation, dependency checks, health status
- [ ] **ShouldProcess support** - Supports -WhatIf/-Confirm
- [ ] **Full idempotency** - Validates existing resource configuration
- [ ] **Verification** - Confirms operations succeeded
- [ ] **ScriptAnalyzer clean** - 0 warnings before commit

**Enhanced UX (4):**
- [ ] **PassThru support** - Returns created/existing resource objects
- [ ] **Force parameter** - Suppresses confirmations for automation
- [ ] **Enhanced error messages** - Shows available options, actionable guidance
- [ ] **Smart behavior** - Optimal selection with logged rationale

**Operational Excellence (1):**
- [ ] **Metrics reporting** - Shows relevant metrics and statistics

**Target: 11/11 features for all public functions**

### 11. Pre-Commit Validation

```powershell
# Run before every commit
Invoke-ScriptAnalyzer -Path source/ -Recurse -Settings PSGallery

# Expected output: 0 warnings
```

**Quality Gates:**
- [ ] ScriptAnalyzer: 0 warnings
- [ ] All public functions have complete comment-based help
- [ ] All parameters have validation attributes
- [ ] Idempotency validated (safe re-runs)
- [ ] Logging uses Write-Log pattern
- [ ] PSStyle usage follows fallback pattern
- [ ] Error messages show available options

---

**Reference Implementation:** Write-Log.ps1 (enterprise-grade logging)  
**Target State:** 11/11 enterprise features, 0 ScriptAnalyzer warnings
