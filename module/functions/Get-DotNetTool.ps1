# <copyright file="Get-DotNetTool.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
    Simple wrapper to check whether a given .NET tool is already installed.
.DESCRIPTION
    Simple wrapper to check whether a given .NET tool is already installed.
.EXAMPLE
    PS C:\> Get-DotNetTool -Global -Name gitversion.tool
    name            version commands
    ----            ------- --------
    gitversion.tool 5.8.0   dotnet-gitversion

    Checks whether any version of the 'gitversion.tool' .NET tool is installed globally, returning an object with the installed tool's details.
.EXAMPLE
    PS C:\> Get-DotNetTool -ToolPath ./tools -Name gitversion.tool -Version 5.6.6

    Checks whether version 5.6.6 of the 'gitversion.tool' .NET tool is installed to a store at the specified directory, returning null if it isn't.
.PARAMETER Name
    The name of the .NET tool to check
.PARAMETER Version
    The version of the .NET tool to check for. When unspecified any version found will cause this function to return true.
.PARAMETER Global
    When specified, the tool's installation status is checked in the global scope (i.e. for the current user).
.PARAMETER Local
    When specified, the tool's installation status is checked in the local scope (i.e. for the current project's .NET tool manifest).
.PARAMETER ToolPath
    When specified, the tool's installation status is checked in the specified directory.
.OUTPUTS
    An object containing the details of the installed tool, or null if the tool isn't installed.
    @{
        name = "gitversion.tool"
        version = "5.6.6"
        commands = "dotnet-gitversion"
    }
#>
function Get-DotNetTool
{
    [CmdletBinding(DefaultParameterSetName="global")]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter()]
        [string] $Version,
        
        [Parameter(ParameterSetName="global")]
        [switch] $Global,

        [Parameter(ParameterSetName="local")]
        [switch] $Local,

        [Parameter(ParameterSetName="toolpath")]
        [string] $ToolPath
    )

    switch ($PSCmdlet.ParameterSetName) {
        "global" { $scopeArg = @("--global") }
        "local" { $scopeArg = @("--local") }
        "toolpath" { $scopeArg = @("--tool-path", $ToolPath) }
    }

    # Parse the output from the dotnet cli to check whether the tool is already installed:
    #  - Skip first 2 'header' lines of output
    #  - The output is not tab delimited, so convert the whitespace between columns to a comma
    #  - Convert the now CSV-formatted output into an object
    #  - Match the specified tool name
    $existingInstall = & dotnet tool list @scopeArg |
                            Select-Object -Skip 2 |
                            ForEach-Object { $_ -ireplace "\s+","," } |
                            ConvertFrom-Csv -Header name,version,commands |
                            Where-Object { $_.name -eq $Name }

    return $existingInstall
}
