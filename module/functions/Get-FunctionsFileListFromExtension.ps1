# <copyright file="Get-FunctionsFileListFromExtension.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-FunctionsFileListFromExtension {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
    param (
        [Parameter(Mandatory=$true)]
        [string] $FunctionsPath
    )

    $functionsToImport = @()
    if (Test-Path $FunctionsPath) {
        $extensionFunctionFiles = Get-ChildItem -Path $FunctionsPath -Filter "*.ps1" -File -Recurse |
                                    Where-Object { $_ -notmatch ".Tests.ps1" }
        $extensionFunctionFiles |
            Where-Object { $_ } | 
            ForEach-Object {
                $functionsToImport += $_
            }
    }
    return $functionsToImport
}