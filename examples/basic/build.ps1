#Requires -Version 7
<#
.SYNOPSIS
    Runs a .NET flavoured build process.
.DESCRIPTION
    This script was scaffolded using a template from the ZeroFailed project.
    It uses the InvokeBuild module to orchestrate an opinionated software build process for .NET solutions.
.EXAMPLE
    PS C:\> ./build.ps1
    Downloads any missing module dependencies (ZeroFailed & InvokeBuild) and executes
    the build process.
.PARAMETER Tasks
    Optionally override the default task executed as the entry-point of the build.
.PARAMETER Configuration
    The build configuration, defaults to 'Release'.
.PARAMETER BuildRepositoryUri
    Optional URI that supports pulling MSBuild logic from a web endpoint (e.g. a GitHub blob).
.PARAMETER SourcesDir
    The path where the source code to be built is located, defaults to the current working directory.
.PARAMETER CoverageDir
    The output path for the test coverage data, if run.
.PARAMETER TestReportTypes
    The test report format that should be generated by the test report generator, if run.
.PARAMETER PackagesDir
    The output path for any packages produced as part of the build.
.PARAMETER LogLevel
    The logging verbosity.
.PARAMETER Clean
    When true, the .NET solution will be cleaned and all output/intermediate folders deleted.
.PARAMETER BuildModulePath
    The path to import the ZeroFailed module from. This is useful when testing pre-release
    versions of ZeroFailed that are not yet available in the PowerShell Gallery.
.PARAMETER BuildModuleVersion
    The version of the ZeroFailed module to import. This is useful when testing pre-release
    versions of ZeroFailed that are not yet available in the PowerShell Gallery.
.PARAMETER InvokeBuildModuleVersion
    The version of the InvokeBuild module to be used.
#>
[CmdletBinding()]
param (
    [Parameter(Position=0)]
    [string[]] $Tasks = @("."),

    [Parameter()]
    [string] $Configuration = "Debug",

    [Parameter()]
    [string] $BuildRepositoryUri = "",

    [Parameter()]
    [string] $SourcesDir = $PWD,

    [Parameter()]
    [string] $CoverageDir = "_codeCoverage",

    [Parameter()]
    [string] $TestReportTypes = "Cobertura",

    [Parameter()]
    [string] $PackagesDir = "_packages",

    [Parameter()]
    [ValidateSet("minimal","normal","detailed")]
    [string] $LogLevel = "minimal",

    [Parameter()]
    [switch] $Clean,

    [Parameter()]
    [string] $BuildModuleVersion = "1.0.0",

    [Parameter()]
    [version] $InvokeBuildModuleVersion = "5.12.1"
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath

#region InvokeBuild setup
# This handles calling the build engine when this file is run like a normal PowerShell script
# (i.e. avoids the need to have another script to setup the InvokeBuild environment and issue the 'Invoke-Build' command )
if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    Install-PSResource InvokeBuild -Version $InvokeBuildModuleVersion -Scope CurrentUser -TrustRepository -Verbose:$false | Out-Null
    try {
        Invoke-Build $Tasks $MyInvocation.MyCommand.Path @PSBoundParameters
    }
    catch {
        Write-Host -f Yellow "`n`n***`n*** Build Failure Summary - check previous logs for more details`n***"
        Write-Host -f Yellow $_.Exception.Message
        Write-Host -f Yellow $_.ScriptStackTrace
        exit 1
    }
    return
}
#endregion

#region Initialise build framework
$splat = @{ Force = $true; Verbose = $false}
Install-PSResource ZeroFailed -Version $BuildModuleVersion -Scope CurrentUser -TrustRepository -Reinstall:$($BuildModuleVersion -match '-') | Out-Null
$BuildModulePath = "ZeroFailed"
$splat.Add("RequiredVersion", ($BuildModuleVersion -split '-')[0])
$splat.Add("Name", $BuildModulePath)
Import-Module @splat
Write-Host "Using Build module version: $((Get-Module ZeroFailed | Select-Object -ExpandProperty Version).ToString())"
#endregion

# Load the build configuration
. $here/.zf/config.ps1
