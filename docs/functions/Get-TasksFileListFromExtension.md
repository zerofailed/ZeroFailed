---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 12/04/2025
PlatyPS schema version: 2024-05-01
title: Get-TasksFileListFromExtension
---

# Get-TasksFileListFromExtension

## SYNOPSIS

Finds all the task definition files from a specified extension.

## SYNTAX

### __AllParameterSets

```
Get-TasksFileListFromExtension [-TasksPath] <string> [[-TasksFileGlob] <string>]
 [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Finds all the files that define tasks for an extension, using the pattern defined in '-TasksFileGlob'.

## EXAMPLES

### EXAMPLE 1

$taskFiles = Get-TasksFileListFromExtension -TasksPath "C:\myExtension\tasks"
PS:> $taskFiles | % { . $_ }

## PARAMETERS

### -TasksFileGlob

The glob pattern to use when searching for task files, defaults to '*.tasks.ps1'.

```yaml
Type: System.String
DefaultValue: '*.tasks.ps1'
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TasksPath

The path to the extension tasks.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.IO.FileInfo

Returns an array of paths to the files containing the task definitions.

## NOTES

## RELATED LINKS

- []()
