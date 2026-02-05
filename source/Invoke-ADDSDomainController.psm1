<#
    This file is intentionally left empty. It is must be left here for the module
    manifest to refer to. It is recreated during the build process.
  #>


   # dot-Source Private functions
 $PrivateFunctions = Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse
 foreach ($function in $PrivateFunctions) {
     try {
        . $function.FullName
     }
     catch {
        Write-Host "$($PSStyle.Foreground.Red)✗ Failed to dot-source private function file: $($function.FullName). Error: $($_.Exception.Message)$($PSStyle.Reset)"
     }
 }

   # dot-Source Public functions
 $PublicFunctions = Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse
 foreach ($function in $PublicFunctions) {
     try {
        . $function.FullName
        Export-ModuleMember -Function $function.BaseName
     }
     catch {
        Write-Host "$($PSStyle.Foreground.Red)✗ Failed to dot-source public function file: $($function.FullName). Error: $($_.Exception.Message)$($PSStyle.Reset)"
     }
 }
