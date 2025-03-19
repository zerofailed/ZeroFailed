# <copyright file="Get-ExtensionFromGitRepository.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-InstalledExtensionDetails.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Copy-FolderFromGitRepo.ps1')
}

Describe 'Get-ExtensionFromGitRepository' {
    # Setup TestDrive with sample extension definitions
    BeforeAll {
        # Setup .zf folder
        $targetPath = Join-Path -Path TestDrive: -ChildPath '.zf' 'extensions'
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
    }

    Context 'Basic' {
        BeforeAll {
            $name = 'ZeroFailed.Build.Common'
            $repo = 'https://github.com/zerofailed/ZeroFailed.Build.DotNet.git'
            $gitRef = 'main'
            $result = Get-ExtensionFromGitRepository -Name $name -TargetPath $targetPath -Repository $repo -GitRef $gitRef
        }
        AfterAll {
            Remove-Item -Path $targetPath/*.* -Recurse -Force
        }

        It 'Should install the extension into the correct location' {
            Test-Path (Join-Path $result.Path 'ZeroFailed.Build.DotNet.psd1') | Should -Be $true
        }
        It "Should install from the correct branch" {
            Split-Path -Leaf $result.Path | Should -Be $gitRef
        }
        It "Should mark the extension as enabled" {
            $result.Enabled | Should -Be $true
        }
    }
}