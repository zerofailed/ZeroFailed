# <copyright file="_mergeExtensionProcess.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest
}

Describe '_mergeExtensionProcess' {

    BeforeAll {
        Mock Write-Warning {}
    }

    It 'Copies the process of the duplicate when the extension has none' {
        $extension = @{ Name = 'ZeroFailed.Build.Common'; Path = './module' }

        _mergeExtensionProcess -Extension $extension -Duplicate @{ Name = 'ZeroFailed.Build.Common'; Process = 'tasks/build.process.ps1' }

        $extension.Process | Should -Be 'tasks/build.process.ps1'
        Should -Invoke Write-Warning -Times 0 -Exactly
    }

    It 'Copies the process of the duplicate when the extension has an empty one' {
        $extension = @{ Name = 'ZeroFailed.Build.Common'; Process = '' }

        _mergeExtensionProcess -Extension $extension -Duplicate @{ Name = 'ZeroFailed.Build.Common'; Process = 'tasks/build.process.ps1' }

        $extension.Process | Should -Be 'tasks/build.process.ps1'
    }

    It 'Does not copy the process of the duplicate when the extension is disabled' {
        $extension = @{ Name = 'ZeroFailed.Build.Common'; Enabled = $false }

        _mergeExtensionProcess -Extension $extension -Duplicate @{ Name = 'ZeroFailed.Build.Common'; Enabled = $true; Process = 'tasks/build.process.ps1' }

        $extension.ContainsKey('Process') | Should -BeFalse
    }

    It 'Does not copy the process of the duplicate when the duplicate is disabled' {
        $extension = @{ Name = 'ZeroFailed.Build.Common'; Enabled = $true }

        _mergeExtensionProcess -Extension $extension -Duplicate @{ Name = 'ZeroFailed.Build.Common'; Enabled = $false; Process = 'tasks/build.process.ps1' }

        $extension.ContainsKey('Process') | Should -BeFalse
    }

    It 'Keeps the process of the extension when the duplicate has none' {
        $extension = @{ Name = 'ZeroFailed.Build.Common'; Process = 'tasks/build.process.ps1' }

        _mergeExtensionProcess -Extension $extension -Duplicate @{ Name = 'ZeroFailed.Build.Common' }

        $extension.Process | Should -Be 'tasks/build.process.ps1'
        Should -Invoke Write-Warning -Times 0 -Exactly
    }

    It 'Does not add a process when neither declares one' {
        $extension = @{ Name = 'ZeroFailed.Build.Common' }

        _mergeExtensionProcess -Extension $extension -Duplicate @{ Name = 'ZeroFailed.Build.Common' }

        $extension.ContainsKey('Process') | Should -BeFalse
    }

    It 'Does not warn when both declare the same process' {
        $extension = @{ Name = 'ZeroFailed.Build.Common'; Process = 'tasks/build.process.ps1' }

        _mergeExtensionProcess -Extension $extension -Duplicate @{ Name = 'ZeroFailed.Build.Common'; Process = 'tasks/build.process.ps1' }

        Should -Invoke Write-Warning -Times 0 -Exactly
    }

    It 'Keeps the process of the extension, and warns, when both declare a different process' {
        $extension = @{ Name = 'ZeroFailed.Build.Common'; Process = 'tasks/build.process.ps1' }

        _mergeExtensionProcess -Extension $extension -Duplicate @{ Name = 'ZeroFailed.Build.Common'; Process = 'tasks/other.process.ps1' }

        $extension.Process | Should -Be 'tasks/build.process.ps1'
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
            $Message -like "*'ZeroFailed.Build.Common'*tasks/build.process.ps1*tasks/other.process.ps1*"
        }
    }
}
