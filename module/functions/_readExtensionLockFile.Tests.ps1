# <copyright file="_readExtensionLockFile.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionLockPath.ps1')

    Set-StrictMode -Version Latest

    Mock Write-Verbose {}
}

Describe '_readExtensionLockFile' {

    BeforeEach {
        $lockFilePath = Join-Path $TestDrive "$(New-Guid).json"
    }

    It 'Returns nothing when the lock file does not exist' {
        $result = _readExtensionLockFile -Path $lockFilePath

        $result | Should -BeNullOrEmpty
    }

    Context 'A valid lock file' {
        BeforeEach {
            Set-Content -Path $lockFilePath -Value @'
{
  "lockVersion": 1,
  "extensions": {
    "ZeroFailed.Build.Common": {
      "source": { "type": "git", "folderPath": "module", "repository": "https://github.com/zerofailed/ZeroFailed.Build.Common" },
      "requested": "main",
      "resolved": "abc123",
      "contentHash": "sha256:def456",
      "direct": false,
      "requiredBy": [ "ZeroFailed.Build.DotNet" ]
    },
    "ZeroFailed.Build.DotNet": {
      "source": { "type": "psrepository", "preRelease": false, "repository": "PSGallery" },
      "requested": null,
      "resolved": "1.2.3",
      "contentHash": "sha256:789abc",
      "direct": true,
      "requiredBy": []
    }
  }
}
'@
            $result = _readExtensionLockFile -Path $lockFilePath
        }

        It 'Returns the locked extensions, keyed by name' {
            @($result.Keys) | Should -Be @('ZeroFailed.Build.Common', 'ZeroFailed.Build.DotNet')
            $result['ZeroFailed.Build.Common'].resolved | Should -Be 'abc123'
            $result['ZeroFailed.Build.Common'].source.repository | Should -Be 'https://github.com/zerofailed/ZeroFailed.Build.Common'
            $result['ZeroFailed.Build.DotNet'].requested | Should -BeNullOrEmpty
        }

        It 'Looks up extension names without regard to case' {
            $result['zerofailed.build.common'].resolved | Should -Be 'abc123'
        }
    }

    It 'Returns no extensions when the lock file has none' {
        Set-Content -Path $lockFilePath -Value '{ "lockVersion": 1, "extensions": {} }'

        $result = _readExtensionLockFile -Path $lockFilePath

        $result | Should -Not -BeNullOrEmpty -Because 'an empty lock file is not the same as a missing one'
        $result.Count | Should -Be 0
    }

    It 'Throws when an extension from a <Type> repository has no content hash' -ForEach @(
        @{ Type = 'git'; Source = '{ "type": "git", "folderPath": "module", "repository": "https://github.com/zerofailed/ZeroFailed.Build.Common" }' }
        @{ Type = 'PowerShell'; Source = '{ "type": "psrepository", "preRelease": false, "repository": "PSGallery" }' }
    ) {
        Set-Content -Path $lockFilePath -Value @"
{
  "lockVersion": 1,
  "extensions": {
    "ZeroFailed.Build.Common": { "source": $Source, "requested": null, "resolved": "abc123", "direct": true, "requiredBy": [] }
  }
}
"@

        { _readExtensionLockFile -Path $lockFilePath } |
            Should -Throw "The extensions lock file '$lockFilePath' has no content hash for: ZeroFailed.Build.Common. Run with the lock mode set to 'Write' to record it."
    }

    It 'Does not require a content hash for a local extension' {
        Set-Content -Path $lockFilePath -Value @'
{
  "lockVersion": 1,
  "extensions": {
    "MyExtension": { "source": { "type": "path", "path": "../MyExtension/module" }, "requested": null, "resolved": null, "direct": true, "requiredBy": [] }
  }
}
'@

        $result = _readExtensionLockFile -Path $lockFilePath

        $result['MyExtension'].source.type | Should -Be 'path'
        $result['MyExtension'].source.path | Should -Be '../MyExtension/module'
    }

    It 'Makes the full path of a local extension relative to the lock file folder, as recorded by ZeroFailed 2.0.0' {
        $extensionPath = (Join-Path $TestDrive 'MyExtension' 'module') | ConvertTo-Json
        Set-Content -Path $lockFilePath -Value @"
{
  "lockVersion": 1,
  "extensions": {
    "MyExtension": { "source": { "type": "path", "path": $extensionPath }, "requested": null, "resolved": null, "direct": true, "requiredBy": [] }
  }
}
"@

        $result = _readExtensionLockFile -Path $lockFilePath

        $result['MyExtension'].source.path | Should -Be 'MyExtension/module'
    }

    It 'Makes a PowerShell drive path of a local extension relative to the lock file folder, as recorded by ZeroFailed 2.0.0' {
        Set-Content -Path $lockFilePath -Value @'
{
  "lockVersion": 1,
  "extensions": {
    "MyExtension": { "source": { "type": "path", "path": "TestDrive:/MyExtension/module" }, "requested": null, "resolved": null, "direct": true, "requiredBy": [] }
  }
}
'@

        $result = _readExtensionLockFile -Path $lockFilePath

        $result['MyExtension'].source.path | Should -Be 'MyExtension/module'
    }

    It 'Keeps the full path of a local extension on a drive that does not exist, so that it is reported as a difference' {
        Set-Content -Path $lockFilePath -Value @'
{
  "lockVersion": 1,
  "extensions": {
    "MyExtension": { "source": { "type": "path", "path": "NoSuchDrive:/MyExtension/module" }, "requested": null, "resolved": null, "direct": true, "requiredBy": [] }
  }
}
'@

        $result = _readExtensionLockFile -Path $lockFilePath

        $result['MyExtension'].source.path | Should -Be 'NoSuchDrive:/MyExtension/module'
    }

    It 'Throws when the lock file is not valid JSON' {
        Set-Content -Path $lockFilePath -Value '{ not json'

        { _readExtensionLockFile -Path $lockFilePath } | Should -Throw "*is not valid JSON*"
    }

    It 'Throws when the lock file has <Description>' -ForEach @(
        @{ Description = 'an unsupported version'; Content = '{ "lockVersion": 2, "extensions": {} }' }
        @{ Description = 'no version'; Content = '{ "extensions": {} }' }
        @{ Description = 'an invalid list of extensions'; Content = '{ "lockVersion": 1, "extensions": [] }' }
        @{ Description = 'an unexpected structure'; Content = '[]' }
    ) {
        Set-Content -Path $lockFilePath -Value $Content

        { _readExtensionLockFile -Path $lockFilePath } | Should -Throw "*is not in a supported format*"
    }
}
