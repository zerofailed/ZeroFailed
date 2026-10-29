# <copyright file="_readExtensionLockFile.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

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
