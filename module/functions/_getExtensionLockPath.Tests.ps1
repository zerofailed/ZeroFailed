# <copyright file="_getExtensionLockPath.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest
}

Describe '_getExtensionLockPath' {

    BeforeAll {
        $repoPath = Join-Path $TestDrive 'repo'
        $zfPath = Join-Path $repoPath '.zf'
    }

    It 'Returns a full path relative to the base path, with / separators' {
        _getExtensionLockPath -Path (Join-Path $repoPath 'module') -BasePath $zfPath | Should -Be '../module'
    }

    It 'Returns the same path for a process folder under .zf' {
        _getExtensionLockPath -Path (Join-Path $repoPath 'module') -BasePath (Join-Path $zfPath 'build') | Should -Be '../../module'
    }

    It 'Returns the same path whichever separators the path uses' {
        _getExtensionLockPath -Path "$repoPath/src\module/" -BasePath $zfPath | Should -Be '../src/module'
    }

    It 'Resolves a PowerShell drive path' {
        _getExtensionLockPath -Path 'TestDrive:/repo/module' -BasePath 'TestDrive:/repo/.zf' | Should -Be '../module'
    }

    It 'Resolves a relative path from the current location' {
        New-Item -ItemType Directory $repoPath -Force | Out-Null
        Push-Location $repoPath
        try {
            _getExtensionLockPath -Path 'module' -BasePath $zfPath | Should -Be '../module'
        }
        finally {
            Pop-Location
        }
    }

    It 'Resolves an empty base path as the current location' {
        # 'Split-Path -Parent' returns an empty string for a relative extensions folder with no parent folder
        New-Item -ItemType Directory $repoPath -Force | Out-Null
        Push-Location $repoPath
        try {
            _getExtensionLockPath -Path (Join-Path $repoPath 'module') -BasePath '' | Should -Be 'module'
        }
        finally {
            Pop-Location
        }
    }

    It 'Returns . when the path is the base path' {
        _getExtensionLockPath -Path $zfPath -BasePath $zfPath | Should -Be '.'
    }
}
