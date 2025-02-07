# <copyright file="Register-ExtensionAndDependencies.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Register-ExtensionAndDependencies {
    <#
        .SYNOPSIS
        Registers an extension and its dependencies.
        
        .DESCRIPTION
        A recursive function responsible for registering the specified extension and its dependencies.
        
        .PARAMETER ExtensionConfig
        A hashtable containing the initial extension metadata provided by the user. This parameter is mandatory.

        .PARAMETER TargetPath
        The path to the folder where ZeroFailed extensions are installed (typically '.zf/extensions'). This parameter is mandatory.
        
        .INPUTS
        None. You can't pipe objects to Register-ExtensionAndDependencies.

        .OUTPUTS
        The function returns an array of hashtables representing the processed extension metadata for the input extension and its dependencies.
        
        .EXAMPLE
        PS:> $extensionConfig = @{
            Name = "MyExtension"
            Path = "C:\Extensions\MyExtension"
            Repository = "https://example.com/extensions"
        }
        PS:>Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath "$PWD/.zf/extensions"
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $ExtensionConfig,

        [Parameter(Mandatory=$true)]
        [string] $TargetPath
    )

    [hashtable[]]$processedExtensionConfig = @()

    # Parse the extension configuration item into its canonical form
    $extension = Resolve-ExtensionMetadata -Value $ExtensionConfig -Verbose:$VerbosePreference

    # Prepare the parameters needed for extension registration
    $splat = $extension.Clone()
    $splat.Remove("Process") | Out-Null
    $splat.Add("Repository", $extension.ContainsKey("Repository") ? $extension.Repository : $DefaultRepository)
    $splat.Add("TargetPath", $TargetPath)
    
    # Decide how the extension is being provided
    if (!$extension.ContainsKey("Path")) {
        # Call the helper that will install the extension if it's not already installed and
        # provide the resulting additional metadata that we need to use the extension
        $extension += Get-ExtensionFromRepository @splat
    }
    elseif ((Test-Path $extension.Path)) {
        $extension.Add("Enabled", $true)
        Write-Host "USING PATH: $($extension.Name) ($($extension.Path))" -f Cyan
    }
    else {
        Write-Warning "Extension '$($extension.Name)' not found at $($extension.Path) - it has been disabled."
        $extension.Add("Enabled", $false)
        continue
    }
    
    # If enabled, interrogate the extension for its dependencies and exported tasks? recursive?
    if ($extension.Enabled) {
        Write-Verbose "Checking dependencies for $($extension.Name)"
        $extension.Add("dependencies", (Get-ExtensionDependencies -Extension $extension))
        Write-Verbose "Checking available tasks for $($extension.Name)"
        $extension.Add("availableTasks", (Get-ExtensionAvailableTasks -ExtensionPath $extension.Path))
    }

    $processedExtensionConfig += $extension

    # If enabled, resolve any dependencies for this extension
    if ($extension.Enabled) {
        foreach ($dependency in $extension.dependencies) {
            Write-Host "Processing dependency: $($dependency.Name)"
            $processedExtensionConfig += Register-ExtensionAndDependencies -ExtensionConfig $dependency -TargetPath $TargetPath
        }
    }
    
    return $processedExtensionConfig
}