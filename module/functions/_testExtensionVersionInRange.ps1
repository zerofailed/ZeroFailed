# <copyright file="_testExtensionVersionInRange.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _testExtensionVersionInRange {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [semver] $Version,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Range,

        [Parameter()]
        [switch] $PreRelease
    )

    if ($Version.PreReleaseLabel -and !$PreRelease) {
        return $false
    }

    # Compare with the maximum without the pre-release label, so that pre-releases of the next major
    # version (e.g. '2.0.0-beta.1') are outside the range, even though they sort before '2.0.0'
    $baseVersion = [semver]::new($Version.Major, $Version.Minor, $Version.Patch)

    return ($Version -ge $Range.Minimum -and $baseVersion -lt $Range.Maximum)
}
