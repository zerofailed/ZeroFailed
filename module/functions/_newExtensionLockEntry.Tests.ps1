# <copyright file="_newExtensionLockEntry.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest
}

Describe '_newExtensionLockEntry' {

    Context 'A directly requested extension' {
        BeforeAll {
            $result = _newExtensionLockEntry -SourceType 'git' `
                                             -Source @{ repository = 'https://example.com/repo.git'; folderPath = 'module' } `
                                             -Requested 'main'
        }

        It 'Records the source, with the type first and the other details in a consistent order' {
            @($result.source.Keys) | Should -Be @('type', 'folderPath', 'repository')
            $result.source.type | Should -Be 'git'
            $result.source.repository | Should -Be 'https://example.com/repo.git'
            $result.source.folderPath | Should -Be 'module'
        }

        It 'Records the requested version' {
            $result.requested | Should -Be 'main'
        }

        It 'Has no resolved version yet' {
            $result.Contains('resolved') | Should -Be $true
            $result.resolved | Should -BeNullOrEmpty
        }

        It 'Records that the extension is a direct dependency' {
            $result.direct | Should -Be $true
            $result.requiredBy.Count | Should -Be 0
        }

        It 'Uses a consistent key order' {
            @($result.Keys) | Should -Be @('source', 'requested', 'resolved', 'direct', 'requiredBy')
        }
    }

    Context 'A dependency of another extension' {
        It 'Records which extension requires it' {
            $result = _newExtensionLockEntry -SourceType 'psrepository' -Source @{ repository = 'PSGallery' } -RequiredBy 'ZeroFailed.Build.DotNet'

            $result.direct | Should -Be $false
            $result.requiredBy | Should -Be @('ZeroFailed.Build.DotNet')
        }
    }

    Context 'No requested version' {
        It 'Records the requested version as null' {
            $result = _newExtensionLockEntry -SourceType 'psrepository' -Source @{ repository = 'PSGallery' } -Requested $null

            $result.requested | Should -BeNullOrEmpty
            $null -eq $result.requested | Should -Be $true
        }
    }

    Context 'Invalid source type' {
        It 'Throws an error' {
            { _newExtensionLockEntry -SourceType 'oci' -Source @{} } | Should -Throw
        }
    }
}
