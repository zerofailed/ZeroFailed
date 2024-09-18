# <copyright file="Register-Extensions.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Register-Extensions {
    <#
        .SYNOPSIS
        Validates and registers a set of extensions and their dependencies.
        
        .DESCRIPTION
        This function validates, installs (if necessary) and registers the specfied set of extensions and any dependencies they declare,
        returning a fully-populated set of metadata for all extensions.

        If an extension is considered valid and available, then it will be marked as enabled; otherwise it will be marked as disabled.
        
        .PARAMETER ExtensionsConfig
        An array of extension configuration objects.
        
        .PARAMETER DefaultRepository
        The default repository to use for extensions that do not specify a repository.
        
        .INPUTS
        None. You can't pipe objects to Register-Extensions.

        .OUTPUTS
        hashtable[]
        
        Returns an array of fully-populated extension metadata.
        
        .EXAMPLE
        PS:> $extensionsConfig = @(
            @{
                Name = "MyExtension"    # Extension available via PS Gallery
            }
            @{
                Path = "/home/<user>/code/myLocalExtension"     # Extension being developed locally
            }
            @{
                Path = "/home/<user>/code/myNonExistantExtension"     # Incorrect path to a local extension
            }
        )
        PS:> Register-Extensions -ExtensionsConfig $extensionsConfig
        @(
            @{
                Name = "MyExtension"
                Path = "/home/<user>/.local/share/powershell/Modules"
                Version = "<installed-version>"
                Enabled = $true
            }
            @{
                Name = "myLocalExtension"
                Path = "/home/<user>/code/myLocalExtension"
                Enabled = $true
            }
            @{
                Path = "/home/<user>/code/myNonExistantExtension"
                Enabled = $false
            }
        )
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [array] $ExtensionsConfig,

        [Parameter(Mandatory=$true)]
        [string] $DefaultRepository
    )
    
    [hashtable[]]$processedExtensionConfig = @()

    for ($i=0; $i -lt $ExtensionsConfig.Length; $i++) {

        $registeredExtensions = Register-ExtensionAndDependencies -ExtensionConfig $ExtensionsConfig[$i]
        
        # Persist the fully-populated extension metadata
        $processedExtensionConfig += $registeredExtensions
    }

    return $processedExtensionConfig
}
