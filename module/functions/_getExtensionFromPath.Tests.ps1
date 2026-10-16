# <copyright file="_getExtensionFromPath.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest
}

Describe '_getExtensionFromPath' {

    BeforeAll {
        Mock Write-Host {}
        Mock Write-Warning {}
    }

    Context 'When the path exists' {
        BeforeAll {
            $extensionPath = Join-Path $TestDrive 'MyExtension'
            New-Item -ItemType Directory -Path $extensionPath | Out-Null

            $result = _getExtensionFromPath -Name 'MyExtension' -Path $extensionPath
        }

        It 'Enables the extension' {
            $result.Enabled | Should -Be $true
        }

        It 'Does not resolve a version' {
            $result.ResolvedVersion | Should -BeNullOrEmpty
        }

        It 'Does not change the path of the extension' {
            $result.ContainsKey('Path') | Should -Be $false
        }

        It 'Logs that the path is being used' {
            Should -Invoke Write-Host -Times 1 -Scope Context -ParameterFilter { $Object -eq "USING PATH: MyExtension ($extensionPath)" }
        }
    }

    Context 'When the path does not exist' {
        BeforeAll {
            $missingPath = Join-Path $TestDrive 'Missing'

            $result = _getExtensionFromPath -Name 'Missing' -Path $missingPath
        }

        It 'Disables the extension' {
            $result.Enabled | Should -Be $false
        }

        It 'Writes a warning' {
            Should -Invoke Write-Warning -Times 1 -Scope Context -ParameterFilter { $Message -eq "Extension 'Missing' not found at $missingPath - it has been disabled." }
        }
    }
}
