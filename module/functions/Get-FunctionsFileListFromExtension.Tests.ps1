# <copyright file="Get-FunctionsFileListFromExtension.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $sut = (Split-Path -Leaf $PSCommandPath) -replace ".Tests"
    
    . "$here/$sut"

    Set-StrictMode -Version Latest
}

Describe 'Get-FunctionsFileListFromExtension' {

    Context 'Functions path does not exist' {
        It 'Should return an empty array' {
            $result = Get-FunctionsFileListFromExtension -FunctionsPath 'TestDrive:\NonExistentPath'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Functions path exists' {
        BeforeAll {
            $rootPath = Join-Path TestDrive: 'FunctionsRoot'
            New-Item -Path $rootPath -ItemType Directory -Force | Out-Null

            # Create valid function files
            New-Item -Path (Join-Path $rootPath 'Function1.ps1') -ItemType File -Force | Out-Null
            New-Item -Path (Join-Path $rootPath 'Function2.ps1') -ItemType File -Force | Out-Null

            # Create test file (should be excluded)
            New-Item -Path (Join-Path $rootPath 'Function1.Tests.ps1') -ItemType File -Force | Out-Null

            # Create nested directory
            $nestedPath = Join-Path $rootPath 'Nested'
            New-Item -Path $nestedPath -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $nestedPath 'NestedFunction.ps1') -ItemType File -Force | Out-Null
            New-Item -Path (Join-Path $nestedPath 'NestedFunction.Tests.ps1') -ItemType File -Force | Out-Null
            
            # Create non-ps1 file
            New-Item -Path (Join-Path $rootPath 'ReadMe.md') -ItemType File -Force | Out-Null
        }

        It 'Should return all .ps1 files recursively' {
            $result = Get-FunctionsFileListFromExtension -FunctionsPath $rootPath
            $result.Count | Should -Be 3
            $result.Name | Should -Contain 'Function1.ps1'
            $result.Name | Should -Contain 'Function2.ps1'
            $result.Name | Should -Contain 'NestedFunction.ps1'
        }

        It 'Should exclude .Tests.ps1 files' {
            $result = Get-FunctionsFileListFromExtension -FunctionsPath $rootPath
            $result.Name | Should -Not -Contain 'Function1.Tests.ps1'
            $result.Name | Should -Not -Contain 'NestedFunction.Tests.ps1'
        }
        
        It 'Should exclude non-ps1 files' {
            $result = Get-FunctionsFileListFromExtension -FunctionsPath $rootPath
            $result.Name | Should -Not -Contain 'ReadMe.md'
        }
    }
}
