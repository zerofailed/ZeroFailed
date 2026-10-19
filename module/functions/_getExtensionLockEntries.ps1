# <copyright file="_getExtensionLockEntries.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getExtensionLockEntries {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $Extensions
    )

    # When an extension has been resolved more than once, the first one found is used (consistent with
    # 'Resolve-ExtensionDuplicates'), but every extension that required it is recorded.
    $winners = [ordered]@{}
    $requiredBy = @{}
    $direct = @{}
    foreach ($extension in $Extensions) {
        $name = $extension.Name
        if (!$winners.Contains($name)) {
            $winners[$name] = $extension
            $requiredBy[$name] = [System.Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
            $direct[$name] = $false
        }
        if ($extension.ContainsKey('LockEntry')) {
            foreach ($parent in $extension.LockEntry.requiredBy) {
                $requiredBy[$name].Add($parent) | Out-Null
            }
            $direct[$name] = $direct[$name] -or $extension.LockEntry.direct
        }
    }

    # Sort by name, so the lock file is stable when it is serialized
    [string[]]$names = @($winners.Keys)
    [Array]::Sort($names, [StringComparer]::Ordinal)

    $entries = [ordered]@{}
    foreach ($name in $names) {
        $extension = $winners[$name]

        # Extensions that are disabled, or that could not be obtained, are not locked
        if (!$extension.Enabled -or !$extension.ContainsKey('LockEntry')) {
            continue
        }

        $lockEntry = $extension.LockEntry
        $entry = [ordered]@{
            source = $lockEntry.source
            requested = $lockEntry.requested
            resolved = $lockEntry.resolved
        }

        # A git minimum version also records the release tag that it resolved to
        if ($lockEntry.Contains('resolvedRef') -and $lockEntry.resolvedRef) {
            $entry.resolvedRef = $lockEntry.resolvedRef
        }

        # Local extensions are working copies, so their content is not locked
        if ($lockEntry.source.type -ne 'path') {
            $entry.contentHash = _getExtensionContentHash -Path $extension.Path

            if (!$lockEntry.resolved) {
                Write-Warning ("The installed version of extension '$name' is unknown, because it was installed by an earlier version of ZeroFailed. " +
                               "Delete '$($extension.Path)' and run again to re-install it and record its version in the lock file.")
            }
        }

        $entry.direct = $direct[$name]
        $entry.requiredBy = [string[]]@($requiredBy[$name])
        $entries[$name] = $entry
    }

    return $entries
}
