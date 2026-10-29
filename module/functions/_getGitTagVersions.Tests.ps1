# <copyright file="_getGitTagVersions.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getVersionFromGitTag.ps1')

    Set-StrictMode -Version Latest

    # Runs a git command to build the fixture repository, failing the test setup if it does not succeed
    function invokeFixtureGit {
        $output = & git @args 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "git $($args -join ' ') failed: $($output -join "`n")"
        }
        $output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
    }
}

Describe '_getGitTagVersions' {

    BeforeAll {
        # Build a repository with release tags (lightweight and annotated, with and without a 'v' prefix),
        # tags that are not releases, and a branch that is named like a release
        $sourceRepo = Join-Path $TestDrive 'source'
        invokeFixtureGit -c init.defaultBranch=main init --quiet $sourceRepo | Out-Null
        invokeFixtureGit -C $sourceRepo config user.email 'test@example.com' | Out-Null
        invokeFixtureGit -C $sourceRepo config user.name 'Test' | Out-Null
        invokeFixtureGit -C $sourceRepo commit --quiet --allow-empty -m 'c1' | Out-Null
        invokeFixtureGit -C $sourceRepo tag '1.0.0' | Out-Null
        invokeFixtureGit -C $sourceRepo tag -a 'v1.2.0' -m 'v1.2.0' | Out-Null
        invokeFixtureGit -C $sourceRepo tag '1.3.0-beta.1' | Out-Null
        invokeFixtureGit -C $sourceRepo tag 'v1' | Out-Null
        invokeFixtureGit -C $sourceRepo tag 'release-notes' | Out-Null
        invokeFixtureGit -C $sourceRepo branch '2.0.0' | Out-Null

        # Serve it as a bare repository via a 'file://' URL, so that git uses its network protocol
        $bareRepo = Join-Path $TestDrive 'fixture.git'
        invokeFixtureGit clone --bare --quiet $sourceRepo $bareRepo | Out-Null
        $repoUrl = [uri]::new($bareRepo, [UriKind]::Absolute).AbsoluteUri

        Mock Write-Verbose {}
    }

    It 'Returns each release tag with its version' {
        $result = @(_getGitTagVersions -RepoUrl $repoUrl)

        @($result | ForEach-Object { $_.Ref } | Sort-Object) | Should -Be @('refs/tags/1.0.0', 'refs/tags/1.3.0-beta.1', 'refs/tags/v1.2.0')
        ($result | Where-Object { $_.Ref -eq 'refs/tags/v1.2.0' }).Version | Should -Be ([semver]'1.2.0')
        ($result | Where-Object { $_.Ref -eq 'refs/tags/1.3.0-beta.1' }).Version | Should -Be ([semver]'1.3.0-beta.1')
    }

    It 'Throws when the tags cannot be listed' {
        $missingRepoUrl = [uri]::new((Join-Path $TestDrive 'missing.git'), [UriKind]::Absolute).AbsoluteUri

        { _getGitTagVersions -RepoUrl $missingRepoUrl } | Should -Throw "git ls-remote --tags --refs $missingRepoUrl failed*"
    }

    It 'Throws when git is not installed' {
        { _getGitTagVersions -RepoUrl $repoUrl -GitCmd 'not-a-git-command' } | Should -Throw 'Git CLI is not installed*'
    }
}
