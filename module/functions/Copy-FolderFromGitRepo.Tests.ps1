# <copyright file="Copy-FolderFromGitRepo.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
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
            Copy-FolderFromGitRepo `
                -RepoUrl 'https://github.com/zerofailed/ZeroFailed.Build.DotNet.git' `
                -DestinationPath (Join-Path $targetPath 'FooExtension' $gitRef) `
                -RepoFolderPath 'module' `
                -GitRef $gitRef
        }

        It 'should copy the folder to the target path' {
            Test-Path (Join-Path -Path $targetPath -ChildPath 'FooExtension/main/ZeroFailed.Build.DotNet.psd1') | Should -Be $true
        }
    }
    
}