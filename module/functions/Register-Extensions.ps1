# <copyright file="Register-Extensions.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Register-Extensions {
    <#
        .SYNOPSIS
        Validates and registers a set of extensions and their dependencies.
        
        .DESCRIPTION
        This function validates, installs (if necessary) and registers the specified set of ZeroFailed extensions and any dependencies
        they declare, returning a fully-populated set of metadata for all extensions.

        If an extension is considered valid and available, then it will be marked as enabled; otherwise it will be marked as disabled.
        
        .PARAMETER ExtensionsConfig
        An array of extension configuration objects.
        
        .PARAMETER DefaultRepository
        The default repository to use for extensions that do not specify a repository.
        
        .PARAMETER ZfPath
        The path to the '.zf' storage directory (e.g. where extensions will be installed).

        .INPUTS
        None. You can't pipe objects to Register-Extensions.

        .OUTPUTS
        hashtable[]
        
        Returns an array of fully-populated extension metadata.
        
        .EXAMPLE
        PS:> $extensionsConfig = @(
            @{
                Name = "PublicExtension"                            # Extension available via PS Gallery, latest stable version
            }
            @{
                Name = "PinnedPublicExtension"                      # Extension available via PS Gallery, specific version
                Version = "1.0.2"
            }
            @{
                Name = "BetaPublicExtension"                        # Extension available via PS Gallery, latest pre-release version
                PreRelease = $true
            }
            @{
                Path = "/myLocalExtension/module"
            }
            @{
                Path = "/myNonExistantExtension/module"             # Incorrect path to a local extension
            }
        )
        PS:> Register-Extensions -ExtensionsConfig $extensionsConfig -DefaultRepository PSGallery -ZfPath "/myproject/.zf"

        @(
            @{
                Name = "PublicExtension"                            # Extension available via PS Gallery, latest stable version
                Version = " 1.5.2"
                Path = "/myproject/.zf/extensions/PublicExtension/1.5.2"
                Enabled = $true
            }
            @{
                Name = "PinnedPublicExtension"                      # Extension available via PS Gallery, specific version
                Version = "1.0.2"
                Path = "/myproject/.zf/extensions/PinnedPublicExtension/1.0.2"
                Enabled = $true
            }
            @{
                Name = "BetaPublicExtension"                        # Extension available via PS Gallery, latest pre-release version
                Version = " 2.0.0-beta0010"
                Path = "/myproject/.zf/extensions/BetaPublicExtension/2.0.0"
                Enabled = $true
            }
            @{
                Name = "myLocalExtension"                           # Extension being developed locally
                Path = "/myLocalExtension/module"
                Enabled = $true
            }
            @{
                Name = "myNonExistantExtension"
                Path = "/myNonExistantExtension/module"   # Incorrect path to a local extension
                Enabled = $false
            }
        )
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable[]] $ExtensionsConfig,

        [Parameter(Mandatory=$true)]
        [string] $DefaultRepository,

        [Parameter(Mandatory=$true)]
        [string] $ZfPath
    )
    
    [hashtable[]]$processedExtensionConfig = @()

    # Extensions will be installed under the ZfPath, which by convention
    # is the '.zf' folder in the root of a project.
    $zfExtensionsPath = Join-Path $ZfPath 'extensions'
    if (!(Test-Path $zfExtensionsPath)) {
        New-Item -ItemType Directory $zfExtensionsPath | Out-Null
    }
    Write-Host "ZF Extensions Path: $zfExtensionsPath"

    # Ensure that $zfExtensionsPath is the first place we will look
    # for modules by putting it at the front of $env:PSModulePath
    [string[]]$moduleSearchPaths = $env:PSModulePath -split ";"
    if ($zfExtensionsPath -notin $moduleSearchPaths) {
        $moduleSearchPaths = ,$zfExtensionsPath + $moduleSearchPaths
    }
    elseif ($moduleSearchPaths[0] -ne $zfExtensionsPath) {
        $moduleSearchPaths = ,$zfExtensionsPath + $($moduleSearchPaths | ? {$_ -ne $zfExtensionsPath})
    }
    $env:PSModulePath = $moduleSearchPaths -join ";"

    # Process each configured extension
    for ($i=0; $i -lt $ExtensionsConfig.Length; $i++) {

        $registeredExtensions = Register-ExtensionAndDependencies -ExtensionConfig $ExtensionsConfig[$i] -TargetPath $zfExtensionsPath
        
        # Persist the fully-populated extension metadata
        $processedExtensionConfig += $registeredExtensions
    }

    return $processedExtensionConfig
}
