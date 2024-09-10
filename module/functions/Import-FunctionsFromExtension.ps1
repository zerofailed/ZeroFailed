function Import-FunctionsFromExtension {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $FunctionsPath
    )

    $functionsToImport = @()
    if (Test-Path $FunctionsPath) {
        $extensionFunctionFiles = Get-ChildItem -Path $FunctionsPath -Filter "*.ps1" -File |
                                    Where-Object { $_ -notmatch ".Tests.ps1" }
        $extensionFunctionFiles |
            Where-Object { $_ } | 
            ForEach-Object {
                $functionsToImport += $_
            }
    }
    return $functionsToImport
}