# <copyright file="_assertExtensionLockSatisfied.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _assertExtensionLockSatisfied {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $Extensions,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $LockedExtensions,

        [Parameter(Mandatory)]
        [string] $LockFilePath
    )

    $problems = [System.Collections.Generic.List[string]]::new()

    # Describes how an extension was requested, e.g. "'main' from https://github.com/org/repo"
    $describeRequest = {
        param ($entry)
        $source = $entry['source']
        $location = $source['repository'] ?? $source['path']
        $requested = $entry['requested'] ? "'$($entry['requested'])'" : 'the latest version'
        "$requested from $($source['type']) '$location'"
    }

    # Extensions that should have been obtained, but could not be (only the first one found for
    # each name is used, consistent with 'Resolve-ExtensionDuplicates')
    $firstByName = [ordered]@{}
    foreach ($extension in $Extensions) {
        if (!$firstByName.Contains($extension.Name)) {
            $firstByName[$extension.Name] = $extension
        }
    }
    foreach ($extension in $firstByName.Values) {
        if ($extension.ContainsKey('LockEntry') -and !$extension.Enabled -and $extension.LockEntry.source.type -ne 'path') {
            $problems.Add("'$($extension.Name)' could not be installed")
        }
    }

    $entries = _getExtensionLockEntries -Extensions $Extensions
    foreach ($name in $entries.Keys) {
        $entry = $entries[$name]
        $lockedEntry = $LockedExtensions[$name]
        $extension = $firstByName[$name]

        if ($null -eq $lockedEntry) {
            $problems.Add("'$name' is not in the lock file")
        }
        elseif (!(_testExtensionLockEntryMatch -LockEntry $lockedEntry -Entry $entry -MinimumVersion $extension['MinimumVersion'] -PreRelease:([bool]$extension['PreRelease']))) {
            $problems.Add("'$name' is requested as $(& $describeRequest $entry), but the lock file has $(& $describeRequest $lockedEntry)")
        }
        elseif ($entry.source.type -eq 'path') {
            # Local extensions are working copies, so only the request is locked
            continue
        }
        elseif (!$lockedEntry['resolved']) {
            $problems.Add("'$name' has no resolved version in the lock file; delete its installed copy, then run in 'Write' mode to re-install it and record its version")
        }
        elseif ($entry.resolved -ne $lockedEntry['resolved']) {
            $problems.Add("'$name' resolved to '$($entry.resolved)', but the lock file has '$($lockedEntry['resolved'])'")
        }
        elseif ($lockedEntry['contentHash'] -and $entry.contentHash -ne $lockedEntry['contentHash']) {
            $problems.Add("'$name' ($($entry.resolved)) does not have the content recorded in the lock file; delete its installed copy to re-install it")
        }
    }

    $unusedNames = @($LockedExtensions.Keys | Where-Object { !$entries.Contains($_) } | Sort-Object)
    if ($unusedNames.Count -gt 0) {
        Write-Warning "The extensions lock file contains extensions that are no longer used: $($unusedNames -join ', ')"
    }

    if ($problems.Count -gt 0) {
        throw ("The extensions do not match the lock file '$LockFilePath':`n" +
               (($problems | ForEach-Object { "  - $_" }) -join "`n") +
               "`nTo update the lock file, run again with the lock mode set to 'Write' (e.g. `$env:ZF_EXTENSIONS_LOCK_MODE = 'Write').")
    }
}
