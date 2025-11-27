# <copyright file="Update-VendirConfig.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Update-VendirConfig {
    <#
        .SYNOPSIS
        Updates the vendir configuration file with a new extension entry.

        .DESCRIPTION
        This function adds or updates an entry in the vendir configuration file (zf.vendir.yml) for a specific extension.
        It uses powershell-yaml to read and write the configuration.

        .PARAMETER Name
        The name of the extension.

        .PARAMETER RepositoryUri
        The URI of the Git repository.

        .PARAMETER GitRef
        The Git reference (branch, tag, or commit SHA).

        .PARAMETER RepositoryFolderPath
        The folder path within the repository to include.

        .PARAMETER CachePath
        The path where vendir should download the content.

        .PARAMETER ZfRootPath
        The root path of the .zf directory where configuration files are stored.

        .EXAMPLE
        Update-VendirConfig -Name "MyExt" -RepositoryUri "https://github.com/org/repo.git" -GitRef "main" -RepositoryFolderPath "module" -CachePath ".zf/cache/MyExt/main" -ZfRootPath "C:\Project\.zf"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $RepositoryUri,

        [Parameter(Mandatory)]
        [string] $GitRef,

        [Parameter(Mandatory)]
        [string] $RepositoryFolderPath,

        [Parameter(Mandatory)]
        [string] $CachePath,

        [Parameter(Mandatory)]
        [string] $ZfRootPath
    )

    $yamlPath = Join-Path $ZfRootPath "zf.vendir.yml"

    if (Test-Path $yamlPath) {
        $config = Get-Content -Raw $yamlPath | ConvertFrom-Yaml
    }
    else {
        $config = [ordered]@{
            apiVersion = "vendir.k14s.io/v1alpha1"
            kind = "Config"
            directories = @()
        }
    }

    # Ensure directories is an array
    if ($null -eq $config.directories) {
        $config.directories = @()
    }
    if ($config.directories -isnot [array] -and $config.directories -isnot [System.Collections.IList]) {
        $config.directories = @($config.directories)
    }

    # Check if entry exists
    $existingEntry = $null
    foreach ($dir in $config.directories) {
        if ($dir.path -eq $CachePath) {
            $existingEntry = $dir
            break
        }
    }
    
    $newEntry = [ordered]@{
        path = $CachePath
        contents = @(
            [ordered]@{
                path = "."
                git = [ordered]@{
                    url = $RepositoryUri
                    ref = $GitRef
                }
                includePaths = @(
                    "$RepositoryFolderPath/**/*"
                )
            }
        )
    }

    if ($existingEntry) {
        # Update existing
        $newDirectories = @()
        foreach ($dir in $config.directories) {
            if ($dir.path -eq $CachePath) {
                $newDirectories += $newEntry
            }
            else {
                $newDirectories += $dir
            }
        }
        $config.directories = $newDirectories
    }
    else {
        # Add new
        $config.directories += $newEntry
    }

    # Save YAML
    $config | ConvertTo-Yaml -Options WithIndentedSequences | Set-Content $yamlPath
}
