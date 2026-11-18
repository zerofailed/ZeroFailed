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

        # An installed copy is used as it is
        $path = Join-Path $TargetPath $Name $selected
        $modulePath = Join-Path $path "$Name.psm1"
        if (!(Test-Path $modulePath)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Set-Content -Path $modulePath -Value "# $Name $selected"
        }
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

    It 'Fails a later Frozen run, before finding its tasks, when an installed copy has changed' {
        $commonPath = Join-Path $zfPath 'extensions' 'Common' '1.6.0'
        Add-Content -Path (Join-Path $commonPath 'Common.psm1') -Value 'Write-Host "changed"'
        # Record the extensions whose tasks are found from now on, as calls made by the Write run count in this scope
        $script:extensionsWithTasksFound = @()
        Mock Get-ExtensionAvailableTasks { $script:extensionsWithTasksFound += $ExtensionPath; @() }

        { Register-Extensions -ExtensionsConfig (& $newExtensionsConfig) -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Frozen } |
            Should -Throw "Extension Common (1.6.0) does not have the content recorded in the lock file. Delete '$commonPath' to re-install it."
        $script:extensionsWithTasksFound | Should -Not -Contain $commonPath
        $script:extensionsWithTasksFound | Should -Contain (Join-Path $zfPath 'extensions' 'A' '1.0.0')
    }
}

Describe 'Register-Extensions with a lock file, when the configuration chooses a version that an earlier extension does not' {

    BeforeAll {
        Mock Write-Host {}
        Mock Write-Warning {}
        Mock _getExtensionFromPSRepository { installFromFakeRepository -Name $Name -Version $Version -MinimumVersion $MinimumVersion -LockedVersion $LockedVersion -TargetPath $TargetPath }
        Mock Get-ExtensionAvailableTasks { @() }

        # 'A' requires 'Common' 1.5 or later, but the configuration chooses 'Common' 1.3.0. 'A' is listed first, so its
        # 'Common' is registered first.
        Mock Get-ExtensionDependencies { @{ A = @{ Name = 'Common'; MinimumVersion = '1.5' } }[$Extension.Name] }
        $newExtensionsConfig = {
            @(
                @{ Name = 'A'; Version = '1.0.0' }
                @{ Name = 'Common'; Version = '1.3.0' }
            )
        }
        $getCommon = { param ($extensions) $extensions | Where-Object { $_.Name -eq 'Common' } | Select-Object -First 1 }
    }

    BeforeEach {
        $originalPSModulePath = $env:PSModulePath
        $zfPath = Join-Path $TestDrive ([guid]::NewGuid())
        $script:available = @{ A = @('1.0.0'); Common = @('1.3.0', '1.6.0') }
        $script:installed = @{}

        $written = Register-Extensions -ExtensionsConfig (& $newExtensionsConfig) -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Write
    }

    AfterEach {
        $env:PSModulePath = $originalPSModulePath
    }

    It 'Writes the version that the configuration chooses to the lock file' {
        (& $getCommon $written).LockEntry.resolved | Should -Be '1.3.0'
    }

    It 'Is satisfied by a later Frozen run on the same machine' {
        $frozen = Register-Extensions -ExtensionsConfig (& $newExtensionsConfig) -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Frozen

        (& $getCommon $frozen).LockEntry.resolved | Should -Be '1.3.0'
    }

    It 'Is satisfied by a later Frozen run on a clean machine' {
        $script:installed = @{}

        $frozen = Register-Extensions -ExtensionsConfig (& $newExtensionsConfig) -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Frozen

        (& $getCommon $frozen).LockEntry.resolved | Should -Be '1.3.0'
        $script:installed.Common | Should -Be @('1.3.0')
    }
}

Describe 'Register-Extensions with a lock file, when one extension requires a git branch and another a minimum version of the same extension' {

    BeforeAll {
        Mock Write-Host {}
        Mock Write-Warning {}
        Mock Get-ExtensionAvailableTasks { @() }

        # Installs a git reference, or the newest release tag in the range of a minimum version, from a fake git
        # repository: a table of references and the commits that they point to
        function installFromFakeGitRepository {
            param ([string] $Name, [string] $GitRef, [string] $MinimumVersion, [string] $LockedCommit, [string] $TargetPath)

            $refs = $script:gitRefs[$Name]
            if ($MinimumVersion -and !$GitRef) {
                $range = _getExtensionVersionRange -MinimumVersion $MinimumVersion
                $GitRef = $refs.Keys |
                              Where-Object { $version = _getVersionFromGitTag -Ref $_; $version -and (_testExtensionVersionInRange -Version $version -Range $range) } |
                              Sort-Object { _getVersionFromGitTag -Ref $_ } -Descending |
                              Select-Object -First 1
            }
            $commit = $LockedCommit ? $LockedCommit : $refs[$GitRef]
            $script:gitInstalls += "$Name $GitRef $commit"

            $path = Join-Path $TargetPath $Name ($GitRef -replace '/', '-')
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Set-Content -Path (Join-Path $path "$Name.psm1") -Value "# $Name $commit"
            $result = @{ Path = $path; Enabled = $true; ResolvedVersion = $commit }
            if ($MinimumVersion) {
                $result.ResolvedRef = $GitRef
            }
            $result
        }
        Mock _getExtensionFromGit { installFromFakeGitRepository -Name $Name -GitRef $GitRef -MinimumVersion $MinimumVersion -LockedCommit $LockedCommit -TargetPath $TargetPath }

        # 'A' requires 'Common' from its 'main' branch, and 'B' requires 'Common' 1.0 or later. The 'Common' release that
        # 'B' requires is chosen for both of them.
        Mock Get-ExtensionDependencies {
            @{
                A = @{ Name = 'Common'; GitRepository = 'https://example.com/Common'; GitRef = 'main' }
                B = @{ Name = 'Common'; GitRepository = 'https://example.com/Common'; MinimumVersion = '1.0' }
            }[$Extension.Name]
        }
        $newExtensionsConfig = {
            @(
                @{ Name = 'A'; GitRepository = 'https://example.com/A'; GitRef = 'main' }
                @{ Name = 'B'; GitRepository = 'https://example.com/B'; GitRef = 'main' }
            )
        }
        $getCommon = { param ($extensions) $extensions | Where-Object { $_.Name -eq 'Common' } | Select-Object -First 1 }
    }

    BeforeEach {
        $originalPSModulePath = $env:PSModulePath
        $zfPath = Join-Path $TestDrive ([guid]::NewGuid())

        # 'main' is ahead of the latest release
        $script:gitRefs = @{
            A = @{ main = 'a1' }
            B = @{ main = 'b1' }
            Common = @{ main = 'common-main'; 'refs/tags/1.2.4' = 'common-1.2.4' }
        }
        $script:gitInstalls = @()

        $written = Register-Extensions -ExtensionsConfig (& $newExtensionsConfig) -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Write
    }

    AfterEach {
        $env:PSModulePath = $originalPSModulePath
    }

    It 'Writes the release that the minimum version chooses to the lock file' {
        $lockedCommon = (Get-Content -Raw (Join-Path $zfPath 'extensions.lock.json') | ConvertFrom-Json -AsHashtable).extensions.Common

        $lockedCommon.requested | Should -Be '[1.0.0,2.0.0)'
        $lockedCommon.resolved | Should -Be 'common-1.2.4'
        $lockedCommon.requiredBy | Should -Be @('A', 'B')
    }

    It 'Is satisfied by a later Frozen run on the same machine' {
        $frozen = Register-Extensions -ExtensionsConfig (& $newExtensionsConfig) -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Frozen

        (& $getCommon $frozen).LockEntry.resolved | Should -Be 'common-1.2.4'
    }

    It 'Is satisfied by a later Frozen run on a clean machine, after a newer commit on the branch, installing only the locked release' {
        Remove-Item -Recurse -Force (Join-Path $zfPath 'extensions')
        $script:gitRefs.Common.main = 'common-newer'
        $script:gitInstalls = @()

        $frozen = Register-Extensions -ExtensionsConfig (& $newExtensionsConfig) -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Frozen

        (& $getCommon $frozen).LockEntry.resolved | Should -Be 'common-1.2.4'
        $script:gitInstalls | Where-Object { $_ -like 'Common *' } | Select-Object -Unique | Should -Be @('Common refs/tags/1.2.4 common-1.2.4')
    }

    It 'Fails a later Frozen run when the configuration requires the extension from a branch' {
        $config = @(& $newExtensionsConfig) + @{ Name = 'Common'; GitRepository = 'https://example.com/Common'; GitRef = 'main' }

        { Register-Extensions -ExtensionsConfig $config -DefaultPSRepository 'PSGallery' -ZfPath $zfPath -LockMode Frozen } |
            Should -Throw "*'Common' is requested as 'main' from git 'https://example.com/Common', but the lock file has '``[1.0.0,2.0.0)' from git 'https://example.com/Common'*"
    }
}
