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
        
        .PARAMETER Repository
        Specifies the Git repository URI from which to retrieve the extension.

        .PARAMETER SourceRepoFolderPath
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
        PS:> Get-ExtensionFromGitRepository -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -Repository "https://github.com/myorg/MyExtension.git"
        Retrieves the 'main' branch version of the "MyExtension" extension from a git repository that uses the default ZF extension folder structure.

        .EXAMPLE
        PS:> Get-ExtensionFromGitRepository -Name "MyExtension" -GitRef "refs/tags/1.0" -TargetPath "C:/MyProject/.zf" -Repository "https://github.com/myorg/MyExtension.git"
        Retrieves '1.0' tagged version of the "MyExtension" extension from a git repository that uses the default ZF extension folder structure.

        .EXAMPLE
        PS:> Get-ExtensionFromGitRepository -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -Repository "https://github.com/myorg/MyExtension.git" -SourceRepoFolderPath 'modules/MyExtension'
        Retrieves the 'main' branch version of the "MyExtension" extension from a git repository that uses a custom folder structure.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [uri] $Repository,

        [Parameter()]
        [string] $SourceRepoFolderPath = 'module',

        [Parameter(Mandatory=$true)]
        [string] $TargetPath,

        [Parameter()]
        [string] $GitRef = 'main'
    )

    # Potential approaches:
    # - clone the repo into the target path, checkout the required version - would need to handle pulls/updates
    #   - would sub-module be any easier?
    #   - only really interested in the module folder, not the whole repo
    # - clone into a temporary folder, checkout the required version, copy the module into the target path
    # - how to handle updates since the ref could be the same (i.e. branch name), but the content could have changed
    #   - have an 'always pull' option?

    # Check whether module is already installed
    # TODO: Should we retain the same module-based folder structure as with PowerShell modules?
    #       If so, will it even work given that the equivalent of module version will be the git ref?
    $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails -Name $Name -TargetPath $TargetPath -Version $GitRef

    # Handle getting the module from the repository
    if (!$existingExtensionPath -or $existingExtensionVersion -ne $GitRef) {
        if (!$existingExtensionPath) {
            Write-Verbose "Extension '$Name' not found locally."
        }
        elseif ($existingExtensionVersion -ne $GitRef) {
            Write-Verbose "Extension '$Name' found locally but version mismatch detected. Found: '$existingExtensionVersion'; Required: '$GitRef'"
        }
        
        Write-Host "Installing extension $Name from $Repository" -f Cyan
        $safeGitRef = $GitRef.Replace('/', '-')
        Copy-FolderFromGitRepo `
                -RepoUrl $Repository `
                -DestinationPath (Join-Path $TargetPath $Name $safeGitRef) `
                -RepoFolderPath $SourceRepoFolderPath `
                -GitRef $gitRef `
                -ErrorAction Continue       # Log the errors but we'll use the logic below to handle them

        $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails -Name $Name -TargetPath $TargetPath -GitRefAsFolderName $safeGitRef
        if (!$existingExtensionPath) {
            throw "Failed to install extension $Name ($GitRef) from $Repository repository"
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
    }

    return $additionalMetadata
}