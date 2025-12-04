---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 12/04/2025
PlatyPS schema version: 2024-05-01
title: Get-InstalledExtensionDetails
---

# Get-InstalledExtensionDetails

## SYNOPSIS

Retrieves the details of an installed extension.

## SYNTAX

### Version (Default)

```
Get-InstalledExtensionDetails -Name <string> -TargetPath <string> [-Version <string>] [-PreRelease]
 [<CommonParameters>]
```

### GitRef

```
Get-InstalledExtensionDetails -Name <string> -TargetPath <string> -GitRefAsFolderName <string>
 [-PreRelease] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Searches the local system for an installed version of the PowerShell module representing the specified extension, and returns
the path to the module and the version that was found.

## EXAMPLES

### EXAMPLE 1

$path,$version = Get-InstalledExtensionDetails -Name "MyExtension"

### EXAMPLE 2

$path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -Version "1.0.0"

### EXAMPLE 3

$path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -Version "1.0.0-beta0001"

### EXAMPLE 4

$path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -PreRelease

## PARAMETERS

### -GitRefAsFolderName

The extension version as represented by the GitRef, modified to be safe for use as a filesystem directory name.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: GitRef
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Name

The name of the extension, which is also the name of the PowerShell module.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PreRelease

Indicates whether to include pre-release versions in the search.

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

### -TargetPath

The path to the folder where ZeroFailed extensions are installed (typically '.zf/extensions').

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Version

The version of the extension, if not specified the latest version available, if any, will be returned.
When this contains a semantic version with a pre-release tag, then this implies that a pre-release
version is acceptable. (i.e. as if the '-PreRelease' switch had been specified)

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Version
  Position: Named
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

### System.String

When an installed extension is found, returns a tuple containing the extenion's install path and version.

## NOTES

## RELATED LINKS

- []()
