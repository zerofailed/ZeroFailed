# <copyright file="_getExtensionFromGit.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-InstalledExtensionDetails.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_copyFolderFromGitRepo.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionVersionRange.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_testExtensionVersionInRange.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getVersionFromGitTag.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getGitTagVersions.ps1')

    Set-StrictMode -Version Latest

    # Creates the minimum folder structure of an installed extension, optionally recording the release tag it came from
    function newInstalledExtension([string] $Path, [string] $Name, [string] $Commit, [string] $Ref, [string] $Repository) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Set-Content -Path (Join-Path $Path "$Name.psd1") -Value "@{ ModuleVersion = '1.0.0' }"
        if ($Ref) {
            @{ repository = $Repository; folderPath = 'module'; ref = $Ref; commit = $Commit } | ConvertTo-Json | Set-Content -Path (Join-Path $Path '.zf-source.json')
        }
        elseif ($Commit) {
            @{ commit = $Commit } | ConvertTo-Json | Set-Content -Path (Join-Path $Path '.zf-source.json')
        }
    }
}

Describe '_getExtensionFromGit' {

    BeforeAll {
        $name = 'ZeroFailed.Build.Test'
        $repo = 'https://github.com/zerofailed/ZeroFailed.Build.Test'

        Mock Write-Host {}

        # Simulate a checkout by creating the extension folder; the commit is the pinned one, or the latest one
        Mock _copyFolderFromGitRepo {
            if (Test-Path $DestinationPath) { Remove-Item $DestinationPath -Recurse -Force }
            newInstalledExtension -Path $DestinationPath -Name 'ZeroFailed.Build.Test'
            $Commit ? $Commit : 'latest-commit'
        }
    }

    BeforeEach {
        $targetPath = Join-Path $TestDrive "extensions-$(New-Guid)"
    }

    Context 'When the extension is not installed' {
        BeforeEach {
            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -GitRef 'main'
        }

        It 'Installs the extension into a folder named after the git reference' {
            $result.Path | Should -Be (Join-Path $targetPath $name 'main')
            $result.Enabled | Should -Be $true
            Should -Invoke _copyFolderFromGitRepo -Times 1 -ParameterFilter {
                $RepoUrl -eq $repo -and $GitRef -eq 'main' -and $RepoFolderPath -eq 'module' -and !$Commit
            }
        }

        It 'Returns the commit that was installed' {
            $result.ResolvedVersion | Should -Be 'latest-commit'
        }

        It 'Records where the extension was installed from' {
            $sourceInfo = Get-Content -Raw (Join-Path $result.Path '.zf-source.json') | ConvertFrom-Json -AsHashtable

            $sourceInfo.repository | Should -Be $repo
            $sourceInfo.folderPath | Should -Be 'module'
            $sourceInfo.ref | Should -Be 'main'
            $sourceInfo.commit | Should -Be 'latest-commit'
        }

        It 'Does not return a release tag' {
            $result.ContainsKey('ResolvedRef') | Should -Be $false
        }
    }

    Context 'When neither a git reference nor a minimum version is requested' {
        It 'Throws an error' {
            { _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath } |
                Should -Throw "A 'GitRef' or 'MinimumVersion' is required to install extension $name from $repo repository"
        }
    }

    Context 'When the git reference contains a /' {
        It 'Uses a folder name with the / replaced' {
            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -GitRef 'feature/foo'

            $result.Path | Should -Be (Join-Path $targetPath $name 'feature-foo')
        }
    }

    Context 'When the extension is already installed' {
        It 'Uses the installed extension and returns its recorded commit' {
            newInstalledExtension -Path (Join-Path $targetPath $name 'main') -Name $name -Commit 'installed-commit'

            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -GitRef 'main'

            $result.Path | Should -Be (Join-Path $targetPath $name 'main')
            $result.ResolvedVersion | Should -Be 'installed-commit'
            Should -Invoke _copyFolderFromGitRepo -Times 0
        }

        It 'Returns no commit when the extension was installed by an earlier version of ZeroFailed' {
            newInstalledExtension -Path (Join-Path $targetPath $name 'main') -Name $name

            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -GitRef 'main'

            $result.ResolvedVersion | Should -BeNullOrEmpty
            Should -Invoke _copyFolderFromGitRepo -Times 0
        }
    }

    Context 'When a commit is locked' {
        It 'Uses the installed extension when it is at the locked commit' {
            newInstalledExtension -Path (Join-Path $targetPath $name 'main') -Name $name -Commit 'locked-commit'

            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -GitRef 'main' -LockedCommit 'locked-commit'

            $result.ResolvedVersion | Should -Be 'locked-commit'
            Should -Invoke _copyFolderFromGitRepo -Times 0
        }

        It 'Re-installs the extension when it is at a different commit' {
            newInstalledExtension -Path (Join-Path $targetPath $name 'main') -Name $name -Commit 'other-commit'

            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -GitRef 'main' -LockedCommit 'locked-commit'

            $result.ResolvedVersion | Should -Be 'locked-commit'
            Should -Invoke _copyFolderFromGitRepo -Times 1 -ParameterFilter { $Commit -eq 'locked-commit' -and $GitRef -eq 'main' }
            (Get-Content -Raw (Join-Path $result.Path '.zf-source.json') | ConvertFrom-Json).commit | Should -Be 'locked-commit'
        }

        It 'Re-installs the extension when it was installed by an earlier version of ZeroFailed' {
            newInstalledExtension -Path (Join-Path $targetPath $name 'main') -Name $name

            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -GitRef 'main' -LockedCommit 'locked-commit'

            $result.ResolvedVersion | Should -Be 'locked-commit'
            Should -Invoke _copyFolderFromGitRepo -Times 1 -ParameterFilter { $Commit -eq 'locked-commit' }
        }

        It 'Installs the locked commit when the extension is not installed' {
            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -GitRef 'main' -LockedCommit 'locked-commit'

            $result.ResolvedVersion | Should -Be 'locked-commit'
            Should -Invoke _copyFolderFromGitRepo -Times 1 -ParameterFilter { $Commit -eq 'locked-commit' }
        }
    }

    Context 'When a minimum version is requested' {
        BeforeAll {
            # Simulate a repository with release tags, including some outside the range
            Mock _getGitTagVersions {
                foreach ($tag in '1.3.0', '1.4.0', 'v1.6.1', '1.7.0-beta.1', '2.0.0') {
                    @{ Ref = "refs/tags/$tag"; Version = [semver]$tag.TrimStart('v') }
                }
            }
        }

        It 'Installs the newest release tag in the range' {
            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -MinimumVersion '1.4.0'

            $result.Path | Should -Be (Join-Path $targetPath $name 'refs-tags-v1.6.1')
            $result.ResolvedRef | Should -Be 'refs/tags/v1.6.1'
            $result.ResolvedVersion | Should -Be 'latest-commit'
            Should -Invoke _copyFolderFromGitRepo -Times 1 -ParameterFilter { $GitRef -eq 'refs/tags/v1.6.1' -and !$Commit }
            (Get-Content -Raw (Join-Path $result.Path '.zf-source.json') | ConvertFrom-Json).ref | Should -Be 'refs/tags/v1.6.1'
        }

        It 'Includes pre-release tags in the range when they are requested' {
            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -MinimumVersion '1.4.0' -PreRelease

            $result.ResolvedRef | Should -Be 'refs/tags/1.7.0-beta.1'
        }

        It 'Uses an installed release in the range without listing the tags' {
            newInstalledExtension -Path (Join-Path $targetPath $name 'refs-tags-1.5.0') -Name $name -Commit 'installed-commit' -Ref 'refs/tags/1.5.0' -Repository "$repo/"

            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -MinimumVersion '1.4.0'

            $result.Path | Should -Be (Join-Path $targetPath $name 'refs-tags-1.5.0')
            $result.ResolvedRef | Should -Be 'refs/tags/1.5.0'
            $result.ResolvedVersion | Should -Be 'installed-commit'
            Should -Invoke _getGitTagVersions -Times 0
            Should -Invoke _copyFolderFromGitRepo -Times 0
        }

        It 'Ignores installed releases from another repository, or outside the range' {
            newInstalledExtension -Path (Join-Path $targetPath $name 'refs-tags-1.5.0') -Name $name -Commit 'other-commit' -Ref 'refs/tags/1.5.0' -Repository 'https://github.com/other/ZeroFailed.Build.Test'
            newInstalledExtension -Path (Join-Path $targetPath $name 'refs-tags-2.0.0') -Name $name -Commit 'major-commit' -Ref 'refs/tags/2.0.0' -Repository $repo

            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -MinimumVersion '1.4.0'

            $result.ResolvedRef | Should -Be 'refs/tags/v1.6.1'
            Should -Invoke _getGitTagVersions -Times 1
        }

        It 'Throws when no release tag is in the range' {
            $expectedMessage = "No release of extension $name in $repo repository matches [3.0.0,4.0.0)."

            { _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -MinimumVersion '3.0' } |
                Should -Throw -ExpectedMessage "$([WildcardPattern]::Escape($expectedMessage))*"
        }

        It 'Throws when the release tags cannot be listed' {
            Mock _getGitTagVersions { throw 'git ls-remote failed' }

            { _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -MinimumVersion '1.4.0' } |
                Should -Throw "Failed to list the release tags of extension $name from $repo repository: git ls-remote failed"
        }

        It 'Installs the locked commit of the release tag in the lock file, without listing the tags' {
            $result = _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -MinimumVersion '1.4.0' -GitRef 'refs/tags/1.4.0' -LockedCommit 'locked-commit'

            $result.Path | Should -Be (Join-Path $targetPath $name 'refs-tags-1.4.0')
            $result.ResolvedRef | Should -Be 'refs/tags/1.4.0'
            $result.ResolvedVersion | Should -Be 'locked-commit'
            Should -Invoke _getGitTagVersions -Times 0
            Should -Invoke _copyFolderFromGitRepo -Times 1 -ParameterFilter { $GitRef -eq 'refs/tags/1.4.0' -and $Commit -eq 'locked-commit' }
        }
    }

    Context 'When the extension cannot be installed' {
        BeforeAll {
            Mock _copyFolderFromGitRepo { throw 'git fetch failed' }
        }

        It 'Throws an error that includes the reason' {
            { _getExtensionFromGit -Name $name -RepositoryUri $repo -TargetPath $targetPath -GitRef 'main' } |
                Should -Throw "Failed to install extension $name (main) from $repo repository: git fetch failed"
        }
    }
}
