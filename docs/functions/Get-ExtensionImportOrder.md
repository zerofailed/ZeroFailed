---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-US
Module Name: ZeroFailed
ms.date: 11/17/2026
PlatyPS schema version: 2024-05-01
title: Get-ExtensionImportOrder
---

# Get-ExtensionImportOrder

## SYNOPSIS

Returns the extensions in the order that their tasks and functions are imported.

## SYNTAX

### __AllParameterSets

```
Get-ExtensionImportOrder [-Extensions] <hashtable[]> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

An extension's tasks, functions and properties can override those of the extensions that it requires.
So every extension is imported after its dependencies, including a dependency that several extensions share.

The extensions are taken in reverse order, and each one is returned after its own dependencies.
So when 2 extensions define the same task or property, the one that is earlier in the given order is imported later, and its definition is used.

A dependency that is not in the given extensions (for example, one that a local extension is used in place of) is ignored.

## EXAMPLES

### EXAMPLE 1

$importOrder = Get-ExtensionImportOrder -Extensions $deduplicatedExtensions
For the extensions 'A', 'Common' and 'B', where 'A' and 'B' both require 'Common', returns 'Common', 'B' and 'A'.

## PARAMETERS

### -Extensions

The de-duplicated extensions (as returned by Resolve-ExtensionDuplicates), in the order that they were registered.

```yaml
Type: System.Collections.Hashtable[]
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

### System.Collections.Hashtable

Returns the given extensions in the order that they are imported, with every extension after the extensions that it requires.

## NOTES

## RELATED LINKS

- [Resolve-ExtensionDuplicates](Resolve-ExtensionDuplicates.md)
