# <copyright file="_resolveModuleNameFromPath.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
}

Describe '_resolveModuleNameFromPath' {
    Context 'Valid module path' {
        BeforeAll {
            $testModulePath = Join-Path TestDrive: "TestModule"
            New-Item -Path $testModulePath -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $testModulePath "TestModule.psd1") -ItemType File -Force | Out-Null
        }

        It 'Should return the correct module name for a single psd1' {
            $moduleName = _resolveModuleNameFromPath -Path $testModulePath
            $moduleName | Should -Be "TestModule"
        }
    }

    Context 'Valid module path with multiple psd1 files' {
        BeforeAll {            
            $testModulePath = Join-Path TestDrive: "MultiPsd1Module"
            New-Item -Path $testModulePath -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $testModulePath "ModuleA.psd1") -ItemType File -Force | Out-Null
            New-Item -Path (Join-Path $testModulePath "ModuleB.psd1") -ItemType File -Force | Out-Null
        }
        
        It 'Should return the first module name found and log a warning' {
            Mock Write-Warning {}

            $moduleName = _resolveModuleNameFromPath -Path $testModulePath
            $moduleName | Should -Be "ModuleA"
            Should -Invoke Write-Warning -Times 1 -Exactly -Scope Context
        }
    }

    Context 'Invalid module path - no psd1 files' {
        BeforeAll {
            $testModulePath = Join-Path TestDrive: "NoPsd1Module"
            New-Item -Path $testModulePath -ItemType Directory -Force | Out-Null
        }

        It 'Should throw an exception' {
            {
                _resolveModuleNameFromPath -Path $testModulePath
            } | Should -Throw "Unable to find the extension's module manifest in '$testModulePath'"
        }
    }

    Context 'Invalid module path - non-existent directory' {
        BeforeAll {
            $nonExistentPath = Join-Path TestDrive: "NonExistentDir"
        }

        It 'Should throw an exception' {
            {
                _resolveModuleNameFromPath -Path $nonExistentPath
            } | Should -Throw "Unable to find the extension's module manifest in '$nonExistentPath'"
        }
    }
}