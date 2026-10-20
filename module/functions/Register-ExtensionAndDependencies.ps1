# <copyright file="Register-ExtensionAndDependencies.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Register-ExtensionAndDependencies {
    <#
        .SYNOPSIS
        Registers an extension and its dependencies.

        .DESCRIPTION
        A recursive function responsible for registering the specified extension and its dependencies.

        Each extension's metadata includes a 'LockEntry' that records how it was requested and resolved: its source, the requested git reference or version, the commit or version that was installed, and which extension required it.

        An extension can request a 'MinimumVersion' instead of a 'Version' or 'GitRef'.
        It is installed at the newest release from that version up to, but not including, the next major version: a module version from a PowerShell repository, or a git tag named after a semantic version (for example, '1.4.2' or 'v1.4.2').
        An installed release in that range is used as it is.
        Its lock entry records the range (for example, '[1.4.0,2.0.0)') as the requested version and, for a git repository, the release tag as 'resolvedRef'.

        When locked extensions are provided, an extension whose lock entry matches how it is requested is installed at the commit or version recorded in the lock entry.
        For a 'MinimumVersion', the lock entry matches when it has the same source and its version is in the range, whatever range it records as requested.
        Before any of the extension's code runs, an error is thrown if its content differs from the lock entry.
        The tasks of an extension that does not match its lock entry are not found, so its code does not run before the difference is reported.

        .PARAMETER ExtensionConfig
        A hashtable containing the initial extension metadata provided by the user.
        This parameter is mandatory.

        .PARAMETER TargetPath
        The path to the folder where ZeroFailed extensions are installed (typically '.zf/extensions').
        This parameter is mandatory.

        .PARAMETER RequiredBy
        The name of the extension that declared this extension as a dependency.
        Omit this for an extension that is configured directly.

        .PARAMETER LockedExtensions
        The extensions recorded in the extensions lock file, keyed by name.
        When omitted, extensions are resolved without using a lock file.

        .EXAMPLE
        PS:> $extensionConfig = @{
            Name = "MyExtension"
            Path = "C:\Extensions\MyExtension"
            Repository = "https://example.com/extensions"
        }
        PS:>Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath "$PWD/.zf/extensions"
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
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

    # Whether the extension was installed at the version in the lock file, and whether to skip finding its tasks
    $isLocked = $false
    $skipTaskDiscovery = $false

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

            # A minimum version is recorded as its range, so that it is distinct from a git reference, along with
            # whether it includes pre-release tags
            $source = @{ repository = $extension.GitRepository; folderPath = $splat.RepositoryFolderPath }
            if ($hasMinimumVersion) {
                $source.preRelease = [bool]$extension['PreRelease']
            }
            $requested = $hasMinimumVersion ? (_getExtensionVersionRange -MinimumVersion $extension.MinimumVersion).Text : $splat.GitRef
            $lockEntry = _newExtensionLockEntry -SourceType 'git' `
                                                -Source $source `
                                                -Requested $requested `
                                                -RequiredBy $RequiredBy
            $lockedEntry = $LockedExtensions ? $LockedExtensions[$extension.Name] : $null
            if ($lockedEntry -and $lockedEntry['resolved'] -and
                    (_testExtensionLockEntryMatch -LockEntry $lockedEntry -Entry $lockEntry -MinimumVersion $extension['MinimumVersion'] -PreRelease:([bool]$extension['PreRelease']))) {
                Write-Host "Using locked commit for extension $($extension.Name): $($lockedEntry['resolved'])" -f Cyan
                $splat.Add("LockedCommit", $lockedEntry['resolved'])
                $isLocked = $true
                # A minimum version is installed from the locked release tag
                if ($hasMinimumVersion) {
                    $splat.Add("GitRef", ($lockedEntry['resolvedRef'] ? $lockedEntry['resolvedRef'] : $lockedEntry['requested']))
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
            $requested = $extension.ContainsKey("MinimumVersion") ? (_getExtensionVersionRange -MinimumVersion $extension.MinimumVersion).Text : $extension['Version']
            $lockEntry = _newExtensionLockEntry -SourceType 'psrepository' `
                                                -Source @{ repository = $splat.PSRepository; preRelease = [bool]$extension['PreRelease'] } `
                                                -Requested $requested `
                                                -RequiredBy $RequiredBy
            $lockedEntry = $LockedExtensions ? $LockedExtensions[$extension.Name] : $null
            if ($lockedEntry -and $lockedEntry['resolved'] -and
                    (_testExtensionLockEntryMatch -LockEntry $lockedEntry -Entry $lockEntry -MinimumVersion $extension['MinimumVersion'] -PreRelease:([bool]$extension['PreRelease']))) {
                Write-Host "Using locked version for extension $($extension.Name): v$($lockedEntry['resolved'])" -f Cyan
                $splat.Add("LockedVersion", $lockedEntry['resolved'])
                $isLocked = $true
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

        # When the lock file is used, check the installed extension before any of its code runs, as finding its tasks
        # runs its task files. Local extensions are working copies, so they are not locked.
        if ($LockedExtensions -and $lockEntry.source.type -ne 'path' -and $extension.Enabled) {
            if (!$isLocked) {
                # The difference from the lock file is reported once every extension has been registered
                Write-Verbose "Not finding the tasks of extension $($extension.Name), as it does not match the lock file"
                $skipTaskDiscovery = $true
            }
            elseif ($lockedEntry['contentHash'] -and (_getExtensionContentHash -Path $extension.Path) -ne $lockedEntry['contentHash']) {
                throw ("Extension $($extension.Name) ($($lockEntry.resolved)) does not have the content recorded in the lock file. " +
                       "Delete '$($extension.Path)' to re-install it.")
            }
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
        $extension.Add("availableTasks", ($skipTaskDiscovery ? @() : (Get-ExtensionAvailableTasks -ExtensionPath $extension.Path)))
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