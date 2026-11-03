# <copyright file="_getVersionFromGitTag.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getVersionFromGitTag {
    [CmdletBinding()]
    [OutputType([semver])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Ref
    )

    # A release tag is named after its full semantic version, optionally with a 'v' prefix (e.g. 'refs/tags/v1.4.2').
    # Partial versions are not releases, because tags such as 'v1' are often moved to the latest release.
    if ($Ref -notmatch '^refs/tags/v?(?<version>\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?)$') {
        return $null
    }

    $version = $null
    if (![semver]::TryParse($Matches['version'], [ref]$version)) {
        return $null
    }

    return $version
}
