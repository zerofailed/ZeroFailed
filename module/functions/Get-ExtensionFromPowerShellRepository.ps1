# <copyright file="Get-ExtensionFromPowerShellRepository.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-ExtensionFromPowerShellRepository {
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