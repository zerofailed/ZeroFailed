# <copyright file="_testExtensionLockEntryMatch.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _testExtensionLockEntryMatch {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [AllowNull()]
        [System.Collections.IDictionary] $LockEntry,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Entry,

        [Parameter()]
        [string] $MinimumVersion,

        [Parameter()]
        [switch] $PreRelease
    )

    # A locked extension only applies when it was resolved from the same request, i.e. the
    # same source and the same requested version or git reference. For a minimum version, it applies
    # when the locked version is in the range, as other extensions may have required the same
    # extension with a different minimum version.
    if ($null -eq $LockEntry -or $LockEntry['source'] -isnot [System.Collections.IDictionary]) {
        return $false
    }

    $lockedSource = $LockEntry['source']
    $source = $Entry['source']
    $keys = @($lockedSource.Keys) + @($source.Keys) | Sort-Object -Unique
    foreach ($key in $keys) {
        # Whether a minimum version includes pre-release versions is checked against the locked version instead
        if ($MinimumVersion -and $key -eq 'preRelease') {
            continue
        }
        # Ignore the case of source details (e.g. repository URLs), as well as any trailing '/'
        $lockedValue = "$($lockedSource[$key])".TrimEnd('/')
        $value = "$($source[$key])".TrimEnd('/')
        if ($lockedValue -ne $value) {
            Write-Verbose "Lock entry does not match: source '$key' is '$lockedValue' in the lock file, but '$value' was requested"
            return $false
        }
    }

    if ($MinimumVersion) {
        # The locked version is a module version, or the release tag of a git repository: the one that a minimum
        # version resolved to, or the one that was requested
        $lockedVersion = $null
        if ($lockedSource['type'] -eq 'git') {
            $lockedRef = $LockEntry['resolvedRef'] ? $LockEntry['resolvedRef'] : $LockEntry['requested']
            $lockedVersion = _getVersionFromGitTag -Ref "$lockedRef"
        }
        else {
            [semver]::TryParse("$($LockEntry['resolved'])", [ref]$lockedVersion) | Out-Null
        }

        $range = _getExtensionVersionRange -MinimumVersion $MinimumVersion
        if (!$lockedVersion -or !(_testExtensionVersionInRange -Version $lockedVersion -Range $range -PreRelease:$PreRelease)) {
            Write-Verbose "Lock entry does not match: the locked version '$lockedVersion' is not in $($range.Text)"
            return $false
        }
        return $true
    }

    # Git references are case-sensitive
    if ("$($LockEntry['requested'])" -cne "$($Entry['requested'])") {
        Write-Verbose "Lock entry does not match: '$($LockEntry['requested'])' is in the lock file, but '$($Entry['requested'])' was requested"
        return $false
    }

    return $true
}
