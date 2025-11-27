Describe "Update-VendirConfig" {
    
    BeforeAll {
        $sut = Join-Path $PSScriptRoot "Update-VendirConfig.ps1"
        . $sut

        $testPath = "TestDrive:\.zf"
        $yamlPath = Join-Path $testPath "zf.vendir.yml"
    }

    BeforeEach {
        if (Test-Path $testPath) { Remove-Item $testPath -Recurse -Force }
        New-Item -ItemType Directory -Path $testPath | Out-Null
    }

    Context "New Configuration" {
        It "Creates the configuration files if they don't exist" {
            Update-VendirConfig -Name "TestExt" -RepositoryUri "https://repo.git" -GitRef "v1" -RepositoryFolderPath "mod" -CachePath ".zf/cache/TestExt/v1" -ZfRootPath $testPath

            Test-Path $yamlPath | Should -Be $true
        }

        It "Generates correct YAML content" {
            Update-VendirConfig -Name "TestExt" -RepositoryUri "https://repo.git" -GitRef "v1" -RepositoryFolderPath "mod" -CachePath ".zf/cache/TestExt/v1" -ZfRootPath $testPath

            $yaml = Get-Content $yamlPath -Raw | ConvertFrom-Yaml
            
            $yaml.apiVersion | Should -Be "vendir.k14s.io/v1alpha1"
            $yaml.directories.Count | Should -Be 1
            $yaml.directories[0].path | Should -Be ".zf/cache/TestExt/v1"
            $yaml.directories[0].contents[0].git.url | Should -Be "https://repo.git"
            $yaml.directories[0].contents[0].git.ref | Should -Be "v1"
            $yaml.directories[0].contents[0].includePaths | Should -Contain "mod/**/*"
        }
    }

    Context "Existing Configuration" {
        It "Adds a new extension to existing configuration" {
            Update-VendirConfig -Name "Ext1" -RepositoryUri "https://repo1.git" -GitRef "v1" -RepositoryFolderPath "mod1" -CachePath ".zf/cache/Ext1/v1" -ZfRootPath $testPath
            Update-VendirConfig -Name "Ext2" -RepositoryUri "https://repo2.git" -GitRef "v2" -RepositoryFolderPath "mod2" -CachePath ".zf/cache/Ext2/v2" -ZfRootPath $testPath

            $yaml = Get-Content $yamlPath -Raw | ConvertFrom-Yaml
            $yaml.directories.Count | Should -Be 2
            
            $yaml.directories[0].path | Should -Be ".zf/cache/Ext1/v1"
            $yaml.directories[1].path | Should -Be ".zf/cache/Ext2/v2"
        }

        It "Updates existing extension entry if path matches" {
            Update-VendirConfig -Name "Ext1" -RepositoryUri "https://repo1.git" -GitRef "v1" -RepositoryFolderPath "mod1" -CachePath ".zf/cache/Ext1/v1" -ZfRootPath $testPath
            # Update with different repo url but same path (unlikely scenario but good for testing update logic)
            Update-VendirConfig -Name "Ext1" -RepositoryUri "https://repo1-new.git" -GitRef "v1" -RepositoryFolderPath "mod1" -CachePath ".zf/cache/Ext1/v1" -ZfRootPath $testPath

            $yaml = Get-Content $yamlPath -Raw | ConvertFrom-Yaml
            $yaml.directories.Count | Should -Be 1
            $yaml.directories[0].contents[0].git.url | Should -Be "https://repo1-new.git"
        }
    }
}
