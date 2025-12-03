# <copyright file="Get-ExtensionFromGitRepository.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-ExtensionFromGitRepository {
    <#
        .SYNOPSIS
        Retrieves an extension from a Git repository using the git CLI.
        
        .DESCRIPTION
        If not already available as a locally-installed module, this function installs the extension from the specified git repository.
        It also derives the additional metadata about the extension required by the tooling.
        
        .PARAMETER Name
        Specifies the name of the extension being retrieved.
        
        .PARAMETER RepositoryUri
        Specifies the Git repository URI from which to retrieve the extension.

        .PARAMETER RepositoryFolderPath
        Specifies the folder path within the repository where the extension is located. Defaults to standard ZF convention of 'module'.
        
        .PARAMETER TargetPath
        Specifies the path where the extension should be installed.

        .PARAMETER GitRef
        Specifies the version of the extension to retrieve. If not specified, the 'main' branch will be retrieved.
        
        .INPUTS
        None. You can't pipe objects to Get-ExtensionFromGitRepository.

        .OUTPUTS
        Hashtable.
        
        Returns a hashtable containing completed set of metadata for the extension. This consists of the originally supplied metadata
        plus these additional properties:
        - Path: The path to the installed extension.
        - Enabled: Indicates whether the extension is enabled.
        
        .EXAMPLE
        PS:> Get-ExtensionFromGitRepository -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -RepositoryUri "https://github.com/myorg/MyExtension.git"
        Retrieves the 'main' branch version of the "MyExtension" extension from a git repository that uses the default ZF extension folder structure.

        .EXAMPLE
        PS:> Get-ExtensionFromGitRepository -Name "MyExtension" -GitRef "refs/tags/1.0" -TargetPath "C:/MyProject/.zf" -RepositoryUri "https://github.com/myorg/MyExtension.git"
        Retrieves '1.0' tagged version of the "MyExtension" extension from a git repository that uses the default ZF extension folder structure.

        .EXAMPLE
        PS:> Get-ExtensionFromGitRepository -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -RepositoryUri "https://github.com/myorg/MyExtension.git" -RepositoryFolderPath 'modules/MyExtension'
        Retrieves the 'main' branch version of the "MyExtension" extension from a git repository that uses a custom folder structure.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [uri] $RepositoryUri,

        [Parameter()]
        [string] $RepositoryFolderPath = 'module',

        [Parameter(Mandatory)]
        [string] $TargetPath,

        [Parameter(Mandatory)]
        [string] $GitRef,

        [Parameter()]
        [bool] $UseEphemeralVendirConfig = $true
    )

    # This function uses the 'vendir' tool to download the extension from the Git repository.

    $safeGitRef = $GitRef.Replace('/', '-')
    $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails -Name $Name -TargetPath $TargetPath -GitRefAsFolderName $safeGitRef
    $zfRoot = Split-Path $TargetPath -Parent

    # Handle getting the module from the repository
    if (!$existingExtensionPath -or $existingExtensionVersion -ne $safeGitRef) {
        if (!$existingExtensionPath) {
            Write-Verbose "Extension '$Name' not found locally."
        }
        elseif ($existingExtensionVersion -ne $safeGitRef) {
            Write-Verbose "Extension '$Name' found locally but version mismatch detected. Found: '$existingExtensionVersion'; Required: '$safeGitRef' [$GitRef]"
        }
        Write-Host "Installing extension $Name from $RepositoryUri" -f Cyan
        
        # Check whether the vendir tool is available
        $vendirTool = 'vendir'
        if (!(Get-Command $vendirTool -ErrorAction SilentlyContinue)) {
            $installDir = Join-Path $zfRoot 'bin'
            New-Item -ItemType Directory -Path $installDir -Force | Out-Null

            if ($IsWindows) {
                $downloadFile = 'vendir-windows-amd64.exe'
                $vendirTool = 'vendir.exe'
            }
            elseif ($IsLinux) {
                $downloadFile = 'vendir-linux-amd64'
            }
            elseif ($IsMacOS) {
                $downloadFile = 'vendir-darwin-amd64'
            }

            $installedToolPath = Join-Path $installDir $vendirTool
            if (!(Get-Command $installedToolPath -ErrorAction Ignore)) {
                # Construct the required URL to the relevant release URL
                $releaseUrl = 'https://github.com/carvel-dev/vendir/releases/download'
                $releaseVersion = 'v0.45.0'
                Invoke-RestMethod -Uri "$releaseUrl/$releaseVersion/$downloadFile" -OutFile $installedToolPath
                if (!$IsWindows) {
                    # Make executable
                    & chmod +x $installedToolPath
                }
            }
            $vendirTool = $installedToolPath
        }

        $cacheDir = Join-Path $zfRoot '.cache'
        # Currently we treat the generated vendir config files as ephemeral and extension-specific
        $vendirConfigPath = Join-Path $cacheDir "zf.$Name.vendir.yml"

        Update-VendirConfig `
            -Name $Name `
            -RepositoryUri $RepositoryUri `
            -GitRef $GitRef `
            -RepositoryFolderPath $RepositoryFolderPath `
            -ConfigPath $vendirConfigPath `
            -TargetPath (Join-Path $TargetPath $Name $safeGitRef)
        
        Write-Verbose "Running vendir sync with config: $vendirConfigPath"
        Get-Content $vendirConfigPath | Write-Verbose
        try {
            # Run vendir and capture/handle any errors
            $PSNativeCommandUseErrorActionPreference = $true
            Invoke-Command { & $vendirTool sync -f $vendirConfigPath --chdir $cacheDir } -ErrorVariable vendirErrors -ErrorAction Stop | Write-Verbose
        }
        catch {
            throw "Error whilst trying to run vendir: $($_.Exception.Message) [ExitCode=$LASTEXITCODE]`n$vendirErrors"
        }

        if ($UseEphemeralVendirConfig) {
            Remove-Item $vendirConfigPath -Force
        }

        $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails -Name $Name -TargetPath $TargetPath -GitRefAsFolderName $safeGitRef
        if (!$existingExtensionPath) {
            throw "Failed to install extension $Name ($GitRef) from $RepositoryUri repository"
        }
        Write-Host "INSTALLED MODULE: $Name ($existingExtensionVersion)" -f Cyan
    }
    else {
        Write-Host "FOUND MODULE: $Name ($existingExtensionVersion)" -f Cyan
    }

    # Return the additional extension metadata that this function has populated
    $additionalMetadata = @{
        Path = $existingExtensionPath
        Enabled = $true
        Version = $GitRef
    }

    return $additionalMetadata
}