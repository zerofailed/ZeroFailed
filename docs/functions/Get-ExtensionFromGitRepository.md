---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 12/05/2025
PlatyPS schema version: 2024-05-01
title: Get-ExtensionFromGitRepository
---

# Get-ExtensionFromGitRepository

## SYNOPSIS

Retrieves an extension from a Git repository using the git CLI.

## SYNTAX

### __AllParameterSets

```
Get-ExtensionFromGitRepository [-Name] <string> [-RepositoryUri] <uri>
 [[-RepositoryFolderPath] <string>] [-TargetPath] <string> [-GitRef] <string>
 [[-UseEphemeralVendirConfig] <bool>] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

If not already available as a locally-installed module, this function installs the extension from the specified git repository.
It also derives the additional metadata about the extension required by the tooling.

## EXAMPLES

### EXAMPLE 1

Get-ExtensionFromGitRepository -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -RepositoryUri "https://github.com/myorg/MyExtension.git"
Retrieves the 'main' branch version of the "MyExtension" extension from a git repository that uses the default ZF extension folder structure.

### EXAMPLE 2

Get-ExtensionFromGitRepository -Name "MyExtension" -GitRef "refs/tags/1.0" -TargetPath "C:/MyProject/.zf" -RepositoryUri "https://github.com/myorg/MyExtension.git"
Retrieves '1.0' tagged version of the "MyExtension" extension from a git repository that uses the default ZF extension folder structure.

### EXAMPLE 3

Get-ExtensionFromGitRepository -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -RepositoryUri "https://github.com/myorg/MyExtension.git" -RepositoryFolderPath 'modules/MyExtension'
Retrieves the 'main' branch version of the "MyExtension" extension from a git repository that uses a custom folder structure.

## PARAMETERS

### -GitRef

Specifies the version of the extension to retrieve.
If not specified, the 'main' branch will be retrieved.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 4
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Name

Specifies the name of the extension being retrieved.

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

### -RepositoryFolderPath

Specifies the folder path within the repository where the extension is located.
Defaults to standard ZF convention of 'module'.

```yaml
Type: System.String
DefaultValue: module
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -RepositoryUri

Specifies the Git repository URI from which to retrieve the extension.

```yaml
Type: System.Uri
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
  Position: 3
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -UseEphemeralVendirConfig

When true, the generated vendir configuration files are deleted once used by this function.

```yaml
Type: System.Boolean
DefaultValue: True
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 5
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
