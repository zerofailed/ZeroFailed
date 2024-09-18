# <copyright file="Get-ExtensionDependencies.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-ExtensionDependencies {
    <#
        .SYNOPSIS
        Retrieves the dependencies of a given extension by reading its `dependencies.psd1` file.

        .DESCRIPTION
        Retrieves the dependencies of a given extension by reading its `dependencies.psd1` file.

        .PARAMETER Extension
        The metadata object for the extension we are resolving dependencies for.

        .INPUTS
        None. You can't pipe objects to Get-ExtensionDependencies.

        .OUTPUTS
        hashtable[]

        Returns the resolved extension metadata for each dependency of the specified extension.

        .EXAMPLE
        PS:> Get-ExtensionDependencies -Extension $extension
        @{
        }
        
        .NOTES
        By convention an extension must declare its dependencies in a `dependencies.psd1` file located alongside
        it's PowerShell module manifest file.  The contents of this file can be in one of two formats:
        
        Short-hand syntax (single or multiple dependencies):
        @(
            'ExtensionA'
        )
        
        Full syntax (single dependency):
        @{
            Name = 'ExtensionA'
            Version = '1.0.0'
        }

        Full syntax (multiple dependencies):
        @(
            @{
                Name = 'ExtensionA'
                Version = '1.0.0'
            }
            @{
                Name = 'ExtensionB'
                Version = '2.0.0'
            }
        )
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable] $Extension
    )

    $deps = @()
    $depConfigPath = Join-Path -Path $Extension.Path -ChildPath 'dependencies.psd1'
    if ((Test-Path $depConfigPath)) {
        $dependencies = Import-PowerShellDataFile -Path $depConfigPath
        
        $dependencies | ForEach-Object {
            try {
                # Use existing logic to resolve the supported syntaxes into the canonical form
                $deps += Resolve-ExtensionMetadata -Value $_
            }
            catch {
                throw "Failed to resolve extension metadata for dependency due to invalid configuration: `n$($_ | ConvertTo-Json)"
            }
        }
        $deps = $dependencies
    }

    return $deps
}
