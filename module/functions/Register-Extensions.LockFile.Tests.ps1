# <copyright file="Register-Extensions.LockFile.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Runs the extension registration and the lock file together, with a fake PowerShell repository, to check that a lock
# file written in 'Write' mode is satisfied by a later run in 'Frozen' mode.

BeforeAll {
    # sut, and every in-module dependency
    foreach ($functionFile in (Get-ChildItem -Path (Split-Path -Parent $PSCommandPath) -Filter '*.ps1' | Where-Object { $_.Name -notlike '*.Tests.ps1' })) {
        . $functionFile.FullName
    }

    Set-StrictMode -Version Latest

    # Installs the newest version that is available, and in the range of a minimum version, unless one is already installed
    function installFromFakeRepository {
        param ([string] $Name, [string] $Version, [string] $MinimumVersion, [string] $LockedVersion, [string] $TargetPath)

        $range = $MinimumVersion ? (_getExtensionVersionRange -MinimumVersion $MinimumVersion) : $null
        $isRequested = { param ($v) $range ? (_testExtensionVersionInRange -Version ([semver]$v) -Range $range) : (!$Version -or $v -eq $Version) }
        $newest = { param ($versions) $versions | Where-Object { $_ -and (& $isRequested $_) } | Sort-Object { [semver]$_ } -Descending | Select-Object -First 1 }

        $selected = $LockedVersion
        if (!$selected) {
            $selected = & $newest $script:installed[$Name]
        }
        if (!$selected) {
            $selected = & $newest $script:available[$Name]
        }
        if ($selected -notin $script:installed[$Name]) {
            $script:installed[$Name] = @($script:installed[$Name]) + $selected | Where-Object { $_ }
        }

        $path = Join-Path $TargetPath $Name $selected
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content -Path (Join-Path $path "$Name.psm1") -Value "# $Name $selected"
        @{ Path = $path; Enabled = $true; ResolvedVersion = $selected }
    }
}

Describe 'Register-Extensions with a lock file' {

    BeforeAll {
        Mock Write-Host {}
        Mock Write-Warning {}
        Mock _getExtensionFromPSRepository { installFromFakeRepository -Name $Name -Version $Version -MinimumVersion $MinimumVersion -LockedVersion $LockedVersion -TargetPath $TargetPath }
        Mock Get-ExtensionAvailableTasks { @() }

        # 'A' and 'B' both require 'Common', with different minimum versions
        Mock Get-ExtensionDependencies { @{ A = @{ Name = 'Common'; MinimumVersion = '1.2' }; B = @{ Name = 'Common'; MinimumVersion = '1.5' } }[$Extension.Name] }

        # Registration adds to the configuration, so each run starts from a new copy
        $newExtensionsConfig = {
            @(
                @{ Name = 'A'; Version = '1.0.0' }
                @{ Name = 'B'; Version = '1.0.0' }
            )
        }
        $getCommon = { param ($extensions) $extensions | Where-Object { $_.Name -eq 'Common' } | Select-Object -First 1 }
    }

    BeforeEach {
        $originalPSModulePath = $env:PSModulePath
        $zfPath = Join-Path $TestDrive ([guid]::NewGuid())

        # 'Common' 1.3.0 is installed, which meets "1.2 or later" but not "1.5 or later"
        $script:available = @{ A = @('1.0.0'); B = @('1.0.0'); Common = @('1.3.0', '1.6.0') }
        $script:installed = @{ Common = @('1.3.0') }

        $written = Register-Extensions -ExtensionsConfig (& $newExtensionsConfig) -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Write
    }

    AfterEach {
        $env:PSModulePath = $originalPSModulePath
    }

    It 'Writes the newest version that every extension requires to the lock file' {
        (& $getCommon $written).LockEntry.resolved | Should -Be '1.6.0'
        (Get-Content -Raw (Join-Path $zfPath 'extensions.lock.json') | ConvertFrom-Json -AsHashtable).extensions.Common.resolved | Should -Be '1.6.0'
    }

    It 'Is satisfied by a later Frozen run on the same machine' {
        $frozen = Register-Extensions -ExtensionsConfig (& $newExtensionsConfig) -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Frozen

        (& $getCommon $frozen).LockEntry.resolved | Should -Be '1.6.0'
    }

    It 'Is satisfied by a later Frozen run on a clean machine, after a newer release' {
        $script:installed = @{}
        $script:available.Common += '1.7.0'

        $frozen = Register-Extensions -ExtensionsConfig (& $newExtensionsConfig) -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Frozen

        (& $getCommon $frozen).LockEntry.resolved | Should -Be '1.6.0'
        $script:installed.Common | Should -Be @('1.6.0')
    }
}
