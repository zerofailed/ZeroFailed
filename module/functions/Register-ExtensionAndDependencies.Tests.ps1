# <copyright file="Register-ExtensionAndDependencies.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-ExtensionFromGitRepository.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-InstalledExtensionDetails.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Copy-FolderFromGitRepo.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-ExtensionDependencies.ps1')

    # make available for mocking
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-ExtensionAvailableTasks.ps1')
}

Describe 'Register-ExtensionAndDependencies' {
    BeforeAll {
        # Setup .zf folder
        $targetPath = Join-Path -Path TestDrive: -ChildPath '.zf' 'extensions'
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null

        Mock Write-Host {}  # suppress logging
        Mock Get-ExtensionAvailableTasks {
            param ($ExtensionPath)
            return @("MockTask1", "MockTask2")
        }
    }

    Context 'Git-Based Extensions' {
        
        Context 'When processing a single extension with no dependencies (no version constraint)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = "ZeroFailed.DevOps.Common"                
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.DevOps.Common"
                }
    
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
    
                $result.Count | Should -Be 1
                $result[0].Name | Should -Be "ZeroFailed.DevOps.Common"
                $result[0].Version | Should -Be $null
                $result[0].GitRef | Should -Be $null
                $result[0].Enabled | Should -Be $true
            }
        }

        Context 'When processing a single extension with no dependencies  (with version constraint)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = "ZeroFailed.DevOps.Common"                
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.DevOps.Common"
                    GitRef = "refs/heads/main"
                }
    
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
    
                $result.Count | Should -Be 1
                $result[0].Name | Should -Be "ZeroFailed.DevOps.Common"
                $result[0].Version | Should -Be $null
                $result[0].GitRef | Should -Be "refs/heads/main"
                $result[0].Enabled | Should -Be $true
            }
        }

        Context 'When processing a single extension with 1 dependency (version constraint)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = "ZeroFailed.Build.Common"                
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.Common"
                    GitRef = "refs/heads/main"
                }
    
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
    
                $result.Count | Should -Be 2

                $result[0].Name | Should -Be "ZeroFailed.Build.Common"
                $result[0].Version | Should -Be $null
                $result[0].GitRef | Should -Be "refs/heads/main"
                $result[0].Enabled | Should -Be $true

                $result[1].Name | Should -Be "ZeroFailed.DevOps.Common"
                $result[1].Version | Should -Be $null
                $result[1].GitRef | Should -Be $null
                $result[1].Enabled | Should -Be $true
            }
        }

        Context 'When processing a single extension with multiple dependencies (version constraint)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = "ZeroFailed.Build.DotNet"                
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.DotNet"
                    GitRef = "refs/heads/main"
                }
    
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
    
                $result.Count | Should -Be 3

                $result[0].Name | Should -Be "ZeroFailed.Build.DotNet"
                $result[0].Version | Should -Be $null
                $result[0].GitRef | Should -Be "refs/heads/main"
                $result[0].Enabled | Should -Be $true

                $result[1].Name | Should -Be "ZeroFailed.Build.Common"
                $result[1].Version | Should -Be $null
                $result[1].GitRef | Should -Be $null
                $result[1].Enabled | Should -Be $true

                $result[2].Name | Should -Be "ZeroFailed.DevOps.Common"
                $result[2].Version | Should -Be $null
                $result[2].GitRef | Should -Be $null
                $result[2].Enabled | Should -Be $true
            }
        }
    }
}
