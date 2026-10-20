# <copyright file="_resolveExtensionVersionRanges.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _resolveExtensionVersionRanges {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $Extensions
    )

    # The version that an extension resolved to, when it is known (i.e. not a git branch or commit, or a local path)
    $getVersion = {
        param ($extension)
        $lockEntry = $extension.LockEntry
        $version = $null
        if ($lockEntry.source.type -eq 'psrepository' -and $lockEntry.resolved) {
            [semver]::TryParse($lockEntry.resolved, [ref]$version) | Out-Null
        }
        elseif ($lockEntry.source.type -eq 'git') {
            $ref = $lockEntry.Contains('resolvedRef') ? $lockEntry.resolvedRef : $lockEntry.requested
            $version = _getVersionFromGitTag -Ref "$ref"
        }
        $version
    }

    # The version that an extension requires: a range (from a minimum version), an exact version, or nothing that can
    # be checked (e.g. the latest version, or a git branch)
    $getRequirement = {
        param ($extension)
        $lockEntry = $extension.LockEntry
        if ($extension.ContainsKey('MinimumVersion')) {
            $range = _getExtensionVersionRange -MinimumVersion $extension.MinimumVersion
            $preRelease = [bool]$extension['PreRelease']
            @{ Text = "$($range.Text)$($preRelease ? ', including pre-release versions' : '')"; Range = $range; PreRelease = $preRelease; Exact = $null }
        }
        elseif ($lockEntry.requested) {
            $exact = $null
            if ($lockEntry.source.type -eq 'psrepository') {
                [semver]::TryParse($lockEntry.requested, [ref]$exact) | Out-Null
            }
            elseif ($lockEntry.source.type -eq 'git') {
                $exact = _getVersionFromGitTag -Ref $lockEntry.requested
            }
            if ($exact) {
                @{ Text = $lockEntry.requested; Range = $null; Exact = $exact }
            }
        }
    }

    $satisfies = {
        param ($version, $requirement)
        if ($null -eq $version) {
            return $false
        }
        if ($requirement.Range) {
            # A pre-release version only satisfies a minimum version that includes pre-release versions
            return (_testExtensionVersionInRange -Version $version -Range $requirement.Range -PreRelease:$requirement.PreRelease)
        }
        return ($version -eq $requirement.Exact)
    }

    $describeRequirer = {
        param ($extension)
        $extension.LockEntry.direct ? 'The configuration' : "'$($extension.LockEntry.requiredBy -join "', '")'"
    }

    # Find every occurrence of each extension, in the order that they were registered
    $resolved = [System.Collections.Generic.List[hashtable]]::new($Extensions)
    $indicesByName = [ordered]@{}
    for ($i = 0; $i -lt $resolved.Count; $i++) {
        $name = $resolved[$i].Name
        if (!$indicesByName.Contains($name)) {
            $indicesByName[$name] = [System.Collections.Generic.List[int]]::new()
        }
        $indicesByName[$name].Add($i)
    }

    foreach ($name in $indicesByName.Keys) {
        $indices = $indicesByName[$name]
        $first = $resolved[$indices[0]]
        if ($indices.Count -lt 2 -or !$first.ContainsKey('LockEntry')) {
            continue
        }

        $occurrences = @($indices | ForEach-Object { $resolved[$_] } | Where-Object { $_.ContainsKey('LockEntry') })
        $requirements = @(foreach ($occurrence in $occurrences) {
            $requirement = & $getRequirement $occurrence
            if ($requirement) {
                @{ Requirement = $requirement; Extension = $occurrence }
            }
        })

        # Only minimum versions are reconciled; other differences are reported by 'Resolve-ExtensionDuplicates'
        if (!($requirements | Where-Object { $_.Requirement.Range })) {
            continue
        }

        # The configuration can choose a version that the extensions requiring it do not, which takes precedence. Its
        # occurrence is not first when an extension listed before it requires the same extension, as registration is
        # depth-first, so move it to the front.
        $directIndex = $indices | Where-Object { $resolved[$_].ContainsKey('LockEntry') -and $resolved[$_].LockEntry.direct } | Select-Object -First 1
        if ($null -ne $directIndex -and $directIndex -ne $indices[0]) {
            $direct = $resolved[$directIndex]
            $resolved[$directIndex] = $first
            $resolved[$indices[0]] = $direct
            $first = $direct
        }

        # Later steps use the first occurrence of each extension, so it must satisfy every requirement
        $firstVersion = & $getVersion $first
        $unsatisfied = @($requirements | Where-Object { !(& $satisfies $firstVersion $_.Requirement) })
        if ($unsatisfied.Count -eq 0) {
            continue
        }

        if ($first.LockEntry.direct) {
            Write-Warning ("Extension '$name'$($firstVersion ? " $firstVersion" : '') is used because it is in the configuration, but " +
                           (($unsatisfied | ForEach-Object { "$(& $describeRequirer $_.Extension) requires $($_.Requirement.Text)" }) -join '; '))
            continue
        }

        # Otherwise, use the newest occurrence that satisfies every requirement. This happens when an installed copy
        # satisfied the first requirement, but is older than a later requirement needs.
        $best = $occurrences |
                    Where-Object { $_.Enabled } |
                    ForEach-Object {
                        $occurrence = $_
                        $version = & $getVersion $occurrence
                        if ($version -and !($requirements | Where-Object { !(& $satisfies $version $_.Requirement) })) {
                            @{ Extension = $occurrence; Version = $version }
                        }
                    } |
                    Sort-Object -Property { $_.Version } -Descending |
                    Select-Object -First 1

        if (!$best) {
            $details = $requirements | ForEach-Object {
                $version = & $getVersion $_.Extension
                "  - $(& $describeRequirer $_.Extension) requires $($_.Requirement.Text)$($version ? " (resolved to $version)" : '')"
            }
            throw ("No version of extension '$name' satisfies every extension that requires it:`n" +
                   ($details -join "`n") + "`n" +
                   "They may need different major versions. To use one version for all of them, add '$name' to the configuration.")
        }

        Write-Verbose "Using extension '$name' $($best.Version), which satisfies every extension that requires it"
        $bestIndex = $indices | Where-Object { [object]::ReferenceEquals($resolved[$_], $best.Extension) } | Select-Object -First 1
        $resolved[$bestIndex] = $first
        $resolved[$indices[0]] = $best.Extension
    }

    return $resolved.ToArray()
}
