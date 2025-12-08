# <copyright file="Update-VendirConfig.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Update-VendirConfig {
    [CmdletBinding()]
    [OutputType([void])]
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
        [string] $ConfigPath,

        [Parameter(Mandatory)]
        [string] $TargetPath
    )

    New-Item -ItemType Directory -Path (Split-Path -Parent $ConfigPath) -Force | Out-Null

    if (Test-Path $ConfigPath) {
        $config = Get-Content -Raw $ConfigPath | ConvertFrom-Yaml
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

    # Derive target path relative to the config path
    # vendir is invoked with --chdir to the config directory, so paths must be relative to that location
    $configDir = Split-Path -Parent $ConfigPath
    
    # Resolve paths with GetFullPath for paths that may not exist yet, avoiding Resolve-Path errors
    $resolvedConfigDir = [System.IO.Path]::GetFullPath($configDir)
    $resolvedTargetPath = [System.IO.Path]::GetFullPath($TargetPath)
    
    # Calculate relative path from config directory to target path
    $relativePath = [System.IO.Path]::GetRelativePath($resolvedConfigDir, $resolvedTargetPath)

    # Check if entry exists
    $existingEntry = $null
    foreach ($dir in $config.directories) {
        if ($dir.path -eq $relativePath) {
            $existingEntry = $dir
            break
        }
    }
    
    $newEntry = [ordered]@{
        path = $relativePath
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
                newRootPath = $RepositoryFolderPath
            }
        )
    }

    if ($existingEntry) {
        # Update existing
        $newDirectories = @()
        foreach ($dir in $config.directories) {
            if ($dir.path -eq $relativePath) {
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
    $config | ConvertTo-Yaml -Options WithIndentedSequences | Set-Content $ConfigPath
}
