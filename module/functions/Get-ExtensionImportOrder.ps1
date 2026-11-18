# <copyright file="Get-ExtensionImportOrder.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-ExtensionImportOrder {
    <#
        .SYNOPSIS
        Returns the extensions in the order that their tasks and functions are imported.

        .DESCRIPTION
        An extension's tasks, functions and properties can override those of the extensions that it requires.
        So every extension is imported after its dependencies, including a dependency that several extensions share.

        Otherwise, an extension that is earlier in the given order is imported later, so when 2 extensions define the same task or property, the earlier one's definition is used.
        Each time, the latest extension whose dependencies have all been imported is imported next.
        A dependency can still override an extension that is earlier than it in the given order, when an extension that requires it is earlier still.
        For example, for 'A', 'B' and 'C', where 'C' requires 'A', the order is 'B', 'A' and 'C', so 'C' overrides 'B'.
        Extensions that require each other in a circle, directly or through other extensions, are imported together, the latest of them first.
        They are imported when the latest of them would be, so an extension that is earlier than all of them still takes precedence, and an extension that requires one of them is imported after all of them.

        A dependency that is not in the given extensions (for example, one that a local extension is used in place of) is ignored.

        .PARAMETER Extensions
        The de-duplicated extensions (as returned by Resolve-ExtensionDuplicates), in the order that they were registered.

        .EXAMPLE
        PS:> $importOrder = Get-ExtensionImportOrder -Extensions $deduplicatedExtensions
        For the extensions 'A', 'Common' and 'B', where 'A' and 'B' both require 'Common', returns 'Common', 'B' and 'A'.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $Extensions
    )
    # The first reference to each extension, in the given order, which is its priority: a later extension is imported
    # earlier, so that the definitions of an earlier one take precedence
    $unique = [System.Collections.Generic.List[hashtable]]::new()
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($extension in $Extensions) {
        if ($names.Add($extension.Name)) {
            $unique.Add($extension)
        }
    }

    # The names of the given extensions that each extension requires
    $dependencyNames = @{}
    foreach ($extension in $unique) {
        $dependencyNames[$extension.Name] = @($extension['dependencies'] |
                                                Where-Object { $null -ne $_ -and $names.Contains($_.Name) -and $_.Name -ne $extension.Name } |
                                                ForEach-Object { $_.Name })
    }

    # The names of the extensions that each extension requires, directly or through other extensions
    $requiredNames = @{}
    foreach ($extension in $unique) {
        $required = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $pending = [System.Collections.Generic.Stack[string]]::new()
        $pending.Push($extension.Name)
        while ($pending.Count -gt 0) {
            foreach ($dependencyName in $dependencyNames[$pending.Pop()]) {
                if ($required.Add($dependencyName)) {
                    $pending.Push($dependencyName)
                }
            }
        }
        $requiredNames[$extension.Name] = $required
    }

    # Extensions that require each other in a circle are imported together, as none of them can be imported after all
    # of the others. Each group has its extensions latest first, and the extensions outside it that they require.
    $groups = [System.Collections.Generic.List[hashtable]]::new()
    $grouped = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    for ($i = $unique.Count - 1; $i -ge 0; $i--) {
        $extension = $unique[$i]
        if (!$grouped.Add($extension.Name)) {
            continue
        }
        $members = [System.Collections.Generic.List[hashtable]]::new()
        $members.Add($extension)
        for ($j = $i - 1; $j -ge 0; $j--) {
            $other = $unique[$j]
            if ($requiredNames[$extension.Name].Contains($other.Name) -and $requiredNames[$other.Name].Contains($extension.Name)) {
                $grouped.Add($other.Name) | Out-Null
                $members.Add($other)
            }
        }
        $memberNames = @($members | ForEach-Object { $_.Name })
        $groups.Add(@{
            Members = $members
            DependencyNames = @($members | ForEach-Object { $dependencyNames[$_.Name] } | Where-Object { $_ -notin $memberNames } | Select-Object -Unique)
        })
    }

    # Each time, the group whose dependencies have all been imported and whose latest extension is the latest is imported
    # next. The groups are in that order, so it is the first one that is ready.
    $ordered = [System.Collections.Generic.List[hashtable]]::new()
    $imported = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    while ($groups.Count -gt 0) {
        $next = $groups | Where-Object { !($_.DependencyNames | Where-Object { !$imported.Contains($_) }) } | Select-Object -First 1
        $next ??= $groups[0]
        foreach ($member in $next.Members) {
            $ordered.Add($member)
            $imported.Add($member.Name) | Out-Null
        }
        $groups.Remove($next) | Out-Null
    }

    return $ordered.ToArray()
}
