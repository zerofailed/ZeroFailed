# <copyright file="Get-ExtensionAvailableTasks.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $sut = (Split-Path -Leaf $PSCommandPath) -replace ".Tests"
    
    . "$here/$sut"
    
    # dot source dependencies
    . "$here/Get-TasksFileListFromExtension.ps1"

    Set-StrictMode -Version Latest
}

Describe 'Get-ExtensionAvailableTasks' {

    BeforeAll {
        Mock Write-Warning {}
        Mock Write-Verbose {}
    }

    Context 'Tasks directory does not exist' {
        BeforeAll {
            $testPath = Join-Path TestDrive: 'NoTasksDir'
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null
        }

        It 'Should return an empty array and warn' {
            $result = Get-ExtensionAvailableTasks -ExtensionPath $testPath
            $result | Should -BeNullOrEmpty
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "No tasks directory found*" }
        }
    }

    Context 'Tasks directory exists' {
        BeforeAll {
            $extensionPath = Join-Path TestDrive: 'WithTasks'
            $tasksPath = Join-Path $extensionPath 'tasks'
            New-Item -Path $tasksPath -ItemType Directory -Force | Out-Null

            # Create dummy task files
            Set-Content -Path (Join-Path $tasksPath 'valid.tasks.ps1') -Value "task 'ValidTask'"
            Set-Content -Path (Join-Path $tasksPath '_private.tasks.ps1') -Value "task 'PrivateTask'"
            Set-Content -Path (Join-Path $tasksPath 'multi.tasks.ps1') -Value "task 'TaskA'; task 'TaskB'"
        }

        It 'Should return all public tasks' {
            $result = Get-ExtensionAvailableTasks -ExtensionPath $extensionPath
            $result | Should -Contain 'ValidTask'
            $result | Should -Contain 'TaskA'
            $result | Should -Contain 'TaskB'
            $result.Count | Should -Be 3
        }

        It 'Should not return private tasks' {
            $result = Get-ExtensionAvailableTasks -ExtensionPath $extensionPath
            $result | Should -Not -Contain 'PrivateTask'
        }
    }

    Context 'Task file with errors' {
        BeforeAll {
            $extensionPath = Join-Path TestDrive: 'ErrorTasks'
            $tasksPath = Join-Path $extensionPath 'tasks'
            New-Item -Path $tasksPath -ItemType Directory -Force | Out-Null

            Set-Content -Path (Join-Path $tasksPath 'error.tasks.ps1') -Value "throw 'Oops'"
            Set-Content -Path (Join-Path $tasksPath 'valid.tasks.ps1') -Value "task 'ValidTask'"
        }

        It 'Should suppress errors and continue' {
            [array]$result = Get-ExtensionAvailableTasks -ExtensionPath $extensionPath
            $result | Should -Contain 'ValidTask'
            $result.Count | Should -Be 1
        }
    }
}
