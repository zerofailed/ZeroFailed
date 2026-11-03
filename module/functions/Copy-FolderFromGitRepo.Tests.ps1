# <copyright file="Copy-FolderFromGitRepo.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_copyFolderFromGitRepo.ps1')
}

Describe 'Copy-FolderFromGitRepo' {
    # Setup TestDrive with sample extension definitions
    BeforeAll {
        # Setup .zf folder
        $targetPath = Join-Path -Path TestDrive: -ChildPath '.zf' 'extensions'
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
    }

    Context 'Basic' {
        BeforeAll {
            $gitRef = 'main'
            $result = Copy-FolderFromGitRepo `
                -RepoUrl 'https://github.com/zerofailed/ZeroFailed.Build.DotNet.git' `
                -DestinationPath (Join-Path $targetPath 'FooExtension' $gitRef) `
                -RepoFolderPath 'module' `
                -GitRef $gitRef
        }

        It 'should copy the folder to the target path' {
            Test-Path (Join-Path -Path $targetPath -ChildPath 'FooExtension/main/ZeroFailed.Build.DotNet.psd1') | Should -Be $true
        }

        It 'should not return any output' {
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Delegation' {
        BeforeAll {
            Mock _copyFolderFromGitRepo { 'abc123' }

            $result = Copy-FolderFromGitRepo `
                -RepoUrl 'https://example.com/repo.git' `
                -DestinationPath (Join-Path $targetPath 'BarExtension' 'v1') `
                -RepoFolderPath 'src' `
                -GitRef 'v1' `
                -GitCmd 'mygit'
        }

        It 'should pass its parameters to the private implementation' {
            Should -Invoke _copyFolderFromGitRepo -Times 1 -Scope Context -ParameterFilter {
                $RepoUrl -eq 'https://example.com/repo.git' -and
                $RepoFolderPath -eq 'src' -and
                $GitRef -eq 'v1' -and
                $GitCmd -eq 'mygit'
            }
        }

        It 'should not return the resolved commit' {
            $result | Should -BeNullOrEmpty
        }
    }
}
