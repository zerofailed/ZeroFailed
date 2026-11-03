# <copyright file="_getNormalizedGitRepositoryUrl.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest
}

Describe '_getNormalizedGitRepositoryUrl' {

    It 'Normalises <Url>' -ForEach @(
        @{ Url = 'https://github.com/org/repo' }
        @{ Url = 'https://github.com/org/repo/' }
        @{ Url = 'https://github.com/org/repo.git' }
        @{ Url = 'https://github.com/org/repo.git/' }
        @{ Url = 'HTTPS://GitHub.com/Org/Repo.GIT' }
    ) {
        _getNormalizedGitRepositoryUrl -RepositoryUrl $Url | Should -Be 'https://github.com/org/repo'
    }

    It 'Only removes a trailing .git' {
        _getNormalizedGitRepositoryUrl -RepositoryUrl 'https://example.com/my.git.repo' | Should -Be 'https://example.com/my.git.repo'
    }

    It 'Returns an empty string for an empty URL' {
        _getNormalizedGitRepositoryUrl -RepositoryUrl '' | Should -Be ''
    }
}
