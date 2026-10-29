# <copyright file="_writeExtensionLockFile.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionLockEntries.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionContentHash.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_readExtensionLockFile.ps1')

    Set-StrictMode -Version Latest

    # Creates the metadata of a registered extension, as produced by Register-ExtensionAndDependencies
    function newRegisteredExtension([string] $Name, [string] $Resolved, [string] $RequiredBy) {
        @{
            Name = $Name
            Path = Join-Path $TestDrive $Name
            Enabled = $true
            LockEntry = [ordered]@{
                source = [ordered]@{ type = 'git'; folderPath = 'module'; repository = "https://github.com/org/$Name" }
                requested = 'main'
                resolved = $Resolved
                direct = !$RequiredBy
                requiredBy = $RequiredBy ? @($RequiredBy) : @()
            }
        }
    }

    $expectedJson = @'
{
  "lockVersion": 1,
  "extensions": {
    "Build": {
      "source": {
        "type": "git",
        "folderPath": "module",
        "repository": "https://github.com/org/Build"
      },
      "requested": "main",
      "resolved": "abc123",
      "contentHash": "sha256:fixed",
      "direct": true,
      "requiredBy": []
    },
    "Common": {
      "source": {
        "type": "git",
        "folderPath": "module",
        "repository": "https://github.com/org/Common"
      },
      "requested": "main",
      "resolved": "def456",
      "contentHash": "sha256:fixed",
      "direct": false,
      "requiredBy": [
        "Build"
      ]
    }
  }
}

'@.Replace("`r`n", "`n")
}

Describe '_writeExtensionLockFile' {

    BeforeAll {
        Mock _getExtensionContentHash { 'sha256:fixed' }
        Mock Write-Host {}
        Mock Write-Verbose {}

        $extensions = @(
            newRegisteredExtension -Name 'Build' -Resolved 'abc123'
            newRegisteredExtension -Name 'Common' -Resolved 'def456' -RequiredBy 'Build'
        )
    }

    BeforeEach {
        $lockFilePath = Join-Path $TestDrive "$(New-Guid)" 'extensions.lock.json'
    }

    Context 'When there is no lock file' {
        BeforeEach {
            _writeExtensionLockFile -Path $lockFilePath -Extensions $extensions
        }

        It 'Writes the locked extensions' {
            [IO.File]::ReadAllText($lockFilePath) | Should -BeExactly $expectedJson
        }

        It 'Uses LF line endings and no byte order mark' {
            $bytes = [IO.File]::ReadAllBytes($lockFilePath)
            $bytes | Should -Not -Contain ([byte]13)
            $bytes[0] | Should -Be ([byte][char]'{')
        }

        It 'Can be read back' {
            $result = _readExtensionLockFile -Path $lockFilePath

            @($result.Keys) | Should -Be @('Build', 'Common')
            $result['Common'].requiredBy | Should -Be @('Build')
        }
    }

    Context 'When the lock file is up to date' {
        It 'Does not write the lock file' {
            New-Item -ItemType Directory -Path (Split-Path -Parent $lockFilePath) -Force | Out-Null
            [IO.File]::WriteAllText($lockFilePath, $expectedJson)
            $lastWriteTime = (Get-Item $lockFilePath).LastWriteTimeUtc.AddMinutes(-5)
            (Get-Item $lockFilePath).LastWriteTimeUtc = $lastWriteTime

            _writeExtensionLockFile -Path $lockFilePath -Extensions $extensions

            (Get-Item $lockFilePath).LastWriteTimeUtc | Should -Be $lastWriteTime
            Should -Invoke Write-Host -Times 0 -Scope It
        }

        It 'Ignores line endings that were changed by a git checkout' {
            New-Item -ItemType Directory -Path (Split-Path -Parent $lockFilePath) -Force | Out-Null
            [IO.File]::WriteAllText($lockFilePath, $expectedJson.Replace("`n", "`r`n"))

            _writeExtensionLockFile -Path $lockFilePath -Extensions $extensions

            Should -Invoke Write-Host -Times 0 -Scope It
        }
    }

    Context 'When the lock file is out of date' {
        It 'Writes the lock file' {
            New-Item -ItemType Directory -Path (Split-Path -Parent $lockFilePath) -Force | Out-Null
            [IO.File]::WriteAllText($lockFilePath, $expectedJson.Replace('def456', 'old-commit'))

            _writeExtensionLockFile -Path $lockFilePath -Extensions $extensions

            [IO.File]::ReadAllText($lockFilePath) | Should -BeExactly $expectedJson
            Should -Invoke Write-Host -Times 1 -Scope It -ParameterFilter { $Object -like 'Updated extensions lock file*' }
        }
    }

    Context 'When there are no extensions to lock' {
        It 'Writes an empty lock file' {
            _writeExtensionLockFile -Path $lockFilePath -Extensions @()

            $result = _readExtensionLockFile -Path $lockFilePath
            $result.Count | Should -Be 0
        }
    }
}
