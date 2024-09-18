# <copyright file="_resolveModuleNameFromPath.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function _resolveModuleNameFromPath {
    <#
        .SYNOPSIS
            Resolves the module name from a given path.

        .DESCRIPTION
            This function resolves the module name from a given path.

        .PARAMETER Path
            The path to the root of the module.

        .INPUTS
            None. You can't pipe objects to _resolveModuleNameFromPath.

        .OUTPUTS
            System.String.

            The name of the module.

        .EXAMPLE
        PS:> _resolveModuleNameFromPath -Path c:\myModule
        myModule
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Path
    )

    $moduleManifestPaths = Get-ChildItem -Path $Path -Filter "*.psd1" | Where-Object { $_.BaseName -ne "dependencies" }
    $moduleManifestPath = $moduleManifestPaths | Select-Object -First 1
    if ($moduleManifestPath.Count -gt 1) {
        Write-Warning "Found multiple module manifest files in '$Path' - using the first one found ($moduleManifestPath.BaseName)"
    }

    return $moduleManifestPath.BaseName
}