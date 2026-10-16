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
        [System.Collections.IDictionary] $Entry
    )

    # A locked extension only applies when it was resolved from the same request, i.e. the
    # same source and the same requested version or git reference.
    if ($null -eq $LockEntry -or $LockEntry['source'] -isnot [System.Collections.IDictionary]) {
        return $false
    }

    $lockedSource = $LockEntry['source']
    $source = $Entry['source']
    $keys = @($lockedSource.Keys) + @($source.Keys) | Sort-Object -Unique
    foreach ($key in $keys) {
        # Ignore the case of source details (e.g. repository URLs), as well as any trailing '/'
        $lockedValue = "$($lockedSource[$key])".TrimEnd('/')
        $value = "$($source[$key])".TrimEnd('/')
        if ($lockedValue -ne $value) {
            Write-Verbose "Lock entry does not match: source '$key' is '$lockedValue' in the lock file, but '$value' was requested"
            return $false
        }
    }

    # Git references are case-sensitive
    if ("$($LockEntry['requested'])" -cne "$($Entry['requested'])") {
        Write-Verbose "Lock entry does not match: '$($LockEntry['requested'])' is in the lock file, but '$($Entry['requested'])' was requested"
        return $false
    }

    return $true
}
