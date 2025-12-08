# <copyright file="_installVendir.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest
}

Describe '_installVendir Tests' {

    BeforeAll {
        # Use the $TestDrive form instead of TestDrive: to ensure valid physical paths are passed to vendir
        $zfPath = Join-Path -Path $TestDrive -ChildPath '.zf'
        $installDir = Join-Path -Path $zfPath -ChildPath 'bin'
        New-Item -Path $zfPath -ItemType Directory -Force | Out-Null
        $splat = @{
            InstallDir = $installDir
            NoVerify = $true
        }

        Mock Write-Warning {}
        Mock Write-Verbose {}
        Mock Invoke-RestMethod {}
        Mock Get-FileHash { @{ Hash = 'mock-hash' } }
        Mock Invoke-Command { vendir }
        
        function chmod {}
        Mock chmod {}
    }

    Context "Installation tests" {

        Context 'No existing installation' {
            BeforeAll {
                Mock Get-Command {} -ParameterFilter { $Name -eq 'vendir' }
            }

            It 'Should attempt to download vendir' {
                $result = _installVendir @splat

                Should -Invoke Invoke-RestMethod -Times 1
                Should -Invoke Get-FileHash -Times 1
                Should -Invoke Write-Warning -Times 1

                if (!$IsWindows) {
                    $result | Should -Be (Join-Path $installDir 'vendir')
                    Should -Invoke chmod -Times 1
                }
                else {
                    $result | Should -Be (Join-Path $installDir 'vendir.exe')
                }
            }
        }

        Context 'vendir available in PATH' {
            BeforeAll {
                Mock Get-Command { @{Name='vendir'} } -ParameterFilter { $Name -eq 'vendir' }
            }

            It 'Should not attempt to download vendir' {
                $result = _installVendir @splat

                $result | Should -Be 'vendir'
                Should -Not -Invoke Invoke-RestMethod
                Should -Not -Invoke Get-FileHash
            }
        }

        Context 'vendir previously installed by ZF' {
            BeforeAll {
                # Mock the first check for vendir in the PATH
                Mock Get-Command {} -ParameterFilter { $Name -eq 'vendir' }
                $zfVendirInstallPath = Join-Path -Path $installDir -ChildPath 'vendir'
                # Mock the second check for vendir in the ZF install location
                Mock Get-Command { @{Name='vendir'} } `
                    -ParameterFilter { $Name.StartsWith($zfVendirInstallPath) }   # .StartsWith() enable a cross-platform match
            }

            It 'Should not attempt to download vendir' {
                $result = _installVendir @splat

                if (!$IsWindows) {
                    $result | Should -Be (Join-Path $installDir 'vendir')
                }
                else {
                    $result | Should -Be (Join-Path $installDir 'vendir.exe')
                }
                Should -Not -Invoke Invoke-RestMethod
                Should -Not -Invoke Get-FileHash
            }
        }
    }
}