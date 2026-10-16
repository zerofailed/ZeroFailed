# <copyright file="_copyFolderFromGitRepo.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest

    # Runs a git command to build the fixture repositories, failing the test setup if it does not succeed
    function invokeFixtureGit {
        $output = & git @args 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "git $($args -join ' ') failed: $($output -join "`n")"
        }
        $output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
    }

    # Writes a file with exact content (i.e. no platform-specific line endings are added)
    function setFixtureFile([string] $Path, [string] $Content) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
        [IO.File]::WriteAllText($Path, $Content)
    }

    # Sets git configuration via environment variables, which mimics settings in the user's git configuration
    function setGitEnvironmentConfig([hashtable] $Settings) {
        $i = 0
        foreach ($key in $Settings.Keys) {
            Set-Item -Path "env:GIT_CONFIG_KEY_$i" -Value $key
            Set-Item -Path "env:GIT_CONFIG_VALUE_$i" -Value $Settings[$key]
            $i++
        }
        $env:GIT_CONFIG_COUNT = $i
    }

    function clearGitEnvironmentConfig {
        Get-ChildItem env:GIT_CONFIG_* | ForEach-Object { Remove-Item -Path "env:$($_.Name)" }
    }
}

Describe '_copyFolderFromGitRepo' {

    BeforeAll {
        # Build a source repository with a module folder, a tag, a branch containing a '/' and several commits:
        #   c1 -> c2 (tag v2.0.0) -> c3 (main)
        #                         \-> c4 (feature/test)
        $sourceRepo = Join-Path $TestDrive 'source'
        invokeFixtureGit -c init.defaultBranch=main init --quiet $sourceRepo | Out-Null
        invokeFixtureGit -C $sourceRepo config user.email 'test@example.com' | Out-Null
        invokeFixtureGit -C $sourceRepo config user.name 'Test' | Out-Null
        invokeFixtureGit -C $sourceRepo config core.autocrlf false | Out-Null

        setFixtureFile (Join-Path $sourceRepo '.gitattributes') "* text=auto`n"
        setFixtureFile (Join-Path $sourceRepo 'README.md') "Not part of the extension`n"
        setFixtureFile (Join-Path $sourceRepo 'module' 'Fixture.psd1') "@{ ModuleVersion = '1.0.0' }`n"
        setFixtureFile (Join-Path $sourceRepo 'module' 'tasks' 'sample.tasks.ps1') "line1`nline2`n"
        setFixtureFile (Join-Path $sourceRepo 'module' 'version.txt') "c1`n"
        invokeFixtureGit -C $sourceRepo add -A | Out-Null
        invokeFixtureGit -C $sourceRepo commit --quiet -m 'c1' | Out-Null
        $commit1 = invokeFixtureGit -C $sourceRepo rev-parse HEAD

        setFixtureFile (Join-Path $sourceRepo 'module' 'version.txt') "c2`n"
        invokeFixtureGit -C $sourceRepo commit --quiet -am 'c2' | Out-Null
        invokeFixtureGit -C $sourceRepo tag -a 'v2.0.0' -m 'v2.0.0' | Out-Null
        $commit2 = invokeFixtureGit -C $sourceRepo rev-parse HEAD

        setFixtureFile (Join-Path $sourceRepo 'module' 'version.txt') "c3`n"
        invokeFixtureGit -C $sourceRepo commit --quiet -am 'c3' | Out-Null
        $commit3 = invokeFixtureGit -C $sourceRepo rev-parse HEAD

        invokeFixtureGit -C $sourceRepo checkout --quiet -b 'feature/test' $commit2 | Out-Null
        setFixtureFile (Join-Path $sourceRepo 'module' 'version.txt') "c4`n"
        invokeFixtureGit -C $sourceRepo commit --quiet -am 'c4' | Out-Null
        $commit4 = invokeFixtureGit -C $sourceRepo rev-parse HEAD
        invokeFixtureGit -C $sourceRepo checkout --quiet main | Out-Null

        # Serve it as a bare repository via a 'file://' URL, so that git uses its network protocol
        $bareRepo = Join-Path $TestDrive 'fixture.git'
        invokeFixtureGit clone --bare --quiet $sourceRepo $bareRepo | Out-Null
        $repoUrl = ([uri]$bareRepo).AbsoluteUri

        $targetPath = Join-Path $TestDrive 'extensions'

        Mock Write-Verbose {}
    }

    Context 'Fetching a git reference' {
        It 'Copies the folder from <GitRef> and returns the commit it resolved to' -ForEach @(
            @{ GitRef = 'main'; ExpectedCommit = 'commit3'; ExpectedContent = 'c3' }
            @{ GitRef = 'refs/heads/main'; ExpectedCommit = 'commit3'; ExpectedContent = 'c3' }
            @{ GitRef = 'feature/test'; ExpectedCommit = 'commit4'; ExpectedContent = 'c4' }
            @{ GitRef = 'v2.0.0'; ExpectedCommit = 'commit2'; ExpectedContent = 'c2' }
            @{ GitRef = 'refs/tags/v2.0.0'; ExpectedCommit = 'commit2'; ExpectedContent = 'c2' }
        ) {
            $destination = Join-Path $targetPath "ref-$($GitRef.Replace('/', '-'))"

            $result = _copyFolderFromGitRepo -RepoUrl $repoUrl -RepoFolderPath 'module' -DestinationPath $destination -GitRef $GitRef

            $result | Should -Be (Get-Variable -Name $ExpectedCommit -ValueOnly)
            Get-Content -Raw (Join-Path $destination 'version.txt') | Should -Be "$ExpectedContent`n"
        }

        It 'Copies a commit specified as the git reference' {
            $destination = Join-Path $targetPath 'ref-commit'

            $result = _copyFolderFromGitRepo -RepoUrl $repoUrl -RepoFolderPath 'module' -DestinationPath $destination -GitRef $commit1

            $result | Should -Be $commit1
            Get-Content -Raw (Join-Path $destination 'version.txt') | Should -Be "c1`n"
        }

        It 'Copies only the contents of the requested folder' {
            $destination = Join-Path $targetPath 'folder-only'

            _copyFolderFromGitRepo -RepoUrl $repoUrl -RepoFolderPath 'module' -DestinationPath $destination | Out-Null

            Join-Path $destination 'Fixture.psd1' | Should -Exist
            Join-Path $destination 'tasks' 'sample.tasks.ps1' | Should -Exist
            Join-Path $destination 'module' | Should -Not -Exist
            Join-Path $destination 'README.md' | Should -Not -Exist
        }

        It 'Does not copy the git metadata when the whole repository is copied' {
            $destination = Join-Path $targetPath 'whole-repo'

            _copyFolderFromGitRepo -RepoUrl $repoUrl -RepoFolderPath '.' -DestinationPath $destination | Out-Null

            Join-Path $destination 'module' 'Fixture.psd1' | Should -Exist
            Join-Path $destination '.git' | Should -Not -Exist
        }
    }

    Context 'Fetching a specific commit' {
        It 'Copies the folder from the specified commit, rather than the latest commit of the git reference' {
            $destination = Join-Path $targetPath 'pinned'

            $result = _copyFolderFromGitRepo -RepoUrl $repoUrl -RepoFolderPath 'module' -DestinationPath $destination -GitRef 'main' -Commit $commit1

            $result | Should -Be $commit1
            Get-Content -Raw (Join-Path $destination 'version.txt') | Should -Be "c1`n"
        }

        Context 'When the git server does not allow a specific commit to be fetched' {
            BeforeAll {
                # The original git protocol only allows advertised objects (e.g. branch tips) to be fetched
                setGitEnvironmentConfig @{ 'protocol.version' = '0' }
            }
            AfterAll {
                clearGitEnvironmentConfig
            }

            It 'Falls back to fetching the history of the git reference' {
                $destination = Join-Path $targetPath 'pinned-fallback'

                $result = _copyFolderFromGitRepo -RepoUrl $repoUrl -RepoFolderPath 'module' -DestinationPath $destination -GitRef 'main' -Commit $commit1

                $result | Should -Be $commit1
                Get-Content -Raw (Join-Path $destination 'version.txt') | Should -Be "c1`n"
                Should -Invoke Write-Verbose -ParameterFilter { $Message -like 'Unable to fetch commit*' } -Times 1
            }
        }
    }

    Context 'Replacing an existing copy' {
        It 'Replaces the existing folder rather than copying into it' {
            $destination = Join-Path $targetPath 'existing'
            setFixtureFile (Join-Path $destination 'stale.txt') "stale`n"

            _copyFolderFromGitRepo -RepoUrl $repoUrl -RepoFolderPath 'module' -DestinationPath $destination | Out-Null

            Join-Path $destination 'Fixture.psd1' | Should -Exist
            Join-Path $destination 'stale.txt' | Should -Not -Exist
            Join-Path $destination 'module' | Should -Not -Exist
        }
    }

    Context 'Line endings' {
        BeforeAll {
            # Mimic a Windows user's typical git configuration, which converts line endings on checkout
            setGitEnvironmentConfig @{ 'core.autocrlf' = 'true' }
        }
        AfterAll {
            clearGitEnvironmentConfig
        }

        It 'Ignores the user''s line-ending settings so that the copied files are the same on every machine' {
            $destination = Join-Path $targetPath 'line-endings'

            _copyFolderFromGitRepo -RepoUrl $repoUrl -RepoFolderPath 'module' -DestinationPath $destination | Out-Null

            $bytes = [IO.File]::ReadAllBytes((Join-Path $destination 'tasks' 'sample.tasks.ps1'))
            $bytes | Should -Not -Contain ([byte][char]"`r")
        }
    }

    Context 'Error handling' {
        BeforeAll {
            Mock New-Guid { 'zf-copy-folder-test' }
            $expectedTempDir = Join-Path ([System.IO.Path]::GetTempPath()) 'zf-copy-folder-test'
        }

        It 'Throws when the git CLI is not available' {
            { _copyFolderFromGitRepo -RepoUrl $repoUrl -RepoFolderPath 'module' -DestinationPath (Join-Path $targetPath 'no-git') -GitCmd 'not-a-real-git-command' } |
                Should -Throw '*Git CLI is not installed*'
        }

        It 'Throws with the git output when the git reference does not exist' {
            { _copyFolderFromGitRepo -RepoUrl $repoUrl -RepoFolderPath 'module' -DestinationPath (Join-Path $targetPath 'bad-ref') -GitRef 'does-not-exist' } |
                Should -Throw '*git fetch*does-not-exist*'
        }

        It 'Throws when the folder does not exist in the repository' {
            { _copyFolderFromGitRepo -RepoUrl $repoUrl -RepoFolderPath 'not-a-folder' -DestinationPath (Join-Path $targetPath 'bad-folder') } |
                Should -Throw "*The folder 'not-a-folder' does not exist*"
        }

        It 'Removes the temporary folder when an error occurs' {
            { _copyFolderFromGitRepo -RepoUrl $repoUrl -RepoFolderPath 'not-a-folder' -DestinationPath (Join-Path $targetPath 'cleanup') } |
                Should -Throw

            $expectedTempDir | Should -Not -Exist
        }
    }
}
