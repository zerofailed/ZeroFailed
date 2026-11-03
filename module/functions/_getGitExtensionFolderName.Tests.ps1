# <copyright file="_getGitExtensionFolderName.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getNormalizedGitRepositoryUrl.ps1')

    Set-StrictMode -Version Latest
}

Describe '_getGitExtensionFolderName' {

    BeforeAll {
        $repo = 'https://github.com/zerofailed/ZeroFailed.Build.Test'
    }

    It 'Names the folder after the git reference, followed by a short hash of the source' {
        $result = _getGitExtensionFolderName -RepositoryUri $repo -RepositoryFolderPath 'module' -GitRef 'main'

        $result | Should -Match '^main-[0-9a-f]{8}$'
    }

    It 'Replaces any / in the git reference' {
        $result = _getGitExtensionFolderName -RepositoryUri $repo -RepositoryFolderPath 'module' -GitRef 'refs/tags/v1.0.0'

        $result | Should -Match '^refs-tags-v1\.0\.0-[0-9a-f]{8}$'
    }

    It 'Returns the same name for the same source' {
        $first = _getGitExtensionFolderName -RepositoryUri $repo -RepositoryFolderPath 'module' -GitRef 'main'
        $second = _getGitExtensionFolderName -RepositoryUri $repo -RepositoryFolderPath 'module' -GitRef 'main'

        $second | Should -Be $first
    }

    It 'Ignores the case of the repository URL, and a trailing /' {
        $expected = _getGitExtensionFolderName -RepositoryUri $repo -RepositoryFolderPath 'module' -GitRef 'main'

        $result = _getGitExtensionFolderName -RepositoryUri "$($repo.ToUpperInvariant())/" -RepositoryFolderPath 'module' -GitRef 'main'

        $result | Should -Be $expected
    }

    It 'Ignores a trailing .git in the repository URL (<Suffix>)' -ForEach @(
        @{ Suffix = '.git' }
        @{ Suffix = '.GIT/' }
    ) {
        $expected = _getGitExtensionFolderName -RepositoryUri $repo -RepositoryFolderPath 'module' -GitRef 'main'

        $result = _getGitExtensionFolderName -RepositoryUri "$repo$Suffix" -RepositoryFolderPath 'module' -GitRef 'main'

        $result | Should -Be $expected
    }

    It 'Returns a different name for a different <Description>' -ForEach @(
        @{ Description = 'repository'; Repository = 'https://github.com/myfork/ZeroFailed.Build.Test'; FolderPath = 'module' }
        @{ Description = 'folder in the repository'; Repository = 'https://github.com/zerofailed/ZeroFailed.Build.Test'; FolderPath = 'src' }
        @{ Description = 'case of the folder in the repository'; Repository = 'https://github.com/zerofailed/ZeroFailed.Build.Test'; FolderPath = 'Module' }
    ) {
        $upstream = _getGitExtensionFolderName -RepositoryUri $repo -RepositoryFolderPath 'module' -GitRef 'main'

        $result = _getGitExtensionFolderName -RepositoryUri $Repository -RepositoryFolderPath $FolderPath -GitRef 'main'

        $result | Should -Match '^main-[0-9a-f]{8}$'
        $result | Should -Not -Be $upstream
    }
}
