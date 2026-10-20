# <copyright file="Get-ExtensionFromPowerShellRepository.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-ExtensionFromPowerShellRepository {
    <#
        .SYNOPSIS
        Retrieves an extension from a PowerShell module repository.

        .DESCRIPTION
        If not already available as a locally-installed module, this function installs the extension (as PowerShell module) from a specified repository.
        It also derives the additional metadata about the extension required by the tooling.

        .PARAMETER Name
        Specifies the module name of the extension to retrieve.

        .PARAMETER PSRepository
        Specifies the PowerShell module repository from which to retrieve the extension.

        .PARAMETER TargetPath
        Specifies the path where the extension should be installed.

        .PARAMETER Version
        Specifies the version of the extension to retrieve.
        If not specified, the latest version will be retrieved.

        .PARAMETER PreRelease
        Indicates whether to consider pre-release versions of the module when checking for existing and installing new versions.

        .EXAMPLE
        PS:> Get-ExtensionFromPowerShellRepository -Name "MyExtension" -Version "1.0.0" -PSRepository "PSGallery" -TargetPath "C:/MyProject/.zf"
        Retrieves version 1.0.0 of the "MyExtension" extension from the PSGallery repository.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $PSRepository,

        [Parameter(Mandatory=$true)]
        [string] $TargetPath,

        [Parameter()]
        [string] $Version,

        [Parameter()]
        [switch] $PreRelease
    )

    # Retained for backwards-compatibility, the implementation now lives in a private function
    # that also returns the resolved version.
    $additionalMetadata = _getExtensionFromPSRepository @PSBoundParameters
    $additionalMetadata.Remove('ResolvedVersion')

    return $additionalMetadata
}