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

        For each extension that is used, the declarations of it by used extensions decide its metadata:
         - its 'Process', when the occurrence that is used does not declare one, from a declaration that is not otherwise
           kept (for example, an occurrence discarded when reconciling minimum versions, or a dependency that a local
           extension is used in place of). A 'Process' that only an unused extension declared is removed.
         - its lock entry's 'requiredBy', which lists the used extensions that require it.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param (
        # The registered extensions, in the order that they were registered, with the version to use first
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $Extensions
    )

    $newReferenceSet = { , [System.Collections.Generic.HashSet[object]]::new([System.Collections.Generic.ReferenceEqualityComparer]::Instance) }

    # An occurrence from the configuration (an explicitly disabled extension does not have a lock entry)
    $isConfigured = {
        param ($extension)
        !$extension.ContainsKey('LockEntry') -or $extension.LockEntry.direct
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
    foreach ($extension in $Extensions) {
        if ((& $isConfigured $extension) -and $usedNames.Add($extension.Name)) {
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

    foreach ($name in $winners.Keys) {
        if (!$usedNames.Contains($name)) {
            continue
        }
        $winner = $winners[$name]
        $nameDeclarations = $declarations.ContainsKey($name) ? $declarations[$name] : @()

        if (!(& $isConfigured $winner) -and !$declared.Contains($winner) -and $winner.ContainsKey('Process')) {
            Write-Verbose "Not using process '$($winner.Process)' for extension '$name', as only an extension that is not used declares it"
            $winner.Remove('Process')
        }

        # A kept occurrence's 'Process' is used by 'Resolve-ExtensionDuplicates'
        foreach ($item in $nameDeclarations) {
            if (!$kept.Contains($item.Declaration)) {
                _mergeExtensionProcess -Extension $winner -Duplicate $item.Declaration
            }
        }

        if ($winner.ContainsKey('LockEntry')) {
            $winner.LockEntry.requiredBy = [string[]]@($nameDeclarations | ForEach-Object { $_.RequiredBy } | Select-Object -Unique)
        }
    }

    return $used
}
