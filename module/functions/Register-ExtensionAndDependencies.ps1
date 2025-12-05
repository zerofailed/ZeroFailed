# <copyright file="Register-ExtensionAndDependencies.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Register-ExtensionAndDependencies {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
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
    $splat.Add("TargetPath", $TargetPath)

    # Skip further processing is extension is explicitly disabled
    if (!$extension.ContainsKey('Enabled') -or $extension.Enabled) {
        if ($extension.ContainsKey("GitRepository")) {
            # Git-based extension
            $splat.Remove("GitRepository")
            $splat.Add("RepositoryUri", $extension.GitRepository)
            # Set defaults for any optional configuration settings
            if (!$extension.ContainsKey("GitRef")) { $splat.Add("GitRef", 'main') }
            if ($extension.ContainsKey("GitRepositoryFolderPath")) {
                $splat.Remove("GitRepositoryFolderPath")
                $splat.Add("RepositoryFolderPath", $extension.GitRepositoryFolderPath)
            }
            else {
                $splat.Add("RepositoryFolderPath", 'module')
            }
    
            # Call the helper that will install the extension from a Git repository if it's not
            # already installed and provide the resulting additional metadata that we need to use the extension
            $extension += Get-ExtensionFromGitRepository @splat
        }
        elseif (!$extension.ContainsKey("Path")) {
            # PowerShell module-based extension
            # Set defaults for any optional configuration settings
            $splat["PSRepository"] = $extension.ContainsKey("PSRepository") ? $extension.PSRepository : $DefaultPSRepository
            
            # Call the helper that will install the extension from a PowerShell module repository if it's not
            # already installed and provide the resulting additional metadata that we need to use the extension
            $extension += Get-ExtensionFromPowerShellRepository @splat
        }
        elseif ((Test-Path $extension.Path)) {
            # Local file-system-based extension
            $extension['Enabled'] = $extension.ContainsKey('Enabled') ? $extension.Enabled : $true
            Write-Host "USING PATH: $($extension.Name) ($($extension.Path))" -f Cyan
        }
        else {
            # Missing local extension or invalid config
            Write-Warning "Extension '$($extension.Name)' not found at $($extension.Path) - it has been disabled."
            $extension['Enabled'] = $false
            continue
        }
    }
    else {
        Write-Host "Skipping extension - explicitly disabled"
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