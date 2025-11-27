# <copyright file="Update-VendirConfig.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Update-VendirConfig {
    <#
        .SYNOPSIS
        Updates the vendir configuration file with a new extension entry.

        .DESCRIPTION
        This function adds or updates an entry in the vendir configuration file (zf.vendir.yml) for a specific extension.
        It maintains a JSON version of the configuration for easier programmatic manipulation and generates the YAML version for vendir.

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

    $configPath = Join-Path $ZfRootPath "zf.vendir.json"
    $yamlPath = Join-Path $ZfRootPath "zf.vendir.yml"

    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
    }
    else {
        $config = [PSCustomObject]@{
            apiVersion = "vendir.k14s.io/v1alpha1"
            kind = "Config"
            directories = @()
        }
    }

    # Ensure directories is an array (in case of single item from JSON or empty)
    if ($null -eq $config.directories) {
        $config | Add-Member -MemberType NoteProperty -Name "directories" -Value @()
    }
    if ($config.directories -isnot [array]) {
        $config.directories = @($config.directories)
    }

    # Check if entry exists
    $existingEntry = $config.directories | Where-Object { $_.path -eq $CachePath } | Select-Object -First 1
    
    $newEntry = [PSCustomObject]@{
        path = $CachePath
        contents = @(
            [PSCustomObject]@{
                path = "."
                git = [PSCustomObject]@{
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
        # Since we can't easily replace in the array by reference if it's a copy, 
        # we'll rebuild the array or find index.
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

    # Save JSON
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath

    # Generate YAML
    $sb = [System.Text.StringBuilder]::new()
    $sb.AppendLine("apiVersion: vendir.k14s.io/v1alpha1") | Out-Null
    $sb.AppendLine("kind: Config") | Out-Null
    $sb.AppendLine("directories:") | Out-Null
    
    foreach ($dir in $config.directories) {
        $sb.AppendLine("- path: $($dir.path)") | Out-Null
        $sb.AppendLine("  contents:") | Out-Null
        foreach ($content in $dir.contents) {
            $sb.AppendLine("  - path: $($content.path)") | Out-Null
            $sb.AppendLine("    git:") | Out-Null
            $sb.AppendLine("      url: $($content.git.url)") | Out-Null
            $sb.AppendLine("      ref: $($content.git.ref)") | Out-Null
            if ($content.includePaths) {
                $sb.AppendLine("    includePaths:") | Out-Null
                foreach ($inc in $content.includePaths) {
                    $sb.AppendLine("    - $inc") | Out-Null
                }
            }
        }
    }
    
    $sb.ToString() | Set-Content $yamlPath
}
