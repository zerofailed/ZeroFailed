# <copyright file="endjin-devops.module.tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
Describe "'endjin-devops' Module Tests" {

    Context 'Module Setup' {
        It "has the root module endjin-devops.psm1" {
            "$PSScriptRoot/endjin-devops.psm1" | Should -Exist
        }

        It "has the a manifest file of endjin-devops.psd1" {
            "$PSScriptRoot/endjin-devops.psd1" | Should -Exist
            "$PSScriptRoot/endjin-devops.psd1" | Should -FileContentMatch "endjin-devops.psm1"
        }
    
        It "endjin-devops folder has functions folder" {
            "$PSScriptRoot/functions" | Should -Exist
        }

        It "endjin-devops is valid PowerShell code" {
            $psFile = Get-Content -Path "$PSScriptRoot/endjin-devops.psm1" -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }

    }

    BeforeDiscovery {
        Write-Host "PSScriptRoot: $PSScriptRoot" -f Magenta
        $functions = Get-ChildItem -Recurse $PSScriptRoot/functions -Include *.ps1 |
                        Where-Object { $_ -notmatch ".Tests.ps1" } 
    }
    
    Context "Test Function <_>" -ForEach $functions {
        
        BeforeAll {
            $function = $_.Name
            $functionPath = $_.FullName
            $functionDir = $_.Directory.FullName
        }
        
        It "<function> should exist" {
            $functionPath | Should -Exist
        }

        It "<function> should have a copyright block" {
            $functionPath | Should -FileContentMatch 'Copyright \(c\) Endjin Limited'
        }

        It "<function> should have help block" {
            $functionPath | Should -FileContentMatch '<#'
            $functionPath | Should -FileContentMatch '#>'
        }

        It "<function> should have a SYNOPSIS section in the help block" {
            $functionPath | Should -FileContentMatch '.SYNOPSIS'
        }

        It "<function> should have a DESCRIPTION section in the help block" {
            $functionPath | Should -FileContentMatch '.DESCRIPTION'
        }

        It "<function> should have a EXAMPLE section in the help block" {
          $functionPath | Should -FileContentMatch '.EXAMPLE'
        }

        It "<function> should be an advanced function" {
            $functionPath | Should -FileContentMatch 'function'
            $functionContent = Get-Content -raw $functionPath
            if ($functionContent -notmatch '#SUPPRESS-ParameterChecks') {
                $functionPath | Should -FileContentMatch 'cmdletbinding'
                $functionPath | Should -FileContentMatch 'param'
            }
        }
    
        It "<function> is valid PowerShell code" {
            $psFile = Get-Content -Path $functionPath -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }

        # Context "$function has tests" {
        #   It "$($function).Tests.ps1 should exist" {
        #     "$functionDir/$($function).Tests.ps1" | Should -Exist
        #   }
        # }
    }
}