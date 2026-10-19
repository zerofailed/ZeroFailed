---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 06/22/2026
PlatyPS schema version: 2024-05-01
title: Get-InstalledExtensionDetails
---

# Get-InstalledExtensionDetails

## SYNOPSIS

Retrieves the details of an installed extension.

## SYNTAX

### Version (Default)

```
Get-InstalledExtensionDetails -Name <string> -TargetPath <string> [-Version <string>]
 [-MinimumVersion <string>] [-PreRelease] [<CommonParameters>]
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

$path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -TargetPath "C:/MyProject/.zf"

### EXAMPLE 2

$path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -Version "1.0.0"

### EXAMPLE 3

$path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -Version "1.0.0-beta0001" -PreRelease

### EXAMPLE 4

$path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -PreRelease

### EXAMPLE 5

$path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -MinimumVersion "1.4.0"

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

### -MinimumVersion

The lowest version of the extension to return. The newest installed version from this version up to, but not
including, the next major version is returned (e.g. '1.4.0' matches '1.9.2', but not '2.0.0'). Before version 1.0.0,
the limit is the next change to the first part that is not zero (e.g. '0.3.1' matches versions below '0.4.0').
Pre-release versions only match when the '-PreRelease' switch is specified. When '-Version' is also specified,
this parameter is ignored.

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
When specified, only that exact version is returned, even if a later version is installed.
When this contains a semantic version with a pre-release tag, then this implies that a pre-release
version is acceptable. (i.e. as if the '-PreRelease' switch had been specified)
When the '-PreRelease' switch is specified, a version without a pre-release tag (e.g. '1.0.0') also matches its
pre-release versions (e.g. '1.0.0-beta0001').

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

When an installed extension is found, returns a tuple containing the extension's install path and version.

## NOTES

## RELATED LINKS

- []()
