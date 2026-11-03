# <copyright file="_copyFolderFromGitRepo.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _copyFolderFromGitRepo {
    [CmdletBinding()]
    [OutputType([string])]
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
        [string] $Commit,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $GitCmd = 'git'
    )

    if (!(Get-Command $GitCmd -ErrorAction Ignore)) {
        throw "Git CLI is not installed. Please install Git CLI before trying to retrieve extensions from Git repositories."
    }

    # Override any line-ending settings in the user's git configuration, so that the checked-out files
    # are the same on every machine and their content hashes are reproducible.
    $gitConfigArgs = @(
        '-c', 'core.autocrlf=false'
        '-c', 'core.eol=lf'
        '-c', 'init.defaultBranch=main'
        '-c', 'advice.detachedHead=false'
    )

    # Runs a git command in the temporary repository, logging its output and failing with
    # the command's output when it returns a non-zero exit code.
    $invokeGit = {
        $PSNativeCommandUseErrorActionPreference = $false
        $output = & $GitCmd @gitConfigArgs -C $tempDir @args 2>&1
        $exitCode = $LASTEXITCODE
        $output | ForEach-Object { Write-Verbose "git: $_" }
        if ($exitCode -ne 0) {
            throw "git $($args -join ' ') failed with exit code $exitCode`n$($output -join "`n")"
        }
        $output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
    }

    # Create a temporary folder for cloning
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "$(New-Guid)"
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        & $invokeGit init --quiet | Out-Null

        if ($Commit) {
            Write-Verbose "Fetching commit $Commit ($GitRef) from $RepoUrl..."
            try {
                & $invokeGit fetch --depth 1 --quiet $RepoUrl $Commit | Out-Null
            }
            catch {
                # Some git servers do not allow a specific commit to be fetched, so fallback to fetching
                # the full history of the ref and finding the commit in that.
                Write-Verbose "Unable to fetch commit $Commit directly, fetching the history of '$GitRef' instead"
                & $invokeGit fetch --quiet $RepoUrl $GitRef | Out-Null
            }
            & $invokeGit checkout --quiet $Commit | Out-Null
        }
        else {
            Write-Verbose "Fetching '$GitRef' from $RepoUrl..."
            & $invokeGit fetch --depth 1 --quiet $RepoUrl $GitRef | Out-Null
            & $invokeGit checkout --quiet FETCH_HEAD | Out-Null
        }
        [string]$resolvedCommit = (& $invokeGit rev-parse HEAD | Select-Object -First 1).ToString().Trim()

        $sourcePath = [IO.Path]::GetFullPath((Join-Path -Path $tempDir -ChildPath $RepoFolderPath))
        if (!(Test-Path $sourcePath -PathType Container)) {
            throw "The folder '$RepoFolderPath' does not exist in the cloned repository."
        }

        # Replace any existing copy, rather than copying the folder inside it
        if (Test-Path $DestinationPath) {
            Remove-Item -Path $DestinationPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $DestinationPath) -Force | Out-Null

        Write-Verbose "Copying contents from $sourcePath to $DestinationPath..."
        Copy-Item -Path $sourcePath -Destination $DestinationPath -Recurse -Force

        # The repository metadata is only copied when the whole repository is the extension, and it is not needed
        Remove-Item -Path (Join-Path $DestinationPath '.git') -Recurse -Force -ErrorAction Ignore

        return $resolvedCommit
    }
    finally {
        # Clean up the temporary folder
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
}
