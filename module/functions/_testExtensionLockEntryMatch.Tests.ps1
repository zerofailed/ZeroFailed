# <copyright file="_testExtensionLockEntryMatch.Tests.ps1" company="Endjin Limited">
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

    It 'Ignores a trailing .git in a git repository URL (<Repository>)' -ForEach @(
        @{ Repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common.git' }
        @{ Repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common.GIT/' }
    ) {
        $lockEntry = @{
            source = @{ type = 'git'; repository = $Repository; folderPath = 'module' }
            requested = 'main'
        }

        _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $entry | Should -Be $true
    }

    It 'Does not ignore a trailing .git in a PowerShell repository name' {
        $psEntry = @{ source = @{ type = 'psrepository'; repository = 'MyRepo'; preRelease = $false }; requested = '1.0.0' }
        $lockEntry = @{ source = @{ type = 'psrepository'; repository = 'MyRepo.git'; preRelease = $false }; requested = '1.0.0' }

        _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $psEntry | Should -Be $false
    }

    It 'Does not match when the <Description>' -ForEach @(
        @{ Description = 'source type differs'; Source = @{ type = 'psrepository'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }; Requested = 'main' }
        @{ Description = 'repository differs'; Source = @{ type = 'git'; repository = 'https://github.com/myorg/ZeroFailed.Build.Common'; folderPath = 'module' }; Requested = 'main' }
        @{ Description = 'folder path differs'; Source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'src' }; Requested = 'main' }
        @{ Description = 'folder path differs by case'; Source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'Module' }; Requested = 'main' }
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

    It 'Matches a module version that has fewer than 3 numeric parts with its full version (<Requested> and <Locked>)' -ForEach @(
        @{ Requested = '1.4'; Locked = '1.4.0' }
        @{ Requested = '1.4.0'; Locked = '1.4' }
        @{ Requested = '1'; Locked = '1.0.0' }
    ) {
        $psEntry = @{ source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $false }; requested = $Requested }
        $lockEntry = @{ source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $false }; requested = $Locked }

        _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $psEntry | Should -Be $true
    }

    It 'Does not match a different module version' {
        $psEntry = @{ source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $false }; requested = '1.4' }
        $lockEntry = @{ source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $false }; requested = '1.4.1' }

        _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $psEntry | Should -Be $false
    }

    It 'Does not match a missing lock entry' {
        _testExtensionLockEntryMatch -LockEntry $null -Entry $entry | Should -Be $false
    }

    Context 'Minimum versions' {
        BeforeAll {
            $gitSource = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module'; preRelease = $false }
            $gitEntry = @{ source = $gitSource; requested = '[1.2.0,2.0.0)' }
            $psEntry = @{ source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $false }; requested = '[1.2.0,2.0.0)' }
        }

        It 'Matches a locked <Description> in the range, whatever was requested' -ForEach @(
            @{ Description = 'release tag'; Requested = '[1.5.0,2.0.0)'; ResolvedRef = 'refs/tags/v1.6.0' }
            @{ Description = 'git reference that is a release tag'; Requested = 'refs/tags/1.6.0'; ResolvedRef = $null }
        ) {
            $lockEntry = @{ source = $gitSource; requested = $Requested; resolved = 'abc123' }
            if ($ResolvedRef) { $lockEntry.resolvedRef = $ResolvedRef }

            _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $gitEntry -MinimumVersion '1.2.0' | Should -Be $true
        }

        It 'Matches a locked module version in the range, whatever was requested' {
            $lockEntry = @{ source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $true }; requested = '1.6.0'; resolved = '1.6.0' }

            _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $psEntry -MinimumVersion '1.2.0' | Should -Be $true
        }

        It 'Does not match when the <Description>' -ForEach @(
            @{ Description = 'locked version is below the range'; ResolvedRef = 'refs/tags/1.1.0'; Repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common' }
            @{ Description = 'locked version is the next major version'; ResolvedRef = 'refs/tags/2.0.0'; Repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common' }
            @{ Description = 'locked version is a pre-release'; ResolvedRef = 'refs/tags/1.6.0-beta.1'; Repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common' }
            @{ Description = 'locked git reference is a branch'; ResolvedRef = $null; Repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common' }
            @{ Description = 'repository differs'; ResolvedRef = 'refs/tags/1.6.0'; Repository = 'https://github.com/myorg/ZeroFailed.Build.Common' }
        ) {
            $lockEntry = @{
                source = @{ type = 'git'; repository = $Repository; folderPath = 'module'; preRelease = $true }
                requested = 'main'
                resolved = 'abc123'
            }
            if ($ResolvedRef) { $lockEntry.resolvedRef = $ResolvedRef }

            _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $gitEntry -MinimumVersion '1.2.0' | Should -Be $false
        }

        It 'Matches a locked pre-release when pre-release versions are included' {
            $lockEntry = @{ source = $gitSource; requested = '[1.5.0,2.0.0)'; resolved = 'abc123'; resolvedRef = 'refs/tags/1.6.0-beta.1' }

            _testExtensionLockEntryMatch -LockEntry $lockEntry -Entry $gitEntry -MinimumVersion '1.2.0' -PreRelease | Should -Be $true
        }
    }

    It 'Does not match a malformed lock entry' {
        _testExtensionLockEntryMatch -LockEntry @{ source = 'git'; requested = 'main' } -Entry $entry | Should -Be $false
    }
}
