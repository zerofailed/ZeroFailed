# <copyright file="_resolveExtensionVersionRanges.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionVersionRange.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_testExtensionVersionInRange.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getVersionFromGitTag.ps1')

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
        Mock Write-Warning {}
    }

    It 'Leaves the order unchanged when the first occurrence satisfies every requirement' {
        $extensions = @(
            newRegisteredExtension -RequiredBy 'DotNet' -MinimumVersion '1.2' -Resolved '1.6.0'
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved '1.6.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions

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

        $result = _resolveExtensionVersionRanges -Extensions $extensions

        @($result | ForEach-Object { $_.Path }) | Should -Be @('DotNet-1.0.0', 'Common-1.6.0', 'PowerShell-1.0.0', 'Common-1.3.0')
    }

    It 'Uses the release tags of git extensions' {
        $extensions = @(
            newRegisteredExtension -Type 'git' -RequiredBy 'DotNet' -MinimumVersion '1.2' -Resolved 'commit1' -ResolvedRef 'refs/tags/1.3.0'
            newRegisteredExtension -Type 'git' -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved 'commit2' -ResolvedRef 'refs/tags/v1.6.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions

        $result[0].LockEntry.resolvedRef | Should -Be 'refs/tags/v1.6.0'
    }

    It 'Uses a release in the range in place of a git branch, whose version is unknown' {
        $extensions = @(
            newRegisteredExtension -Type 'git' -RequiredBy 'DotNet' -Requested 'main' -Resolved 'commit1'
            newRegisteredExtension -Type 'git' -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved 'commit2' -ResolvedRef 'refs/tags/1.6.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions

        $result[0].LockEntry.resolvedRef | Should -Be 'refs/tags/1.6.0'
    }

    It 'Keeps an occurrence from the configuration, with a warning' {
        $extensions = @(
            newRegisteredExtension -Requested '1.3.0' -Resolved '1.3.0'
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved '1.6.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions

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

        $result = _resolveExtensionVersionRanges -Extensions $extensions

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

        $result = _resolveExtensionVersionRanges -Extensions $extensions

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

        $result = _resolveExtensionVersionRanges -Extensions $extensions

        $result[0].Path | Should -Be 'Common-1.5.0'
    }

    It 'Keeps a pre-release when every extension includes pre-release versions' {
        $extensions = @(
            newRegisteredExtension -RequiredBy 'DotNet' -MinimumVersion '1.4' -Resolved '1.6.0-beta.1'
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.4' -Resolved '1.5.0'
        )
        $extensions | ForEach-Object { $_.PreRelease = $true }

        $result = _resolveExtensionVersionRanges -Extensions $extensions

        $result[0].Path | Should -Be 'Common-1.6.0-beta.1'
    }

    It 'Throws when only a pre-release satisfies every range, and one extension does not include pre-release versions' {
        $preReleaseExtension = newRegisteredExtension -RequiredBy 'DotNet' -MinimumVersion '1.6' -Resolved '1.7.0-beta.1'
        $preReleaseExtension.PreRelease = $true
        $extensions = @(
            $preReleaseExtension
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.4' -Resolved '1.5.0'
        )
        $expectedMessage = "No version of extension 'Common' satisfies every extension that requires it:`n" +
                           "  - 'DotNet' requires [1.6.0,2.0.0), including pre-release versions (resolved to 1.7.0-beta.1)`n" +
                           "  - 'PowerShell' requires [1.4.0,2.0.0) (resolved to 1.5.0)`n"

        { _resolveExtensionVersionRanges -Extensions $extensions } | Should -Throw -ExpectedMessage "$([WildcardPattern]::Escape($expectedMessage))*"
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

        { _resolveExtensionVersionRanges -Extensions $extensions } | Should -Throw -ExpectedMessage ([WildcardPattern]::Escape($expectedMessage))
    }

    It 'Includes exact versions in the requirements' {
        $extensions = @(
            newRegisteredExtension -Type 'git' -RequiredBy 'DotNet' -Requested 'refs/tags/1.3.0' -Resolved 'commit1'
            newRegisteredExtension -Type 'git' -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved 'commit2' -ResolvedRef 'refs/tags/1.6.0'
        )

        { _resolveExtensionVersionRanges -Extensions $extensions } | Should -Throw "No version of extension 'Common'*"
    }

    It 'Ignores extensions that are not required with a minimum version' {
        $extensions = @(
            newRegisteredExtension -RequiredBy 'DotNet' -Requested '1.0.0' -Resolved '1.0.0'
            newRegisteredExtension -RequiredBy 'PowerShell' -Requested '2.0.0' -Resolved '2.0.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions

        $result[0].Path | Should -Be 'Common-1.0.0'
        Should -Invoke Write-Warning -Times 0
    }

    It 'Ignores extensions that were not registered' {
        $extensions = @(
            @{ Name = 'Common'; Enabled = $false }
            newRegisteredExtension -RequiredBy 'PowerShell' -MinimumVersion '1.5' -Resolved '1.6.0'
        )

        $result = _resolveExtensionVersionRanges -Extensions $extensions

        $result[0].ContainsKey('LockEntry') | Should -Be $false
    }
}
