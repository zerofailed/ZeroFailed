# <copyright file="_removeFolderWithRetry.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest
}

Describe '_removeFolderWithRetry' {

    BeforeEach {
        $folderPath = Join-Path $TestDrive "folder-$(New-Guid)"
        New-Item -ItemType Directory -Path (Join-Path $folderPath 'child') -Force | Out-Null
        Set-Content -Path (Join-Path $folderPath 'child' 'file.txt') -Value 'content'

        Mock Start-Sleep {}
    }

    It 'Deletes the folder and its contents' {
        _removeFolderWithRetry -Path $folderPath

        $folderPath | Should -Not -Exist
        Should -Invoke Start-Sleep -Times 0
    }

    It 'Deletes the folder once a file in it is no longer in use' {
        $script:attempts = 0
        Mock Remove-Item -ParameterFilter { $Path -eq $folderPath } {
            $script:attempts++
            if ($script:attempts -le 2) {
                throw 'The file is in use'
            }
            Remove-Item -LiteralPath $folderPath -Recurse -Force
        }

        _removeFolderWithRetry -Path $folderPath

        $folderPath | Should -Not -Exist
        $script:attempts | Should -Be 3
        Should -Invoke Start-Sleep -Times 2 -Exactly
    }

    It 'Waits longer after each failed attempt, up to a limit' {
        $script:delays = [System.Collections.Generic.List[int]]::new()
        Mock Start-Sleep { $script:delays.Add($Milliseconds) }
        $script:attempts = 0
        Mock Remove-Item -ParameterFilter { $Path -eq $folderPath } {
            $script:attempts++
            if ($script:attempts -le 5) {
                throw 'The file is in use'
            }
        }

        _removeFolderWithRetry -Path $folderPath -RetryDelayMilliseconds 200

        $script:delays | Should -Be @(200, 400, 800, 1000, 1000)
    }

    It 'Throws when a file in the folder is still in use after the timeout' {
        Mock Remove-Item -ParameterFilter { $Path -eq $folderPath } { throw 'The file is in use' }

        { _removeFolderWithRetry -Path $folderPath -TimeoutSeconds 0 } |
            Should -Throw "Unable to delete '$folderPath' because a file in it is in use by another process (for example an editor or antivirus scanner): The file is in use"
        $folderPath | Should -Exist
    }
}
