---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 12/05/2025
PlatyPS schema version: 2024-05-01
title: Update-VendirConfig
---

# Update-VendirConfig

## SYNOPSIS

Updates the vendir configuration file with a new extension entry.

## SYNTAX

### __AllParameterSets

```
Update-VendirConfig [-Name] <string> [-RepositoryUri] <string> [-GitRef] <string>
 [-RepositoryFolderPath] <string> [-ConfigPath] <string> [-TargetPath] <string> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function adds or updates an entry in the vendir configuration file (zf.vendir.yml) for a specific extension.
It uses powershell-yaml to read and write the configuration.

## EXAMPLES

### EXAMPLE 1

Update-VendirConfig -Name "MyExt" -RepositoryUri "https://github.com/org/repo.git" -GitRef "main" -RepositoryFolderPath "module" -ConfigPath ".zf/.cache/zf.vendir.yaml" -TargetPath ".zf/extensions/MyExt/main"

## PARAMETERS

### -ConfigPath

The path to the vendir YAML configuration file.

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

### -GitRef

The Git reference (branch, tag, or commit SHA).

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

### -Name

The name of the extension.

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

The folder path within the repository to include.

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

### -RepositoryUri

The URI of the Git repository.

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

The path where the downloaded files are stored.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 5
  IsRequired: true
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

### System.Void

This function has no outputs.

## NOTES

## RELATED LINKS

- []()
