Describe "Update-VendirConfig" {
    
    BeforeAll {
        $sut = Join-Path $PSScriptRoot "Update-VendirConfig.ps1"
        . $sut

        $testPath = "TestDrive:\.zf"
        $configPath = Join-Path $testPath "zf.vendir.json"
        $yamlPath = Join-Path $testPath "zf.vendir.yml"
    }

    BeforeEach {
        if (Test-Path $testPath) { Remove-Item $testPath -Recurse -Force }
        New-Item -ItemType Directory -Path $testPath | Out-Null
    }

    Context "New Configuration" {
        It "Creates the configuration files if they don't exist" {
            Update-VendirConfig -Name "TestExt" -RepositoryUri "https://repo.git" -GitRef "v1" -RepositoryFolderPath "mod" -CachePath ".zf/cache/TestExt/v1" -ZfRootPath $testPath

            Test-Path $configPath | Should -Be $true
            Test-Path $yamlPath | Should -Be $true
        }

        It "Generates correct YAML content" {
            Update-VendirConfig -Name "TestExt" -RepositoryUri "https://repo.git" -GitRef "v1" -RepositoryFolderPath "mod" -CachePath ".zf/cache/TestExt/v1" -ZfRootPath $testPath

            $content = Get-Content $yamlPath -Raw
            $content | Should -Match "apiVersion: vendir.k14s.io/v1alpha1"
            $content | Should -Match "path: .zf/cache/TestExt/v1"
            $content | Should -Match "url: https://repo.git"
            $content | Should -Match "ref: v1"
            $content | Should -Match "includePaths:"
            $content | Should -Match "- mod/\*\*/\*"
        }
    }

    Context "Existing Configuration" {
        It "Adds a new extension to existing configuration" {
            Update-VendirConfig -Name "Ext1" -RepositoryUri "https://repo1.git" -GitRef "v1" -RepositoryFolderPath "mod1" -CachePath ".zf/cache/Ext1/v1" -ZfRootPath $testPath
            Update-VendirConfig -Name "Ext2" -RepositoryUri "https://repo2.git" -GitRef "v2" -RepositoryFolderPath "mod2" -CachePath ".zf/cache/Ext2/v2" -ZfRootPath $testPath

            $json = Get-Content $configPath | ConvertFrom-Json
            $json.directories.Count | Should -Be 2
            
            $content = Get-Content $yamlPath -Raw
            $content | Should -Match "path: .zf/cache/Ext1/v1"
            $content | Should -Match "path: .zf/cache/Ext2/v2"
        }

        It "Updates existing extension entry if path matches" {
            Update-VendirConfig -Name "Ext1" -RepositoryUri "https://repo1.git" -GitRef "v1" -RepositoryFolderPath "mod1" -CachePath ".zf/cache/Ext1/v1" -ZfRootPath $testPath
            # Update with different repo url but same path (unlikely scenario but good for testing update logic)
            Update-VendirConfig -Name "Ext1" -RepositoryUri "https://repo1-new.git" -GitRef "v1" -RepositoryFolderPath "mod1" -CachePath ".zf/cache/Ext1/v1" -ZfRootPath $testPath

            $json = Get-Content $configPath | ConvertFrom-Json
            $json.directories.Count | Should -Be 1
            $json.directories[0].contents[0].git.url | Should -Be "https://repo1-new.git"

            $content = Get-Content $yamlPath -Raw
            $content | Should -Match "url: https://repo1-new.git"
        }
    }
}
