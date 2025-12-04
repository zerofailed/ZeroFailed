---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 12/04/2025
PlatyPS schema version: 2024-05-01
title: Get-ExtensionAvailableTasks
---

# Get-ExtensionAvailableTasks

## SYNOPSIS

Returns a list of all the task names defined within an extension.

## SYNTAX

### __AllParameterSets

```
Get-ExtensionAvailableTasks [-ExtensionPath] <string> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

This function is used to discover all of the tasks defined by an extension.
It does this by creating a private implementation of the InvokeBuild 'task' DSL keyword
that simply returns the task name as a string. This allows us to enumerate all of the tasks defined
in the extension's tasks files, without knowing how many tasks are defined in any given file.

## EXAMPLES

### EXAMPLE 1

$taskNames = Get-ExtensionAvailableTasks -ExtensionPath c:\myExtension

## PARAMETERS

### -ExtensionPath

The path to the root of the extension being searched.

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

### System.String

Lists all the InvokeBuild tasks exposed by the extension.

## NOTES

## RELATED LINKS

- []()
