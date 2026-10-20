# <copyright file="Register-Extensions.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Register-Extensions {
    <#
        .SYNOPSIS
        Validates and registers a set of extensions and their dependencies.

        .DESCRIPTION
        This function validates, installs (if necessary) and registers the specified set of ZeroFailed extensions and any dependencies
        they declare, returning a fully-populated set of metadata for all extensions.

        If an extension is considered valid and available, then it will be marked as enabled; otherwise it will be marked as disabled.

        The extensions lock file ('<ZfPath>/extensions.lock.json') records the exact version of every installed extension, including dependencies.
        How it is used depends on the lock mode:

        - Write (default): extensions are resolved as normal, then the lock file is created or updated.
        - Frozen: each extension is installed at the commit or version in the lock file, and an error is thrown if there is no lock file or if any extension differs from it.
        - Off: the lock file is not used.

        Each extension's metadata includes a 'LockEntry' that records how it was requested and resolved.

        When several extensions require the same extension and at least one of them uses a 'MinimumVersion', the version that is used must be in every range that they require:

        - If the configuration includes the extension, that version is used, wherever it is listed, and a warning names each range that it is not in.
        - Otherwise, the first one registered is used if it is in every range.
        - Otherwise, the newest registered version that is in every range is used in its place.
        - If no version is in every range, an error is thrown.

        Without a 'MinimumVersion', the first one registered is used.

        .PARAMETER ExtensionsConfig
        An array of extension configuration objects.

        .PARAMETER DefaultPSRepository
        The default PowerShell repository to use when installing those types of extensions.
        Defaults to 'PSGallery'.

        .PARAMETER ZfPath
        The path to the '.zf' storage directory, where extensions will be installed.

        .PARAMETER LockMode
        How the extensions lock file is used: 'Write' updates it after resolving the extensions, 'Frozen' installs the versions it records and throws an error if any extension differs from it, and 'Off' does not use it.
        Defaults to 'Write'.

        .EXAMPLE
        PS:> $extensionsConfig = @(
            @{
                Name = "PublicExtension"                            # Extension available via PS Gallery, latest stable version
            }
            @{
                Name = "PinnedPublicExtension"                      # Extension available via PS Gallery, specific version
                Version = "1.0.2"
            }
            @{
                Name = "BetaPublicExtension"                        # Extension available via PS Gallery, latest pre-release version
                PreRelease = $true
            }
            @{
                Name = "RangedPublicExtension"                      # Extension available via PS Gallery, newest version from 1.4.0, below 2.0.0
                MinimumVersion = "1.4.0"
            }
            @{
                Name = "PublicExtension"                            # Extension available via a Git repo, using the 'main' branch
                GitRepository = "https://github.com/myorg/PublicExtension"
            }
            @{
                Name = "PublicExtension"                            # Extension available via a Git repo, using a tagged version
                GitRepository = "https://github.com/myorg/PublicExtension"
                GitRef = "refs/tags/1.0.0"
            }
            @{
                Name = "RangedGitExtension"                         # Extension available via a Git repo, newest release tag from 1.4.0, below 2.0.0
                GitRepository = "https://github.com/myorg/RangedGitExtension"
                MinimumVersion = "1.4.0"
            }
            @{
                Name = "PublicExtension"                            # Extension available via a Git repo, using a custom branch
                GitRepository = "https://github.com/myorg/PublicExtension"
                GitRef = "feature/new-stuff"
            }
            @{
                Name = "PublicExtension"                            # Extension available via a Git repo, using the 'main' branch, located in a non-standard folder
                GitRepository = "https://github.com/myorg/PublicExtension"
                GitRepositoryPath = "src/PublicExtension"
            }
            @{
                Path = "~/myLocalExtension/module"                  # Extension being developed locally
            }
            @{
                Path = "/myNonExistantExtension/module"             # Incorrect path to a local extension
            }
        )
        PS:> Register-Extensions -ExtensionsConfig $extensionsConfig -DefaultPSRepository PSGallery -ZfPath "/myproject/.zf"

        @(
            @{
                Name = "PublicExtension"                            # Extension available via PS Gallery, latest stable version
                Version = "1.5.2"
                Path = "/myproject/.zf/extensions/PublicExtension/1.5.2"
                Enabled = $true
            }
            @{
                Name = "PinnedPublicExtension"                      # Extension available via PS Gallery, specific version
                Version = "1.0.2"
                Path = "/myproject/.zf/extensions/PinnedPublicExtension/1.0.2"
                Enabled = $true
            }
            @{
                Name = "BetaPublicExtension"                        # Extension available via PS Gallery, latest pre-release version
                Version = "2.0.0-beta0010"
                Path = "/myproject/.zf/extensions/BetaPublicExtension/2.0.0"
                Enabled = $true
            }
            @{
                Name = "RangedPublicExtension"                      # Extension available via PS Gallery, newest version from 1.4.0, below 2.0.0
                MinimumVersion = "1.4.0"
                Path = "/myproject/.zf/extensions/RangedPublicExtension/1.6.1"
                Enabled = $true
            }
            @{
                Name = "PublicExtension"                            # Extension available via a Git repo, using the 'main' branch
                Version = "main"
                Path = "/myproject/.zf/extensions/PublicExtension/main"
                Enabled = $true
            }
            @{
                Name = "PublicExtension"                            # Extension available via a Git repo, using a tagged version
                Version = "refs/tags/1.0.0"
                Path = "/myproject/.zf/extensions/PublicExtension/refs-tags-1.0.0"
                Enabled = $true
            }
            @{
                Name = "RangedGitExtension"                         # Extension available via a Git repo, newest release tag from 1.4.0, below 2.0.0
                MinimumVersion = "1.4.0"
                Path = "/myproject/.zf/extensions/RangedGitExtension/refs-tags-v1.6.1"
                Enabled = $true
            }
            @{
                Name = "PublicExtension"                            # Extension available via a Git repo, using a custom branch
                Version = "feature/new-stuff"
                Path = "/myproject/.zf/extensions/PublicExtension/feature-new-stuff"
                Enabled = $true
            }
            @{
                Name = "PublicExtension"                            # Extension available via a Git repo, using the 'main' branch, located in a non-standard folder
                Version = "main"
                Path = "/myproject/.zf/extensions/PublicExtension/main"
                Enabled = $true
            }
            @{
                Name = "myLocalExtension"                           # Extension being developed locally
                Path = "/myLocalExtension/module"
                Enabled = $true
            }
            @{
                Name = "myNonExistantExtension"
                Path = "/myNonExistantExtension/module"   # Incorrect path to a local extension
                Enabled = $false
            }
        )
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable[]] $ExtensionsConfig,

        [Parameter(Mandatory=$true)]
        [string] $DefaultPSRepository,

        [Parameter(Mandatory=$true)]
        [string] $ZfPath,

        [Parameter()]
        [ValidateSet('Write', 'Frozen', 'Off')]
        [string] $LockMode = 'Write'
    )

    [hashtable[]]$processedExtensionConfig = @()

    # The lock file records the exact version of every extension that was installed, including dependencies:
    #  - Write:  extensions are resolved as normal, then the lock file is updated
    #  - Frozen: the versions in the lock file are installed, and any difference from it is an error
    #  - Off:    the lock file is not used
    $lockFilePath = Join-Path $ZfPath 'extensions.lock.json'
    $lockedExtensions = $null
    if ($LockMode -eq 'Frozen') {
        $lockedExtensions = _readExtensionLockFile -Path $lockFilePath
        if ($null -eq $lockedExtensions) {
            throw "The extensions lock mode is 'Frozen', but there is no lock file at '$lockFilePath'. Run with the lock mode set to 'Write' to create it."
        }
        Write-Host "Using extensions lock file: $lockFilePath"
    }

    # Extensions will be installed under the ZfPath, which by convention
    # is the '.zf' folder in the root of a project.
    $zfExtensionsPath = Join-Path $ZfPath 'extensions'
    if (!(Test-Path $zfExtensionsPath)) {
        New-Item -ItemType Directory $zfExtensionsPath | Out-Null
    }
    Write-Host "ZF Extensions Path: $zfExtensionsPath"

    # Ensure that $zfExtensionsPath is the first place we will look
    # for modules by putting it at the front of $env:PSModulePath
    [string[]]$moduleSearchPaths = $env:PSModulePath -split [IO.Path]::PathSeparator
    if ($zfExtensionsPath -notin $moduleSearchPaths) {
        $moduleSearchPaths = ,$zfExtensionsPath + $moduleSearchPaths
    }
    elseif ($moduleSearchPaths[0] -ne $zfExtensionsPath) {
        $moduleSearchPaths = ,$zfExtensionsPath + $($moduleSearchPaths | Where-Object {$_ -ne $zfExtensionsPath})
    }
    $env:PSModulePath = $moduleSearchPaths -join [IO.Path]::PathSeparator

    # Process each configured extension
    for ($i=0; $i -lt $ExtensionsConfig.Length; $i++) {

        $registeredExtensions = Register-ExtensionAndDependencies -ExtensionConfig $ExtensionsConfig[$i] `
                                                                 -TargetPath $zfExtensionsPath `
                                                                 -LockedExtensions $lockedExtensions

        # Persist the fully-populated extension metadata
        $processedExtensionConfig += $registeredExtensions
    }

    # When several extensions require the same extension with a minimum version, use a version that satisfies all of them
    $processedExtensionConfig = _resolveExtensionVersionRanges -Extensions $processedExtensionConfig

    switch ($LockMode) {
        'Write' {
            _writeExtensionLockFile -Path $lockFilePath -Extensions $processedExtensionConfig
        }
        'Frozen' {
            _assertExtensionLockSatisfied -Extensions $processedExtensionConfig -LockedExtensions $lockedExtensions -LockFilePath $lockFilePath
        }
    }

    return $processedExtensionConfig
}
