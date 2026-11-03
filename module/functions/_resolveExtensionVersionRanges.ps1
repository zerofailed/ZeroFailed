# <copyright file="_resolveExtensionVersionRanges.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _resolveExtensionVersionRanges {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $Extensions,

        # Where to install a version that satisfies every requirement, when no registered version does
        [Parameter(Mandatory)]
        [string] $TargetPath,

        [Parameter()]
        [AllowNull()]
        [System.Collections.IDictionary] $LockedExtensions
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

    # The source of an extension, ignoring whether pre-release versions are included, as the lock file compares it
    $describeSource = {
        param ($extension)
        $source = $extension.LockEntry.source
        $repository = $source.type -eq 'git' ? (_getNormalizedGitRepositoryUrl -RepositoryUrl "$($source['repository'])") : "$($source['repository'])".TrimEnd('/').ToLowerInvariant()
        "$($source.type)|$repository|$($source['folderPath'])"
    }

    # Installs the newest version in every range, when they overlap and every extension requires the same source. Every
    # range ends at the next breaking change (e.g. the next major version), so overlapping ranges overlap in the range of
    # the highest minimum version. Returns the registered extension and its dependencies.
    $registerVersionInEveryRange = {
        param ($name, $requirements)
        if ($requirements | Where-Object { !$_.Requirement.Range }) {
            return
        }
        if (@($requirements | ForEach-Object { & $describeSource $_.Extension } | Select-Object -Unique).Count -gt 1) {
            return
        }

        $highest = $requirements | Sort-Object -Property { $_.Requirement.Range.Minimum } -Descending | Select-Object -First 1
        $minimum = $highest.Requirement.Range.Minimum
        $range = _getExtensionVersionRange -MinimumVersion "$minimum"
        if ($requirements | Where-Object { $_.Requirement.Range.Maximum -ne $range.Maximum }) {
            return
        }

        $source = $highest.Extension.LockEntry.source
        $config = @{ Name = $name; MinimumVersion = "$minimum" }
        if ($source.type -eq 'git') {
            $config.GitRepository = $source.repository
            $config.GitRepositoryFolderPath = $source.folderPath
        }
        else {
            $config.PSRepository = $source.repository
        }
        # A pre-release version is only in every range when every extension includes pre-release versions
        if (!($requirements | Where-Object { !$_.Requirement.PreRelease })) {
            $config.PreRelease = $true
        }

        Write-Host "Installing a version of extension '$name' that satisfies every extension that requires it: $($range.Text)" -f Cyan
        Register-ExtensionAndDependencies -ExtensionConfig $config `
                                          -TargetPath $TargetPath `
                                          -RequiredBy ($highest.Extension.LockEntry.requiredBy | Select-Object -First 1) `
                                          -LockedExtensions $LockedExtensions
    }

    # Whether an extension was installed, whose dependencies may also need to be reconciled
    $installedAny = $false

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

        # An occurrence that does not match the lock file was not installed, and the run fails when the lock file is
        # checked, which reports the reason
        if (@($indices | Where-Object { $resolved[$_]['LockMismatch'] }).Count -gt 0) {
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

        # Otherwise, a version that was not registered may satisfy every requirement (e.g. when an installed copy
        # satisfies one minimum version, and a pre-release satisfies another that includes pre-release versions)
        $installError = $null
        if (!$best) {
            try {
                $registered = @(& $registerVersionInEveryRange $name $requirements)
            }
            catch {
                $installError = $_.Exception.Message
                $registered = @()
            }
            if ($registered.Count -gt 0 -and $registered[0].Enabled) {
                $version = & $getVersion $registered[0]
                if ($version -and !($requirements | Where-Object { !(& $satisfies $version $_.Requirement) })) {
                    $installedAny = $true
                    $indices.Add($resolved.Count)
                    $resolved.AddRange([hashtable[]]$registered)
                    $best = @{ Extension = $registered[0]; Version = $version }
                }
            }
        }

        if (!$best) {
            $details = $requirements | ForEach-Object {
                $version = & $getVersion $_.Extension
                "  - $(& $describeRequirer $_.Extension) requires $($_.Requirement.Text)$($version ? " (resolved to $version)" : '')"
            }
            throw ("No version of extension '$name' satisfies every extension that requires it:`n" +
                   ($details -join "`n") + "`n" +
                   ($installError ? "A version in every range could not be installed: $installError`n" : '') +
                   "They may need different major versions. To use one version for all of them, add '$name' to the configuration.")
        }

        Write-Verbose "Using extension '$name' $($best.Version), which satisfies every extension that requires it"
        $bestIndex = $indices | Where-Object { [object]::ReferenceEquals($resolved[$_], $best.Extension) } | Select-Object -First 1
        $resolved[$bestIndex] = $first
        $resolved[$indices[0]] = $best.Extension
    }

    # The dependencies of an installed extension are registered after it, so reconcile them too
    if ($installedAny) {
        return _resolveExtensionVersionRanges -Extensions $resolved.ToArray() -TargetPath $TargetPath -LockedExtensions $LockedExtensions
    }

    return $resolved.ToArray()
}
