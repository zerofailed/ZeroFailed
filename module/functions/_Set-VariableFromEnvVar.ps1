# <copyright file="Set-VariableFromEnvVar.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
    Updates the value of a variable based on the value of an environment variable.
.DESCRIPTION
    Supports updating typed PowerShell variables using the string value from an environment variable.
    
    The PowerShell variable must already be defined for this function to udpate its value.
    
    Specific support is included for casting 'boolean' and 'hashtable' types, other types rely on the
    underlying casting support in PowerShell (e.g. integers).

    Hashtable variables can be overridden via an environment variable containing a JSON
    object definition.
.EXAMPLE
    PS C:\> $MyVar = 1
    PS C:\> $MyVar.GetType()
    IsPublic IsSerial Name                                     BaseType
    -------- -------- ----                                     --------
    True     True     Int32                                    System.ValueType

    PS C:\> $env:SomeEnvVar = "50"
    PS C:\> $($env:SomeEnvVar).GetType()
    IsPublic IsSerial Name                                     BaseType
    -------- -------- ----                                     --------
    True     True     String                                   System.Object

    PS C:\> Set-VariableFromEnvVar -VariableName "MyVar" -EnvironmentVariableName "SomeEnvVar"
    True

    PS C:\> Write-Host $MyVar
    50
    PS C:\> $MyVar.GetType()
    IsPublic IsSerial Name                                     BaseType
    -------- -------- ----                                     --------
    True     True     Int32                                    System.ValueType
.EXAMPLE
    PS C:\> $MyDictionary = @{ foo=1; bar="foobar" }
    PS C:\> $MyDictionary.GetType()
    IsPublic IsSerial Name                                     BaseType
    -------- -------- ----                                     --------
    True     True     Hashtable                                System.Object

    PS C:\> $env:SomeEnvVar = '{"foo": 200, "bar": "only-bar" }'
    PS C:\> $($env:SomeEnvVar).GetType()
    IsPublic IsSerial Name                                     BaseType
    -------- -------- ----                                     --------
    True     True     String                                   System.Object

    PS C:\> Set-VariableFromEnvVar -VariableName "MyDictionary" -EnvironmentVariableName "SomeEnvVar"
    True

    PS C:\> $MyDictionary | Format-Table
    Name                           Value
    ----                           -----
    bar                            only-bar
    foo                            200

    PS C:\> $MyDictionary.GetType()
    IsPublic IsSerial Name                                     BaseType
    -------- -------- ----                                     --------
    True     True     Hashtable                                System.Object
.PARAMETER VariableName
    The name of the PowerShell variable that will be updated.
.PARAMETER EnvironmentVariableName
    The name of the environment variable that holds the new value.
.PARAMETER UseGlobalScope
    When true the variable will be updated in the 'global' scope, otherwise the 'script' scope will be used.

    Ref: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scopes
.PARAMETER TestMode
    *** NOTE: Only intended to be used when running Pester tests against this cmdlet. ***

    When true, information about the updated variables will written to the following environment variables:
    
    * _SetVariableFromEnvVarTypeName
    * _SetVariableFromEnvVarValue
    
    This allows the cmdlet's behaviour to be tested via Pester, without mocking. The updated variable values
    are not available to Pester test fixtures due to the way in which Pester creates isolated scopes for
    running the tests in.
.OUTPUTS
    Returns $true if the variable was updated, otherwise returns $false
#>
function Set-VariableFromEnvVar {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory=$true)]
        [string] $VariableName,

        [Parameter(Mandatory=$true)]
        [string] $EnvironmentVariableName,

        [switch] $UseGlobalScope,

        [switch] $TestMode
    )

    if ( !(Test-Path variable:/$VariableName) ) {
        Write-Warning "Unable to override the variable '$VariableName' as it is not currently defined - skipping"
        return $false
    }

    $envVar = Get-Item env:/$EnvironmentVariableName

    # get the type of the existing value of the variable, defaulting to 'string' if null
    $existingValue = (Get-Variable -Name $VariableName).Value
    # strict null checking to avoid false positives with empty arrays
    $varType = $null -ne $existingValue ? $existingValue.GetType() : "".GetType()

    # Update the value of the variable, ensuring that the existing type is preserved and
    # the string value from the environment variable is cast/coerced/converted accordingly.
    switch ($varType.Name)
    {
        "Boolean" {
            # booleans require special handling, due to '-as' not always behaving as required
            # e.g. "false" -as [boolean] returns 'True'
            $varValue = [System.Convert]::ToBoolean($envVar.Value)
        }
        ({$_ -in @("Hashtable","Object[]")}) {
            # support deserializing a JSON string into a hashtable or array
            try {
                $varValue = $envVar.Value | ConvertFrom-Json -AsHashtable -Depth 100
            }
            catch {
                Write-Warning "Unable to process environment variable '$($envVar.Name)' - the value was not valid JSON"
                return $false
            }
        }
        default {
            $varValue = $envVar.Value -as $varType
        }
    }

    Write-Verbose "Overriding '$VariableName' from environment variable [Type=$($varType.Name)]"
    Set-Variable -Scope ($UseGlobalScope ? "global" : "script") -Name $VariableName -Value $varValue

    # When running in the context of Pester, the variable scoping is such that changes made by this function are not accessible
    # to the test fixture - this provides a mechanism for testing the value and type-handling behaviour.
    if ($TestMode) {
        $env:_SetVariableFromEnvVarTypeName = $varValue.GetType().Name
        switch ($env:_SetVariableFromEnvVarTypeName)
        {
            ({$_ -in @("Hashtable","Object[]", "OrderedHashtable")}) {
                # support serializing hashtables and arrays as a JSON string so we can roudntrip the full type information when the
                # tests read the value of the string-based environment variable.
                $env:_SetVariableFromEnvVarValue = $varValue | ConvertTo-Json -Compress -Depth 100
            }
            default {
                $env:_SetVariableFromEnvVarValue = $varValue
            }
        }
    }

    return $true
}