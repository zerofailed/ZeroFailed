# <copyright file="Register-ExtensionAndDependencies.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Register-ExtensionAndDependencies {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param (
        [Parameter(Mandatory=$true)]
        $ExtensionConfig,

        [Parameter(Mandatory=$true)]
        [string] $TargetPath,

        [Parameter()]
        [AllowNull()]
        [string] $RequiredBy,

        [Parameter()]
        [AllowNull()]
        [System.Collections.IDictionary] $LockedExtensions
    )

    [hashtable[]]$processedExtensionConfig = @()

    # Parse the extension configuration item into its canonical form
    $extension = Resolve-ExtensionMetadata -Value $ExtensionConfig -Verbose:$VerbosePreference

    # Prepare the parameters needed for extension registration
    $splat = $extension.Clone()
    $splat.Remove("Process") | Out-Null
    $splat.Remove("Enabled") | Out-Null
    $splat.Add("TargetPath", $TargetPath)

    # Skip further processing is extension is explicitly disabled
    if (!$extension.ContainsKey('Enabled') -or $extension.Enabled) {
        if ($extension.ContainsKey("GitRepository")) {
            # Git-based extension
            $splat.Remove("GitRepository")
            $splat.Add("RepositoryUri", $extension.GitRepository)
            # Set defaults for any optional configuration settings (a minimum version is resolved to a release tag instead)
            $hasMinimumVersion = $extension.ContainsKey("MinimumVersion")
            if (!$extension.ContainsKey("GitRef") -and !$hasMinimumVersion) { $splat.Add("GitRef", 'main') }
            if ($extension.ContainsKey("GitRepositoryFolderPath")) {
                $splat.Remove("GitRepositoryFolderPath")
                $splat.Add("RepositoryFolderPath", $extension.GitRepositoryFolderPath)
            }
            else {
                $splat.Add("RepositoryFolderPath", 'module')
            }

            # A minimum version is recorded as its range, so that it is distinct from a git reference
            $requested = $hasMinimumVersion ? (_getExtensionVersionRange -MinimumVersion $extension.MinimumVersion).Text : $splat.GitRef
            $lockEntry = _newExtensionLockEntry -SourceType 'git' `
                                                -Source @{ repository = $extension.GitRepository; folderPath = $splat.RepositoryFolderPath } `
                                                -Requested $requested `
                                                -RequiredBy $RequiredBy
            $lockedEntry = $LockedExtensions ? $LockedExtensions[$extension.Name] : $null
            # A locked minimum version also needs the release tag that it resolved to
            if ($lockedEntry -and $lockedEntry['resolved'] -and (!$hasMinimumVersion -or $lockedEntry['resolvedRef']) -and
                    (_testExtensionLockEntryMatch -LockEntry $lockedEntry -Entry $lockEntry)) {
                Write-Host "Using locked commit for extension $($extension.Name): $($lockedEntry['resolved'])" -f Cyan
                $splat.Add("LockedCommit", $lockedEntry['resolved'])
                if ($hasMinimumVersion) {
                    $splat.Add("GitRef", $lockedEntry['resolvedRef'])
                }
            }

            # Call the helper that will install the extension from a Git repository if it's not
            # already installed and provide the resulting additional metadata that we need to use the extension
            $result = _getExtensionFromGit @splat
        }
        elseif (!$extension.ContainsKey("Path")) {
            # PowerShell module-based extension
            # Set defaults for any optional configuration settings
            $splat["PSRepository"] = $extension.ContainsKey("PSRepository") ? $extension.PSRepository : $DefaultPSRepository

            # A minimum version is recorded as its range, so that it is distinct from the same exact version
            $requested = $extension.ContainsKey("MinimumVersion") ? (_getExtensionVersionRange -MinimumVersion $extension.MinimumVersion).Text : $extension.Version
            $lockEntry = _newExtensionLockEntry -SourceType 'psrepository' `
                                                -Source @{ repository = $splat.PSRepository; preRelease = [bool]$extension.PreRelease } `
                                                -Requested $requested `
                                                -RequiredBy $RequiredBy
            $lockedEntry = $LockedExtensions ? $LockedExtensions[$extension.Name] : $null
            if ($lockedEntry -and $lockedEntry['resolved'] -and (_testExtensionLockEntryMatch -LockEntry $lockedEntry -Entry $lockEntry)) {
                Write-Host "Using locked version for extension $($extension.Name): v$($lockedEntry['resolved'])" -f Cyan
                $splat.Add("LockedVersion", $lockedEntry['resolved'])
            }

            # Call the helper that will install the extension from a PowerShell module repository if it's not
            # already installed and provide the resulting additional metadata that we need to use the extension
            $result = _getExtensionFromPSRepository @splat
        }
        else {
            # Local file-system-based extension, which is used in place
            $lockEntry = _newExtensionLockEntry -SourceType 'path' -Source @{ path = $extension.Path } -RequiredBy $RequiredBy
            $result = _getExtensionFromPath -Name $extension.Name -Path $extension.Path
        }

        # Add the metadata populated by the helper, recording the resolved version (and release tag) separately
        $lockEntry.resolved = $result.ResolvedVersion
        if ($result.ContainsKey('ResolvedRef')) {
            $lockEntry.resolvedRef = $result.ResolvedRef
        }
        $extension.LockEntry = $lockEntry
        foreach ($key in $result.Keys) {
            if ($key -notin 'ResolvedVersion', 'ResolvedRef') {
                $extension[$key] = $result[$key]
            }
        }

        if ($lockEntry.source.type -eq 'path' -and !$extension.Enabled) {
            # Missing local extension or invalid config
            continue
        }
    }
    else {
        Write-Host "Skipping extension - explicitly disabled"
    }
    
    # If enabled, interrogate the extension for its dependencies and exported tasks? recursive?
    if ($extension.Enabled) {
        Write-Verbose "Checking dependencies for $($extension.Name)"
        $extension.Add("dependencies", (Get-ExtensionDependencies -Extension $extension))
        Write-Verbose "Checking available tasks for $($extension.Name)"
        $extension.Add("availableTasks", (Get-ExtensionAvailableTasks -ExtensionPath $extension.Path))
    }

    $processedExtensionConfig += $extension

    # If enabled, resolve any dependencies for this extension
    if ($extension.Enabled) {
        foreach ($dependency in $extension.dependencies) {
            Write-Host "Processing dependency: $($dependency.Name)"
            $processedExtensionConfig += Register-ExtensionAndDependencies -ExtensionConfig $dependency `
                                                                           -TargetPath $TargetPath `
                                                                           -RequiredBy $extension.Name `
                                                                           -LockedExtensions $LockedExtensions
        }
    }
    
    return $processedExtensionConfig
}