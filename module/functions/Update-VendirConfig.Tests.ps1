Describe "Update-VendirConfig" {
    
    BeforeAll {
        $sut = Join-Path $PSScriptRoot "Update-VendirConfig.ps1"
        . $sut

        $testPath = "TestDrive:\.zf"
        $extensionsBasePath = Join-Path $testPath 'extensions'
        $cachePath = Join-Path $testPath '.cache'

        Set-StrictMode -Version Latest
    }

    Context "Single Extension" {
        BeforeAll {
            $configPath = Join-Path $cachePath "zf.vendir.yml"
            $targetPath = Join-Path $extensionsBasePath 'TestExt' 'v1'

            Update-VendirConfig -Name 'TestExt' -RepositoryUri "https://repo.git" -GitRef 'v1' -RepositoryFolderPath "module" -ConfigPath $configPath -TargetPath $targetPath
        }
        AfterAll {
            Remove-Item $configPath
        }

        It "Creates the configuration file" {            
            Test-Path $configPath | Should -Be $true
        }

        It "Generates correct YAML content" {
            $yaml = Get-Content $configPath -Raw | ConvertFrom-Yaml
            
            $yaml.apiVersion | Should -Be "vendir.k14s.io/v1alpha1"
            $yaml.directories.Count | Should -Be 1
            $yaml.directories[0].path | Should -Be ("..{0}extensions{0}TestExt{0}v1" -f [IO.Path]::DirectorySeparatorChar)
            $yaml.directories[0].contents[0].git.url | Should -Be "https://repo.git"
            $yaml.directories[0].contents[0].git.ref | Should -Be 'v1'
            $yaml.directories[0].contents[0].includePaths | Should -Contain "module/**/*"
        }
    }

    Context "Existing Configuration" {
        BeforeAll {
            $configPath = Join-Path $cachePath "zf.vendir.yml"
            $targetPath1 = Join-Path $extensionsBasePath 'Ext1' 'v1'
            $targetPath2 = Join-Path $extensionsBasePath 'Ext2' 'v2'
        }
        AfterEach {
            Remove-Item $configPath
        }

        It "Adds a new extension to existing configuration" {
            Update-VendirConfig -Name "Ext1" -RepositoryUri "https://repo1.git" -GitRef "v1" -RepositoryFolderPath "mod1" -ConfigPath $configPath -TargetPath $targetPath1
            Update-VendirConfig -Name "Ext2" -RepositoryUri "https://repo2.git" -GitRef "v2" -RepositoryFolderPath "mod2" -ConfigPath $configPath -TargetPath $targetPath2

            $yaml = Get-Content $configPath -Raw | ConvertFrom-Yaml
            $yaml.directories.Count | Should -Be 2
            
            $yaml.directories[0].path | Should -Be ("..{0}extensions{0}Ext1{0}v1" -f [IO.Path]::DirectorySeparatorChar)
            $yaml.directories[1].path | Should -Be ("..{0}extensions{0}Ext2{0}v2" -f [IO.Path]::DirectorySeparatorChar)
        }

        It "Updates existing extension entry if path matches" {
            Update-VendirConfig -Name "Ext1" -RepositoryUri "https://repo1.git" -GitRef "v1" -RepositoryFolderPath "mod1" -ConfigPath $configPath -TargetPath $targetPath1
            # Update with different repo url but same path (unlikely scenario but good for testing update logic)
            Update-VendirConfig -Name "Ext1" -RepositoryUri "https://repo1-new.git" -GitRef "v1" -RepositoryFolderPath "mod1" -ConfigPath $configPath -TargetPath $targetPath1

            $yaml = Get-Content $configPath -Raw | ConvertFrom-Yaml
            $yaml.directories.Count | Should -Be 1
            $yaml.directories[0].contents[0].git.url | Should -Be "https://repo1-new.git"
        }
    }
}
