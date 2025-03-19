function Copy-FolderFromGitRepo {
    [CmdletBinding()]
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
    $tempDir = New-TemporaryDirectory

    try {
        Write-Verbose "Cloning repository $RepoUrl to $tempDir..."
        & $GitCmd clone --quiet --single-branch --depth 1 -b $GitRef $RepoUrl $tempDir
        if ($LASTEXITCODE -ne 0) {
            throw "Git clone failed. Verify repository URL and network connectivity."
        }

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
