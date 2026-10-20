# <copyright file="_getExtensionVersionRange.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getExtensionVersionRange {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param (
        [Parameter(Mandatory)]
        [string] $MinimumVersion
    )

    # Accept versions with fewer than 3 numeric parts (e.g. '1.4'), as PowerShell does for module versions
    $completeVersion = _getCompleteExtensionVersion -Version $MinimumVersion
    if (!$completeVersion) {
        throw "Invalid minimum version '$MinimumVersion': expected a semantic version, e.g. '1.4.0'"
    }
    $minimum = [semver]$completeVersion

    # Breaking changes are expected in the next major version or, before 1.0.0, when the first non-zero part changes
    if ($minimum.Major -gt 0) {
        $maximum = [semver]::new($minimum.Major + 1, 0, 0)
    }
    elseif ($minimum.Minor -gt 0) {
        $maximum = [semver]::new(0, $minimum.Minor + 1, 0)
    }
    else {
        $maximum = [semver]::new(0, 0, $minimum.Patch + 1)
    }

    # The text uses NuGet's version range notation: the minimum is included, and the maximum is not
    $range = [ordered]@{
        Minimum = $minimum
        Maximum = $maximum
        Text = "[$minimum,$maximum)"
    }

    return $range
}
