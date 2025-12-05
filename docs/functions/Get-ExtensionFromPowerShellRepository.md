---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 12/04/2025
PlatyPS schema version: 2024-05-01
title: Get-ExtensionFromPowerShellRepository
---

# Get-ExtensionFromPowerShellRepository

## SYNOPSIS

Retrieves an extension from a PowerShell module repository.

## SYNTAX

### __AllParameterSets

```
Get-ExtensionFromPowerShellRepository [-Name] <string> [-PSRepository] <string>
 [-TargetPath] <string> [[-Version] <string>] [-PreRelease] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

If not already available as a locally-installed module, this function installs the extension (as PowerShell module) from a specified repository.
It also derives the additional metadata about the extension required by the tooling.

## EXAMPLES

### EXAMPLE 1

Get-ExtensionFromPowerShellRepository -Name "MyExtension" -Version "1.0.0" -Path "C:/MyProject/.zf"
Retrieves version 1.0 of the "MyExtension" extension from the default repository (e.g. PSGallery).

## PARAMETERS

### -Name

Specifies the module name of the extension to retrieve.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PreRelease

Indicates whether to consider pre-release versions of the module when checking for existing and installing new versions.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PSRepository

Specifies the PowerShell module repository from which to retrieve the extension.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TargetPath

Specifies the path where the extension should be installed.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Version

Specifies the version of the extension to retrieve.
If not specified, the latest version will be retrieved.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Collections.Hashtable

Returns a hashtable containing completed set of metadata for the extension. This consists of the originally supplied metadata
plus these additional properties:
- Path: The path to the installed extension.
- Enabled: Indicates whether the extension is enabled.

## NOTES

## RELATED LINKS

- []()
