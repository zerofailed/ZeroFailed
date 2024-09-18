# <copyright file="Get-FunctionsFileListFromExtension.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-FunctionsFileListFromExtension {
    <#
        .SYNOPSIS
        Finds all the function definitions from a specified extension.

        .DESCRIPTION
        Finds all the files that define functions, whilst excluding any test files using the typical Pester naming convention.

        .PARAMETER FunctionsPath
        The path to where the scripts with the extension's functions are stored.

        .OUTPUTS
        System.IO.FileInfo[]

        Returns an array of paths to the files containing the function definitions.

        .EXAMPLE
        PS:> $functionFiles = Get-FunctionsFileListFromExtension -FunctionsPath "C:\myExtension\functions"
        PS:> $functionFiles | % { . $_ }
    #>

    [CmdletBinding()]
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