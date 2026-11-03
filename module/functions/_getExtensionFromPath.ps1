# <copyright file="_getExtensionFromPath.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getExtensionFromPath {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Path
    )

    if (Test-Path $Path) {
        Write-Host "USING PATH: $Name ($Path)" -f Cyan
        $enabled = $true
    }
    else {
        Write-Warning "Extension '$Name' not found at $Path - it has been disabled."
        $enabled = $false
    }

    # Local extensions are used in place, so there is nothing to install and no version to resolve
    $additionalMetadata = @{
        Enabled = $enabled
        ResolvedVersion = $null
    }

    return $additionalMetadata
}
