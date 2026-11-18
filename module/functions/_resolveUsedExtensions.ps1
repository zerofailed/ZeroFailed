# <copyright file="_resolveUsedExtensions.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _resolveUsedExtensions {
    <#
        .SYNOPSIS
        Removes the extensions that only unused extensions require, and completes the metadata of the extensions that are used.

        .DESCRIPTION
        The first occurrence of each extension is the one that is used.
        An extension is used when it is in the configuration, or a used extension requires it.
        So an extension that only a version that is not used requires (for example, the losing version of an extension
        that is referenced at 2 exact versions) is removed, along with every other occurrence that such a version requires.

        For each extension that is used, its references decide its metadata:
         - its 'Process': the first one in the configuration, in the order that it is listed, or else the first one that
           a used extension declares for it, in the order that they were registered. This includes a reference that is
           not otherwise kept (for example, an occurrence discarded when reconciling minimum versions, or a dependency that
           a local extension is used in place of). A warning names any other process. A 'Process' that only an unused
           extension declared is removed, and so is the 'Process' of every other occurrence that is kept, so that
           'Resolve-ExtensionDuplicates' does not use it.
         - its lock entry's 'requiredBy', which lists the used extensions that require it.

        These rules are described in 'docs/adr/0002-resolving-the-extensions-that-are-used.md'.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param (
        # The registered extensions, in the order that they were registered, with the version to use first
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $Extensions,

        # The occurrence that each entry in the configuration registered, in the order of the configuration, including
        # one that was discarded when reconciling minimum versions. They are compared by reference.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $ConfiguredExtensions
    )

    $newReferenceSet = { , [System.Collections.Generic.HashSet[object]]::new([System.Collections.Generic.ReferenceEqualityComparer]::Instance) }

    # An occurrence from the configuration. Whether an occurrence has a lock entry, or whether that entry is marked
    # 'direct', does not decide this: an explicitly disabled dependency has no lock entry, and reconciling minimum
    # versions marks the occurrence that it keeps as 'direct' when it discards one from the configuration.
    $configured = & $newReferenceSet
    foreach ($extension in $ConfiguredExtensions) {
        $configured.Add($extension) | Out-Null
    }
    $isConfigured = {
        param ($extension)
        $configured.Contains($extension)
    }

    # The occurrence of each extension that is used
    $winners = [ordered]@{}
    foreach ($extension in $Extensions) {
        if (!$winners.Contains($extension.Name)) {
            $winners[$extension.Name] = $extension
        }
    }

    # The extensions that are used: those in the configuration, then those that a used extension requires
    $usedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $pending = [System.Collections.Generic.Queue[string]]::new()
    foreach ($extension in $ConfiguredExtensions) {
        if ($usedNames.Add($extension.Name)) {
            $pending.Enqueue($extension.Name)
        }
    }
    while ($pending.Count -gt 0) {
        $winner = $winners[$pending.Dequeue()]
        if (!$winner -or !$winner['Enabled']) {
            continue
        }
        foreach ($dependency in @($winner['dependencies'])) {
            if ($null -ne $dependency -and $usedNames.Add($dependency.Name)) {
                $pending.Enqueue($dependency.Name)
            }
        }
    }

    # The declarations of each extension by the used extensions, in the order that they were registered. A registered
    # dependency is the same object as its declaration.
    $declarations = @{}
    $declared = & $newReferenceSet
    foreach ($name in $winners.Keys) {
        $winner = $winners[$name]
        if (!$usedNames.Contains($name) -or !$winner['Enabled']) {
            continue
        }
        foreach ($dependency in @($winner['dependencies'])) {
            if ($null -eq $dependency) {
                continue
            }
            if (!$declarations.ContainsKey($dependency.Name)) {
                $declarations[$dependency.Name] = [System.Collections.Generic.List[hashtable]]::new()
            }
            $declarations[$dependency.Name].Add(@{ Declaration = $dependency; RequiredBy = $name })
            $declared.Add($dependency) | Out-Null
        }
    }

    # Keep the occurrences of the used extensions that are used, in the configuration, or required by a used extension
    $kept = & $newReferenceSet
    [hashtable[]]$used = @(foreach ($extension in $Extensions) {
        $isWinner = [object]::ReferenceEquals($winners[$extension.Name], $extension)
        if ($usedNames.Contains($extension.Name) -and ($isWinner -or (& $isConfigured $extension) -or $declared.Contains($extension))) {
            $kept.Add($extension) | Out-Null
            $extension
        }
        else {
            Write-Verbose "Not using extension '$($extension.Name)' ($($extension['Path'])), as only an extension that is not used requires it"
        }
    })

    # The processes that each extension is given, in order of precedence: those in the configuration, in the order that
    # they are listed, then those that the used extensions declare, in the order that they were registered. The process
    # of an explicitly disabled reference is not used. A reference that is disabled only because it does not match the
    # lock file still declares its process. They are read before any process is changed, as an occurrence can also be a
    # declaration.
    $processes = @{}
    $addProcess = {
        param ($name, $reference)
        if ($reference.ContainsKey('Process') -and ![string]::IsNullOrEmpty($reference.Process) -and
                (!$reference.ContainsKey('Enabled') -or $reference.Enabled -or $reference['LockMismatch'])) {
            if (!$processes.ContainsKey($name)) {
                $processes[$name] = [System.Collections.Generic.List[string]]::new()
            }
            if (!$processes[$name].Contains($reference.Process)) {
                $processes[$name].Add($reference.Process)
            }
        }
    }
    foreach ($extension in $ConfiguredExtensions) {
        & $addProcess $extension.Name $extension
    }
    foreach ($name in $declarations.Keys) {
        foreach ($item in $declarations[$name]) {
            & $addProcess $name $item.Declaration
        }
    }

    foreach ($name in $winners.Keys) {
        if (!$usedNames.Contains($name)) {
            continue
        }
        $winner = $winners[$name]
        $nameDeclarations = $declarations.ContainsKey($name) ? $declarations[$name] : @()

        # The occurrence that is used takes the first of its processes, and a warning names any other. The other
        # occurrences that are kept no longer declare one, so that 'Resolve-ExtensionDuplicates' does not use it.
        if ($winner['Enabled']) {
            if ($winner.ContainsKey('Process') -and !($processes.ContainsKey($name) -and $processes[$name].Contains($winner.Process))) {
                Write-Verbose "Not using process '$($winner.Process)' for extension '$name', as only an extension that is not used declares it"
            }
            $winner.Remove('Process')
            foreach ($process in ($processes.ContainsKey($name) ? $processes[$name] : @())) {
                _mergeExtensionProcess -Extension $winner -Duplicate @{ Name = $name; Process = $process }
            }
            foreach ($extension in $used) {
                if ($extension.Name -eq $name -and ![object]::ReferenceEquals($extension, $winner)) {
                    $extension.Remove('Process')
                }
            }
        }

        if ($winner.ContainsKey('LockEntry')) {
            $winner.LockEntry.requiredBy = [string[]]@($nameDeclarations | ForEach-Object { $_.RequiredBy } | Select-Object -Unique)
        }
    }

    return $used
}
