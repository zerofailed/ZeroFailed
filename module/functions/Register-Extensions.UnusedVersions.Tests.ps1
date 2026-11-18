# <copyright file="Register-Extensions.UnusedVersions.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Runs the extension registration with a fake PowerShell repository, to check that a version of an extension that is
# not used does not affect the extensions that are used.

BeforeAll {
    # sut, and every in-module dependency
    foreach ($functionFile in (Get-ChildItem -Path (Split-Path -Parent $PSCommandPath) -Filter '*.ps1' | Where-Object { $_.Name -notlike '*.Tests.ps1' })) {
        . $functionFile.FullName
    }

    Set-StrictMode -Version Latest
}

Describe 'Register-Extensions with a version of an extension that is not used' {

    BeforeAll {
        Mock Write-Host {}
        Mock Write-Warning {}
        Mock Get-ExtensionAvailableTasks { @() }
        Mock _getExtensionFromPSRepository {
            # A minimum version resolves to 1.3.0
            $resolvedVersion = $Version ? $Version : '1.3.0'
            $path = Join-Path $TargetPath $Name $resolvedVersion
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Set-Content -Path (Join-Path $path "$Name.psm1") -Value "# $Name $resolvedVersion"
            @{ Path = $path; Enabled = $true; ResolvedVersion = $resolvedVersion }
        }

        $script:localCommonPath = Join-Path $TestDrive 'Common' 'module'
        New-Item -ItemType Directory -Path $script:localCommonPath -Force | Out-Null
        Set-Content -Path (Join-Path $script:localCommonPath 'Common.psd1') -Value '@{}'

        # Registers the configuration, then removes the duplicates, as 'ZeroFailed.tasks' does
        $register = {
            param ($config, $lockMode = 'Write')
            $registered = Register-Extensions -ExtensionsConfig $config -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode $lockMode
            , @(Resolve-ExtensionDuplicates -Extensions $registered)
        }
        $readLockFile = { Get-Content -Raw (Join-Path $zfPath 'extensions.lock.json') | ConvertFrom-Json -AsHashtable }
    }

    BeforeEach {
        $originalPSModulePath = $env:PSModulePath
        $zfPath = Join-Path $TestDrive ([guid]::NewGuid())
    }

    AfterEach {
        $env:PSModulePath = $originalPSModulePath
    }

    Context 'When the configuration chooses an exact version, and only the other version requires a dependency' {
        BeforeAll {
            # The configuration has 'A' 1.0.0, and 'X' requires 'A' 2.0.0, which requires 'Common' and declares its process
            Mock Get-ExtensionDependencies {
                switch ($Extension.Name) {
                    'X' { @{ Name = 'A'; Version = '2.0.0' } }
                    'A' { if ($Extension.Path -like '*2.0.0') { @{ Name = 'Common'; Version = '1.0.0'; Process = 'tasks/old.process.ps1' } } }
                }
            }
        }

        It 'Does not use the dependency, or record it in the lock file' {
            $result = & $register @(@{ Name = 'A'; Version = '1.0.0' }, @{ Name = 'X'; Version = '1.0.0' })

            $result.Name | Should -Be @('A', 'X')
            $result[0].Path | Should -BeLike '*1.0.0'
            (& $readLockFile).extensions.Keys | Should -Not -Contain 'Common'
        }

        It 'Does not give a local extension in its place the process, or record the extension that requires it' {
            $result = & $register @(@{ Name = 'A'; Version = '1.0.0' }, @{ Name = 'X'; Version = '1.0.0' }, @{ Path = $script:localCommonPath })

            $common = @($result | Where-Object { $_.Name -eq 'Common' })
            $common.Count | Should -Be 1
            $common[0].ContainsKey('Process') | Should -BeFalse
            (& $readLockFile).extensions.Common.requiredBy | Should -BeNullOrEmpty
        }
    }

    Context 'When the configuration chooses a version that is in the range that another extension requires' {
        BeforeAll {
            # The configuration has 'A' 1.6.0 and 'Common' 1.4.0. 'X' requires 'A' 1.0 or later, which resolves to 1.3.0,
            # and requires 'Common' 1.0 or later and declares its process.
            Mock Get-ExtensionDependencies {
                switch ($Extension.Name) {
                    'X' { @{ Name = 'A'; MinimumVersion = '1.0' } }
                    'A' { if ($Extension.Path -like '*1.3.0') { @{ Name = 'Common'; MinimumVersion = '1.0'; Process = 'tasks/old.process.ps1' } } }
                }
            }
        }

        It 'Does not use the process that only the version that is not used declares' {
            $result = & $register @(@{ Name = 'A'; Version = '1.6.0' }, @{ Name = 'Common'; Version = '1.4.0' }, @{ Name = 'X'; Version = '1.0.0' })

            $result.Name | Should -Be @('A', 'Common', 'X')
            $result[1].Path | Should -BeLike '*1.4.0'
            $result[1].ContainsKey('Process') | Should -BeFalse
            (& $readLockFile).extensions.Common.requiredBy | Should -BeNullOrEmpty
        }
    }

    Context 'When an extension that is used declares the process of another version of an extension in the configuration' {
        BeforeAll {
            # The configuration has 'Common' 1.0.0, and 'X' requires 'Common' 2.0.0 and declares its process. The lock
            # file records 'Common' 1.0.0, so a Frozen run does not install 2.0.0.
            Mock Get-ExtensionDependencies {
                switch ($Extension.Name) {
                    'X' { @{ Name = 'Common'; Version = '2.0.0'; Process = 'tasks/build.process.ps1' } }
                }
            }
        }

        It 'Uses the process in <LockMode> mode' -ForEach @(@{ LockMode = 'Write' }, @{ LockMode = 'Frozen' }) {
            # Registration adds to the configuration, so each run has its own
            $newConfig = { @(@{ Name = 'Common'; Version = '1.0.0' }, @{ Name = 'X'; Version = '1.0.0' }) }
            if ($LockMode -eq 'Frozen') {
                & $register (& $newConfig) 'Write' | Out-Null
            }

            $result = & $register (& $newConfig) $LockMode

            $result.Name | Should -Be @('Common', 'X')
            $result[0].Path | Should -BeLike '*1.0.0'
            $result[0].Process | Should -Be 'tasks/build.process.ps1'
        }
    }

    Context 'When the configuration lists an extension twice in a range, and only the second declares its process' {
        BeforeAll {
            Mock Get-ExtensionDependencies {}
        }

        It 'Uses the process' {
            $result = & $register @(@{ Name = 'Common'; MinimumVersion = '1.0' }, @{ Name = 'Common'; MinimumVersion = '1.0'; Process = 'tasks/build.process.ps1' })

            $result.Count | Should -Be 1
            $result[0].Process | Should -Be 'tasks/build.process.ps1'
        }
    }

    Context 'When the version that is used declares the process of a dependency whose other occurrence is discarded' {
        BeforeAll {
            # 'A' and 'B' both require 'Common' 1.0 or later. Only 'B' declares its process, and the occurrence that 'B'
            # registers is discarded.
            Mock Get-ExtensionDependencies {
                switch ($Extension.Name) {
                    'A' { @{ Name = 'Common'; MinimumVersion = '1.0' } }
                    'B' { @{ Name = 'Common'; MinimumVersion = '1.0'; Process = 'tasks/build.process.ps1' } }
                }
            }
        }

        It 'Uses the process, and records both extensions in the lock file' {
            $result = & $register @(@{ Name = 'A'; Version = '1.0.0' }, @{ Name = 'B'; Version = '1.0.0' })

            $common = @($result | Where-Object { $_.Name -eq 'Common' })
            $common.Count | Should -Be 1
            $common[0].Process | Should -Be 'tasks/build.process.ps1'
            (& $readLockFile).extensions.Common.requiredBy | Should -Be @('A', 'B')
        }
    }
}
