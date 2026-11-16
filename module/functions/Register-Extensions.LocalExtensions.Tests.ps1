# <copyright file="Register-Extensions.LocalExtensions.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Runs the extension registration with a fake PowerShell repository, to check that a local extension in the
# configuration is used in place of a dependency with the same name.

BeforeAll {
    # sut, and every in-module dependency
    foreach ($functionFile in (Get-ChildItem -Path (Split-Path -Parent $PSCommandPath) -Filter '*.ps1' | Where-Object { $_.Name -notlike '*.Tests.ps1' })) {
        . $functionFile.FullName
    }

    Set-StrictMode -Version Latest
}

Describe 'Register-Extensions with a local extension that a dependency also provides' {

    BeforeAll {
        Mock Write-Host {}
        Mock Write-Warning {}
        Mock Get-ExtensionAvailableTasks { @() }
        Mock _getExtensionFromPSRepository {
            $path = Join-Path $TargetPath $Name $Version
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Set-Content -Path (Join-Path $path "$Name.psm1") -Value "# $Name $Version"
            @{ Path = $path; Enabled = $true; ResolvedVersion = $Version }
        }

        # 'A' requires 'Common' and declares its process. The installed 'Common' requires 'Shared', but the local copy
        # of 'Common' does not.
        Mock Get-ExtensionDependencies {
            switch ($Extension.Name) {
                'A' { @{ Name = 'Common'; Version = '1.6.0'; Process = 'tasks/build.process.ps1' } }
                'Common' { if ($Extension.Path -ne $script:localCommonPath) { @{ Name = 'Shared'; Version = '1.0.0' } } }
            }
        }

        $script:localCommonPath = Join-Path $TestDrive 'Common' 'module'
        New-Item -ItemType Directory -Path $script:localCommonPath -Force | Out-Null
        Set-Content -Path (Join-Path $script:localCommonPath 'Common.psd1') -Value '@{}'

        # The references to 'Common', as an array (',' stops a single one being unrolled into its hashtable)
        $getCommon = { param ($extensions) , @($extensions | Where-Object { $_.Name -eq 'Common' }) }
    }

    BeforeEach {
        $originalPSModulePath = $env:PSModulePath
        $zfPath = Join-Path $TestDrive ([guid]::NewGuid())
    }

    AfterEach {
        $env:PSModulePath = $originalPSModulePath
    }

    Context 'When the local extension is listed <Position>' -ForEach @(
        @{ Position = 'before the extension that requires it'; LocalFirst = $true }
        @{ Position = 'after the extension that requires it'; LocalFirst = $false }
    ) {
        BeforeEach {
            # Registration adds to the configuration, so each run starts from a new copy
            $newConfig = {
                $config = @(
                    @{ Name = 'A'; Version = '1.0.0' }
                    @{ Path = $script:localCommonPath }
                )
                if ($LocalFirst) {
                    [array]::Reverse($config)
                }
                , $config
            }

            $result = Register-Extensions -ExtensionsConfig (& $newConfig) -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Write
        }

        It 'Does not install the dependency, or its own dependencies' {
            Should -Invoke _getExtensionFromPSRepository -Times 0 -ParameterFilter { $Name -in 'Common', 'Shared' }
            @($result | Where-Object { $_.Name -eq 'Shared' }).Count | Should -Be 0
        }

        It 'Uses the local extension, with the process that the dependency declares' {
            $common = & $getCommon $result
            $common.Count | Should -Be 1
            $common[0].Path | Should -Be $script:localCommonPath
            $common[0].Process | Should -Be 'tasks/build.process.ps1'
        }

        It 'Does not warn' {
            Should -Invoke Write-Warning -Times 0
        }

        It 'Records the local extension, and the extension that requires it, in the lock file' {
            $lock = Get-Content -Raw (Join-Path $zfPath 'extensions.lock.json') | ConvertFrom-Json -AsHashtable
            $lock.extensions.Keys | Should -Not -Contain 'Shared'
            $lock.extensions.Common.source.type | Should -Be 'path'
            $lock.extensions.Common.direct | Should -Be $true
            $lock.extensions.Common.requiredBy | Should -Be @('A')
        }

        It 'Is satisfied by a later Frozen run' {
            $frozen = Register-Extensions -ExtensionsConfig (& $newConfig) -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Frozen

            (& $getCommon $frozen)[0].Path | Should -Be $script:localCommonPath
        }
    }

    Context 'When the local extension declares its own process' {
        It 'Keeps its own process' {
            $config = @(
                @{ Path = $script:localCommonPath; Process = 'tasks/local.process.ps1' }
                @{ Name = 'A'; Version = '1.0.0' }
            )

            $result = Register-Extensions -ExtensionsConfig $config -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Off

            (& $getCommon $result)[0].Process | Should -Be 'tasks/local.process.ps1'
        }
    }

    Context 'When the local extension does not exist' {
        It 'Installs the dependency' {
            $config = @(
                @{ Name = 'Common'; Path = (Join-Path $TestDrive 'missing') }
                @{ Name = 'A'; Version = '1.0.0' }
            )

            $result = Register-Extensions -ExtensionsConfig $config -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Off

            Should -Invoke _getExtensionFromPSRepository -Times 1 -ParameterFilter { $Name -eq 'Common' }
            $common = & $getCommon $result
            $common.Count | Should -Be 1
            $common[0].Process | Should -Be 'tasks/build.process.ps1'
        }
    }

    Context 'When the local extension is disabled' {
        It 'Installs the dependency' {
            $config = @(
                @{ Path = $script:localCommonPath; Enabled = $false }
                @{ Name = 'A'; Version = '1.0.0' }
            )

            Register-Extensions -ExtensionsConfig $config -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Off | Out-Null

            Should -Invoke _getExtensionFromPSRepository -Times 1 -ParameterFilter { $Name -eq 'Common' }
        }
    }
}
