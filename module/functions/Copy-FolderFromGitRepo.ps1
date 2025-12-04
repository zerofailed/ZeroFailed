# <copyright file="Copy-FolderFromGitRepo.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Copy-FolderFromGitRepo {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string] $RepoUrl,
        
        [Parameter(Mandatory)]
        [string] $RepoFolderPath,
        
        [Parameter(Mandatory)]
        [string] $DestinationPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $GitRef = 'main',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $GitCmd = 'git'
    )
    
    if (!(Get-Command $GitCmd -ErrorAction Ignore)) {
        throw "Git CLI is not installed. Please install Git CLI before trying to retrieve extensions from Git repositories."
    }

    # Create a temporary folder for cloning
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "$(New-Guid)"
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        Write-Verbose "Cloning repository $RepoUrl to $tempDir..."
        Push-Location $tempDir
        $PSNativeCommandUseErrorActionPreference = $true
        & $GitCmd init --quiet
        & $GitCmd fetch $RepoUrl "$($GitRef):local" --depth 1 --quiet
        & $GitCmd checkout local --quiet
        Pop-Location

        $sourcePath = [IO.Path]::GetFullPath((Join-Path -Path $tempDir -ChildPath $RepoFolderPath))
        if (!(Test-Path $sourcePath)) {
            throw "The folder '$RepoFolderPath' does not exist in the cloned repository."
        }
        
        Write-Verbose "Copying contents from $sourcePath to $DestinationPath..."
        Copy-Item -Path $sourcePath -Destination $DestinationPath -Recurse -Force   
    }
    finally {
        # Clean up the temporary folder
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
}
