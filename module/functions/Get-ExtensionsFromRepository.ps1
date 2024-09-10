function Get-ExtensionFromRepository {
    param(
        [Parameter(Mandatory=$true)]
        [string] $ExtensionName,

        [Parameter(Mandatory=$true)]
        [string] $Repository
    )

    $extension = @{
        Name = $ExtensionName
        Repository = $Repository
        Enabled = $false
    }

    # TODO: Check whether module is already installed, or can we rely on 'Install-PSResource' to handle this?

    # Handle getting the module from the repository
    if (Find-Module $ExtensionName -ErrorAction Ignore) {
        Write-Host "  Installing extension '$ExtensionName' from $Repository"
        $installArgs = $extension.Clone()
        $installArgs += @{
            Scope = "CurrentUser"
            PassThru = $true
        }
        $extensionModule = Install-PSResource @installArgs
        $extension.Add("Path", $extensionModule.InstalledLocation)
        $extension.Add("Enabled", $true)
        Write-Host "  Extension installed: $ExtensionName to $($extension.Path)"
    }
    else {
        Write-Warning "Extension '$ExtensionName' not found on $Repository - it has been disabled."
    }

    return $extension
}