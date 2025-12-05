# <copyright file="Get-TasksFileListFromExtension.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $sut = (Split-Path -Leaf $PSCommandPath) -replace ".Tests"

    . "$here/$sut"
    
    Set-StrictMode -Version Latest
}

Describe 'Get-TasksFileListFromExtension' {
    Context 'Path does not exist' {
        It 'Should return an empty array' {
            $result = Get-TasksFileListFromExtension -TasksPath 'TestDrive:\NonExistentPath'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Path exists' {
        BeforeAll {
            # Setup TestDrive structure
            $root = 'TestDrive:\TasksRoot'
            New-Item -Path $root -ItemType Directory -Force | Out-Null
            
            # Matching files
            New-Item -Path "$root\task1.tasks.ps1" -ItemType File -Force | Out-Null
            New-Item -Path "$root\subfolder" -ItemType Directory -Force | Out-Null
            New-Item -Path "$root\subfolder\task2.tasks.ps1" -ItemType File -Force | Out-Null
            
            # Non-matching files
            New-Item -Path "$root\readme.txt" -ItemType File -Force | Out-Null
            New-Item -Path "$root\script.ps1" -ItemType File -Force | Out-Null
            
            # Custom glob files
            New-Item -Path "$root\custom.myext" -ItemType File -Force | Out-Null
        }

        It 'Should return all matching files recursively with default glob' {
            $result = Get-TasksFileListFromExtension -TasksPath 'TestDrive:\TasksRoot'
            $result.Count | Should -Be 2
            $result.Name | Should -Contain 'task1.tasks.ps1'
            $result.Name | Should -Contain 'task2.tasks.ps1'
        }

        It 'Should return matching files with custom glob' {
            [array]$result = Get-TasksFileListFromExtension -TasksPath 'TestDrive:\TasksRoot' -TasksFileGlob '*.myext'
            $result.Count | Should -Be 1
            $result.Name | Should -Be 'custom.myext'
        }
        
        It 'Should return empty if no files match' {
             $result = Get-TasksFileListFromExtension -TasksPath 'TestDrive:\TasksRoot' -TasksFileGlob '*.nonexistent'
             $result | Should -BeNullOrEmpty
        }
    }
}
