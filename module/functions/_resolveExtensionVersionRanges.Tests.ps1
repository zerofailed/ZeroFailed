# <copyright file="_resolveExtensionVersionRanges.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionVersionRange.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getCompleteExtensionVersion.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_testExtensionVersionInRange.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getVersionFromGitTag.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getNormalizedGitRepositoryUrl.ps1')

    # Defined so that it can be mocked
    function Register-ExtensionAndDependencies { param($ExtensionConfig, $TargetPath, $RequiredBy, $LockedExtensions) }

    Set-StrictMode -Version Latest

    # Creates the metadata of a registered extension, as produced by Register-ExtensionAndDependencies
    function newRegisteredExtension {
        param (
            [string] $Name = 'Common',
            [string] $Type = 'psrepository',
            [string] $MinimumVersion,
            [string] $Requested,
            [string] $Resolved,
            [string] $ResolvedRef,
            [string] $RequiredBy
        )
        $lockEntry = [ordered]@{
            source = [ordered]@{ type = $Type }
            requested = $MinimumVersion ? (_getExtensionVersionRange -MinimumVersion $MinimumVersion).Text : ($Requested ? $Requested : $null)
            resolved = $Resolved ? $Resolved : $null
            direct = !$RequiredBy
            requiredBy = $RequiredBy ? @($RequiredBy) : @()
        }
        if ($ResolvedRef) {
            $lockEntry.resolvedRef = $ResolvedRef
        }
        $extension = @{
            Name = $Name
            Enabled = $true
            Path = "$Name-$Resolved$ResolvedRef"
            LockEntry = $lockEntry
        }
        if ($MinimumVersion) {
            $extension.MinimumVersion = $MinimumVersion
        }
        $extension
    }
}

Describe '_resolveExtensionVersionRanges' {

    BeforeAll {
        $targetPath = 'TestDrive:/extensions'

        Mock Write-Host {}
        Mock Write-Warning {}
        # By default, no other version is available
        Mock Register-ExtensionAndDependencies {}
    }

    It 'Leaves the order unchanged when the first occurrence satisfies every requirement' {
        $extensions = @(
            newRegisteredExtension -RequiredBy 'DotNet' -MinimumVersion '1.2' -Resolved '1.6.0'
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved '1.6.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

        [object]::ReferenceEquals($result[0], $extensions[0]) | Should -Be $true
        [object]::ReferenceEquals($result[1], $extensions[1]) | Should -Be $true
        Should -Invoke Write-Warning -Times 0
    }

    It 'Uses the newest occurrence that satisfies every requirement, in place of the first one' {
        $extensions = @(
            newRegisteredExtension -Name 'DotNet' -Requested '1.0.0' -Resolved '1.0.0'
            newRegisteredExtension -RequiredBy 'DotNet' -MinimumVersion '1.2' -Resolved '1.3.0'
            newRegisteredExtension -Name 'PowerShell' -Requested '1.0.0' -Resolved '1.0.0'
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved '1.6.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

        @($result | ForEach-Object { $_.Path }) | Should -Be @('DotNet-1.0.0', 'Common-1.6.0', 'PowerShell-1.0.0', 'Common-1.3.0')
    }

    It 'Uses the release tags of git extensions' {
        $extensions = @(
            newRegisteredExtension -Type 'git' -RequiredBy 'DotNet' -MinimumVersion '1.2' -Resolved 'commit1' -ResolvedRef 'refs/tags/1.3.0'
            newRegisteredExtension -Type 'git' -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved 'commit2' -ResolvedRef 'refs/tags/v1.6.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

        $result[0].LockEntry.resolvedRef | Should -Be 'refs/tags/v1.6.0'
    }

    It 'Uses a release in the range in place of a git branch, whose version is unknown' {
        $extensions = @(
            newRegisteredExtension -Type 'git' -RequiredBy 'DotNet' -Requested 'main' -Resolved 'commit1'
            newRegisteredExtension -Type 'git' -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved 'commit2' -ResolvedRef 'refs/tags/1.6.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

        $result[0].LockEntry.resolvedRef | Should -Be 'refs/tags/1.6.0'
    }

    It 'Keeps an occurrence from the configuration, with a warning' {
        $extensions = @(
            newRegisteredExtension -Requested '1.3.0' -Resolved '1.3.0'
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved '1.6.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

        $result[0].Path | Should -Be 'Common-1.3.0'
        Should -Invoke Write-Warning -Times 1 -ParameterFilter {
            $Message -eq "Extension 'Common' 1.3.0 is used because it is in the configuration, but 'PowerShell' requires [1.5.0,2.0.0)"
        }
    }

    It 'Uses an occurrence from the configuration that is not first, with a warning' {
        $extensions = @(
            newRegisteredExtension -Name 'PowerShell' -Requested '1.0.0' -Resolved '1.0.0'
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved '1.6.0'
            newRegisteredExtension -Requested '1.3.0' -Resolved '1.3.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

        @($result | ForEach-Object { $_.Path }) | Should -Be @('PowerShell-1.0.0', 'Common-1.3.0', 'Common-1.6.0')
        Should -Invoke Write-Warning -Times 1 -ParameterFilter {
            $Message -eq "Extension 'Common' 1.3.0 is used because it is in the configuration, but 'PowerShell' requires [1.5.0,2.0.0)"
        }
    }

    It 'Uses an occurrence from the configuration that is not first, even when the first one satisfies every requirement' {
        $extensions = @(
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved '1.7.0'
            newRegisteredExtension -MinimumVersion '1.5' -Resolved '1.6.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

        $result[0].Path | Should -Be 'Common-1.6.0'
        Should -Invoke Write-Warning -Times 0
    }

    It 'Uses a version without a pre-release label in place of a pre-release that another extension does not include' {
        $preReleaseExtension = newRegisteredExtension -RequiredBy 'DotNet' -MinimumVersion '1.4' -Resolved '1.6.0-beta.1'
        $preReleaseExtension.PreRelease = $true
        $extensions = @(
            $preReleaseExtension
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.4' -Resolved '1.5.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

        $result[0].Path | Should -Be 'Common-1.5.0'
    }

    It 'Keeps a pre-release when every extension includes pre-release versions' {
        $extensions = @(
            newRegisteredExtension -RequiredBy 'DotNet' -MinimumVersion '1.4' -Resolved '1.6.0-beta.1'
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.4' -Resolved '1.5.0'
        )
        $extensions | ForEach-Object { $_.PreRelease = $true }

        $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

        $result[0].Path | Should -Be 'Common-1.6.0-beta.1'
    }

    It 'Throws when only a pre-release satisfies every range, one extension does not include pre-release versions, and no other version is available' {
        $preReleaseExtension = newRegisteredExtension -RequiredBy 'DotNet' -MinimumVersion '1.6' -Resolved '1.7.0-beta.1'
        $preReleaseExtension.PreRelease = $true
        $extensions = @(
            $preReleaseExtension
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.4' -Resolved '1.5.0'
        )
        $expectedMessage = "No version of extension 'Common' satisfies every extension that requires it:`n" +
                           "  - 'DotNet' requires [1.6.0,2.0.0), including pre-release versions (resolved to 1.7.0-beta.1)`n" +
                           "  - 'PowerShell' requires [1.4.0,2.0.0) (resolved to 1.5.0)`n"

        { _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath } | Should -Throw -ExpectedMessage "$([WildcardPattern]::Escape($expectedMessage))*"
    }

    Context 'When no registered version satisfies every range, but the ranges overlap' {
        BeforeEach {
            # A pre-release satisfies the first range, and an installed copy satisfies the second, but neither
            # satisfies both
            $preReleaseExtension = newRegisteredExtension -RequiredBy 'DotNet' -MinimumVersion '1.6' -Resolved '1.7.0-beta.1'
            $preReleaseExtension.PreRelease = $true
            $extensions = @(
                $preReleaseExtension
                newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.4' -Resolved '1.5.0'
            )
            $extensions | ForEach-Object { $_.LockEntry.source.repository = 'PSGallery' }
            $lockedExtensions = @{ Common = @{ resolved = '1.6.0' } }

            # The repository has a version in both ranges, which depends on another extension
            Mock Register-ExtensionAndDependencies {
                $installed = newRegisteredExtension -RequiredBy $RequiredBy -MinimumVersion $ExtensionConfig.MinimumVersion -Resolved '1.6.0'
                $installed.LockEntry.source.repository = $ExtensionConfig.PSRepository
                $installed
                newRegisteredExtension -Name 'Dependency' -RequiredBy 'Common' -MinimumVersion '1.0' -Resolved '1.0.0'
            }
        }

        It 'Installs the newest version in every range, from the same source, without pre-release versions' {
            $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath -LockedExtensions $lockedExtensions

            $result[0].Path | Should -Be 'Common-1.6.0'
            Should -Invoke Register-ExtensionAndDependencies -Times 1 -ParameterFilter {
                $ExtensionConfig.Name -eq 'Common' -and
                $ExtensionConfig.MinimumVersion -eq '1.6.0' -and
                $ExtensionConfig.PSRepository -eq 'PSGallery' -and
                !$ExtensionConfig.ContainsKey('PreRelease') -and
                $TargetPath -eq 'TestDrive:/extensions' -and
                $RequiredBy -eq 'DotNet' -and
                $LockedExtensions.Common.resolved -eq '1.6.0'
            }
        }

        It 'Keeps every registered occurrence, and adds the dependencies of the installed version' {
            $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

            $result.Count | Should -Be 4
            @($result | Where-Object { $_.Name -eq 'Common' }).Count | Should -Be 3
            @($result | Where-Object { $_.Name -eq 'Dependency' }).Count | Should -Be 1
        }

        It 'Installs from a git repository' {
            $extensions | ForEach-Object {
                $_.LockEntry.source = [ordered]@{ type = 'git'; folderPath = 'module'; repository = 'https://github.com/zerofailed/Common' }
                $_.LockEntry.resolvedRef = "refs/tags/$($_.LockEntry.resolved)"
            }
            Mock Register-ExtensionAndDependencies {
                newRegisteredExtension -Type 'git' -RequiredBy $RequiredBy -MinimumVersion $ExtensionConfig.MinimumVersion -Resolved 'commit' -ResolvedRef 'refs/tags/1.6.0'
            }

            $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

            $result[0].LockEntry.resolvedRef | Should -Be 'refs/tags/1.6.0'
            Should -Invoke Register-ExtensionAndDependencies -Times 1 -ParameterFilter {
                $ExtensionConfig.GitRepository -eq 'https://github.com/zerofailed/Common' -and
                $ExtensionConfig.GitRepositoryFolderPath -eq 'module' -and
                !$ExtensionConfig.ContainsKey('PSRepository')
            }
        }

        It 'Installs from a git repository that is referenced with and without a trailing .git' {
            $extensions | ForEach-Object {
                $_.LockEntry.source = [ordered]@{ type = 'git'; folderPath = 'module'; repository = 'https://github.com/zerofailed/Common' }
                $_.LockEntry.resolvedRef = "refs/tags/$($_.LockEntry.resolved)"
            }
            $extensions[1].LockEntry.source.repository = 'https://github.com/zerofailed/Common.git'
            Mock Register-ExtensionAndDependencies {
                newRegisteredExtension -Type 'git' -RequiredBy $RequiredBy -MinimumVersion $ExtensionConfig.MinimumVersion -Resolved 'commit' -ResolvedRef 'refs/tags/1.6.0'
            }

            $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

            $result[0].LockEntry.resolvedRef | Should -Be 'refs/tags/1.6.0'
            Should -Invoke Register-ExtensionAndDependencies -Times 1
        }

        It 'Throws, with the reason, when the version cannot be installed' {
            Mock Register-ExtensionAndDependencies { throw 'No release matches' }

            { _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath } |
                Should -Throw "No version of extension 'Common'*A version in every range could not be installed: No release matches*"
        }

        It 'Throws when no version in every range is available' {
            Mock Register-ExtensionAndDependencies { @{ Name = 'Common'; Enabled = $false } }

            { _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath } | Should -Throw "No version of extension 'Common'*"
        }

        It 'Does not install a version when the extensions require it from different sources' {
            $extensions[1].LockEntry.source.repository = 'MyRepository'

            { _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath } | Should -Throw "No version of extension 'Common'*"
            Should -Invoke Register-ExtensionAndDependencies -Times 0
        }
    }

    It 'Throws when no version satisfies every requirement' {
        $extensions = @(
            newRegisteredExtension -RequiredBy 'DotNet' -MinimumVersion '1.2' -Resolved '1.6.0'
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '2.0' -Resolved '2.1.0'
        )
        $expectedMessage = "No version of extension 'Common' satisfies every extension that requires it:`n" +
                           "  - 'DotNet' requires [1.2.0,2.0.0) (resolved to 1.6.0)`n" +
                           "  - 'PowerShell' requires [2.0.0,3.0.0) (resolved to 2.1.0)`n" +
                           "They may need different major versions. To use one version for all of them, add 'Common' to the configuration."

        { _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath } | Should -Throw -ExpectedMessage ([WildcardPattern]::Escape($expectedMessage))
    }

    It 'Includes exact versions in the requirements' {
        $extensions = @(
            newRegisteredExtension -Type 'git' -RequiredBy 'DotNet' -Requested 'refs/tags/1.3.0' -Resolved 'commit1'
            newRegisteredExtension -Type 'git' -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved 'commit2' -ResolvedRef 'refs/tags/1.6.0'
        )

        { _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath } | Should -Throw "No version of extension 'Common'*"
    }

    It 'Includes exact module versions that have fewer than 3 numeric parts in the requirements' {
        $extensions = @(
            newRegisteredExtension -RequiredBy 'DotNet' -Requested '1.4' -Resolved '1.4.0'
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved '1.6.0'
        )

        { _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath } |
            Should -Throw "No version of extension 'Common'*'DotNet' requires 1.4 (resolved to 1.4.0)*"
        Should -Invoke Register-ExtensionAndDependencies -Times 0
    }

    It 'Ignores extensions that are not required with a minimum version' {
        $extensions = @(
            newRegisteredExtension -RequiredBy 'DotNet' -Requested '1.0.0' -Resolved '1.0.0'
            newRegisteredExtension -RequiredBy 'PowerShell' -Requested '2.0.0' -Resolved '2.0.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

        $result[0].Path | Should -Be 'Common-1.0.0'
        Should -Invoke Write-Warning -Times 0
    }

    It 'Ignores extensions that were not registered' {
        $extensions = @(
            @{ Name = 'Common'; Enabled = $false }
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved '1.6.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions -TargetPath $targetPath

        $result[0].ContainsKey('LockEntry') | Should -Be $false
    }
}
