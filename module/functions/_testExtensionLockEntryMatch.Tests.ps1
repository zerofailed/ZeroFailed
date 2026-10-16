# <copyright file="_testExtensionLockEntryMatch.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest
}

Describe '_testExtensionLockEntryMatch' {

    BeforeAll {
        $entry = @{
            source = [ordered]@{ type = 'git'; folderPath = 'module'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common' }
            requested = 'main'
            resolved = 'abc123'
        }
    }

    It 'Matches a lock entry with the same source and requested version' {
        $lockEntry = @{
            source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }
            requested = 'main'
            resolved = 'def456'
        }

        _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $entry | Should -Be $true
    }

    It 'Ignores the case of source details and trailing slashes' {
        $lockEntry = @{
            source = @{ type = 'git'; repository = 'https://GitHub.com/zerofailed/ZeroFailed.Build.Common/'; folderPath = 'module' }
            requested = 'main'
        }

        _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $entry | Should -Be $true
    }

    It 'Does not match when the <Description>' -ForEach @(
        @{ Description = 'source type differs'; Source = @{ type = 'psrepository'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }; Requested = 'main' }
        @{ Description = 'repository differs'; Source = @{ type = 'git'; repository = 'https://github.com/myorg/ZeroFailed.Build.Common'; folderPath = 'module' }; Requested = 'main' }
        @{ Description = 'folder path differs'; Source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'src' }; Requested = 'main' }
        @{ Description = 'source has an extra detail'; Source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module'; extra = 'x' }; Requested = 'main' }
        @{ Description = 'requested version differs'; Source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }; Requested = 'develop' }
        @{ Description = 'requested git reference differs by case'; Source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }; Requested = 'Main' }
    ) {
        $lockEntry = @{ source = $Source; requested = $Requested }

        _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $entry | Should -Be $false
    }

    It 'Matches when neither entry has a requested version' {
        $psEntry = @{ source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $false }; requested = $null }
        $lockEntry = @{ source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $false }; requested = $null }

        _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $psEntry | Should -Be $true
    }

    It 'Does not match when only one entry has a requested version' {
        $psEntry = @{ source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $false }; requested = $null }
        $lockEntry = @{ source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $false }; requested = '1.0.0' }

        _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $psEntry | Should -Be $false
    }

    It 'Does not match a missing lock entry' {
        _testExtensionLockEntryMatch -LockEntry $null -Entry $entry | Should -Be $false
    }

    It 'Does not match a malformed lock entry' {
        _testExtensionLockEntryMatch -LockEntry @{ source = 'git'; requested = 'main' } -Entry $entry | Should -Be $false
    }
}
