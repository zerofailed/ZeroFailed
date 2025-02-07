[CmdletBinding()]
param (
    [Parameter(Position=0)]
    [string[]] $Tasks = @("."),

    [Parameter()]
    [string] $Configuration = "Debug",

    [Parameter()]
    [string] $SourcesDir = $PWD,

    [Parameter()]
    [string] $PackagesDir = "_packages",

    [Parameter()]
    [ValidateSet("minimal","normal","detailed")]
    [string] $LogLevel = "minimal",

    [Parameter()]
    [version] $InvokeBuildModuleVersion = "5.11.3"
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath

#region InvokeBuild setup
# This handles calling the build engine when this file is run like a normal PowerShell script
# (i.e. avoids the need to have another script to setup the InvokeBuild environment and issue the 'Invoke-Build' command )
if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    Install-PSResource InvokeBuild -Version $InvokeBuildModuleVersion -Scope CurrentUser -TrustRepository | Out-Null
    try {
        Invoke-Build $Tasks $MyInvocation.MyCommand.Path @PSBoundParameters
    }
    catch {
        if ($env:GITHUB_ACTIONS) {
            Write-Host ("::error file={0},line={1},col={2}::{3}" -f `
                            $_.InvocationInfo.ScriptName,
                            $_.InvocationInfo.ScriptLineNumber,
                            $_.InvocationInfo.OffsetInLine,
                            $_.Exception.Message
                        )
        }
        Write-Host -f Yellow "`n`n***`n*** Build Failure Summary - check previous logs for more details`n***"
        Write-Host -f Yellow $_.Exception.Message
        Write-Host -f Yellow $_.ScriptStackTrace
        exit 1
    }
    return
}
#endregion

# Load the local version of the module
Import-Module "$here/module/ZeroFailed.psd1" -Force

# Load the build configuration
. $here/.zf/config.ps1
