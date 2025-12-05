---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 12/04/2025
PlatyPS schema version: 2024-05-01
title: Get-FunctionsFileListFromExtension
---

# Get-FunctionsFileListFromExtension

## SYNOPSIS

Finds all the function definitions from a specified extension.

## SYNTAX

### __AllParameterSets

```
Get-FunctionsFileListFromExtension [-FunctionsPath] <string> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Finds all the files that define functions, whilst excluding any test files using the typical Pester naming convention.

## EXAMPLES

### EXAMPLE 1

$functionFiles = Get-FunctionsFileListFromExtension -FunctionsPath "C:\myExtension\functions"
PS:> $functionFiles | % { . $_ }

## PARAMETERS

### -FunctionsPath

The path to where the scripts with the extension's functions are stored.

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

Returns an array of paths to the files containing the function definitions.

## NOTES

## RELATED LINKS

- []()
