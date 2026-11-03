# <copyright file="_waitForExtensionsLock.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest

    # Tries to acquire the lock for a path from another thread, as a mutex can be acquired more than once by the same
    # thread. Returns whether it was acquired.
    function testLockFromOtherThread([string] $ZfPath) {
        $powershell = [powershell]::Create()
        try {
            $null = $powershell.AddScript(". '$($PSCommandPath.Replace('.Tests.ps1','.ps1'))'").AddStatement()
            $null = $powershell.AddScript({
                param ($ZfPath)
                function Write-Host {}
                try {
                    $mutex = _waitForExtensionsLock -ZfPath $ZfPath -Timeout ([timespan]::FromMilliseconds(100))
                    $mutex.ReleaseMutex()
                    $mutex.Dispose()
                    $true
                }
                catch {
                    $false
                }
            }).AddArgument($ZfPath)
            $powershell.Invoke() | Select-Object -Last 1
        }
        finally {
            $powershell.Dispose()
        }
    }
}

Describe '_waitForExtensionsLock' {

    BeforeAll {
        Mock Write-Host {}
    }

    BeforeEach {
        $zfPath = Join-Path $TestDrive "zf-$(New-Guid)"
    }

    It 'Returns an acquired mutex' {
        $mutex = _waitForExtensionsLock -ZfPath $zfPath
        try {
            $mutex | Should -BeOfType [System.Threading.Mutex]
            testLockFromOtherThread -ZfPath $zfPath | Should -Be $false
        }
        finally {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
        }
    }

    It 'Can be acquired again once it is released' {
        $mutex = _waitForExtensionsLock -ZfPath $zfPath
        $mutex.ReleaseMutex()
        $mutex.Dispose()

        testLockFromOtherThread -ZfPath $zfPath | Should -Be $true
    }

    It 'Does not block a run that uses a different path' {
        $mutex = _waitForExtensionsLock -ZfPath $zfPath
        try {
            testLockFromOtherThread -ZfPath "$zfPath-other" | Should -Be $true
        }
        finally {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
        }
    }

    It 'Uses the same lock for the same path written differently' {
        $mutex = _waitForExtensionsLock -ZfPath $zfPath
        try {
            testLockFromOtherThread -ZfPath "$zfPath/" | Should -Be $false
        }
        finally {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
        }
    }
}
