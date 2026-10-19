# <copyright file="_getExtensionLockEntries.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionContentHash.ps1')

    Set-StrictMode -Version Latest

    # Creates the metadata of a registered extension, as produced by Register-ExtensionAndDependencies
    function newRegisteredExtension {
        param (
            [string] $Name,
            [string] $Type = 'git',
            [string] $Requested = 'main',
            [string] $Resolved = 'abc123',
            [string] $RequiredBy,
            [bool] $Enabled = $true
        )
        $path = Join-Path $TestDrive $Name $Requested
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content -Path (Join-Path $path "$Name.psd1") -Value "@{ ModuleVersion = '1.0.0' }"

        $source = switch ($Type) {
            'git' { [ordered]@{ type = 'git'; folderPath = 'module'; repository = "https://github.com/org/$Name" } }
            'psrepository' { [ordered]@{ type = 'psrepository'; preRelease = $false; repository = 'PSGallery' } }
            'path' { [ordered]@{ type = 'path'; path = $path } }
        }
        @{
            Name = $Name
            Path = $path
            Enabled = $Enabled
            LockEntry = [ordered]@{
                source = $source
                requested = $Requested
                resolved = $Resolved ? $Resolved : $null
                direct = !$RequiredBy
                requiredBy = $RequiredBy ? @($RequiredBy) : @()
            }
        }
    }
}

Describe '_getExtensionLockEntries' {

    BeforeAll {
        Mock Write-Warning {}
    }

    It 'Returns an entry for each extension, sorted by name' {
        $extensions = @(
            newRegisteredExtension -Name 'Zeta'
            newRegisteredExtension -Name 'Alpha'
            newRegisteredExtension -Name 'beta'
        )

        $result = _getExtensionLockEntries -Extensions $extensions

        @($result.Keys) | Should -Be @('Alpha', 'Zeta', 'beta')
    }

    It 'Records the source, requested and resolved versions, and a content hash, in a consistent order' {
        $extension = newRegisteredExtension -Name 'Alpha' -Requested 'v1' -Resolved 'abc123'

        $result = _getExtensionLockEntries -Extensions @($extension)

        $entry = $result['Alpha']
        @($entry.Keys) | Should -Be @('source', 'requested', 'resolved', 'contentHash', 'direct', 'requiredBy')
        $entry.source.repository | Should -Be 'https://github.com/org/Alpha'
        $entry.requested | Should -Be 'v1'
        $entry.resolved | Should -Be 'abc123'
        $entry.contentHash | Should -Be (_getExtensionContentHash -Path $extension.Path)
    }

    It 'Records the release tag that a git minimum version resolved to' {
        $extension = newRegisteredExtension -Name 'Alpha' -Resolved 'abc123'
        $extension.LockEntry.resolvedRef = 'refs/tags/1.4.2'

        $result = _getExtensionLockEntries -Extensions @($extension)

        @($result['Alpha'].Keys) | Should -Be @('source', 'requested', 'resolved', 'resolvedRef', 'contentHash', 'direct', 'requiredBy')
        $result['Alpha'].resolvedRef | Should -Be 'refs/tags/1.4.2'
    }

    It 'Does not record a content hash for local extensions' {
        $extension = newRegisteredExtension -Name 'Local' -Type 'path' -Resolved ''

        $result = _getExtensionLockEntries -Extensions @($extension)

        $result['Local'].Contains('contentHash') | Should -Be $false
    }

    Context 'When an extension has been resolved more than once' {
        BeforeAll {
            $extensions = @(
                newRegisteredExtension -Name 'Build' -Requested 'main'
                newRegisteredExtension -Name 'Common' -Requested 'v2' -Resolved 'first' -RequiredBy 'Build'
                newRegisteredExtension -Name 'Other' -Requested 'main'
                newRegisteredExtension -Name 'Common' -Requested 'v1' -Resolved 'second' -RequiredBy 'Other'
                newRegisteredExtension -Name 'Common' -Requested 'v3' -Resolved 'third'
            )

            $result = _getExtensionLockEntries -Extensions $extensions
        }

        It 'Uses the first one found' {
            $result['Common'].requested | Should -Be 'v2'
            $result['Common'].resolved | Should -Be 'first'
        }

        It 'Records every extension that requires it, sorted by name' {
            $result['Common'].requiredBy | Should -Be @('Build', 'Other')
        }

        It 'Records it as a direct dependency when any of them were configured directly' {
            $result['Common'].direct | Should -Be $true
        }
    }

    It 'Excludes extensions that are disabled' {
        $extensions = @(
            newRegisteredExtension -Name 'Enabled'
            newRegisteredExtension -Name 'Disabled' -Enabled $false
        )

        $result = _getExtensionLockEntries -Extensions $extensions

        @($result.Keys) | Should -Be @('Enabled')
    }

    It 'Excludes extensions without lock metadata (e.g. explicitly disabled ones)' {
        $extensions = @(
            newRegisteredExtension -Name 'Enabled'
            @{ Name = 'Skipped'; Enabled = $false }
        )

        $result = _getExtensionLockEntries -Extensions $extensions

        @($result.Keys) | Should -Be @('Enabled')
    }

    It 'Warns when the installed commit of a git extension is unknown' {
        $extension = newRegisteredExtension -Name 'Legacy' -Resolved ''

        $result = _getExtensionLockEntries -Extensions @($extension)

        $result['Legacy'].resolved | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like "*'Legacy' is unknown*" }
    }

    It 'Returns no entries when there are no extensions' {
        $result = _getExtensionLockEntries -Extensions @()

        $result.Count | Should -Be 0
    }
}
