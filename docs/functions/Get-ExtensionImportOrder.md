---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-US
Module Name: ZeroFailed
ms.date: 11/18/2026
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

Otherwise, an extension that is earlier in the given order is imported later, so when 2 extensions define the same task or property, the earlier one's definition is used.
Each time, the latest extension whose dependencies have all been imported is imported next.
A dependency can still override an extension that is earlier than it in the given order, when an extension that requires it is earlier still.
For example, for 'A', 'B' and 'C', where 'C' requires 'A', the order is 'B', 'A' and 'C', so 'C' overrides 'B'.
Extensions that require each other in a circle, directly or through other extensions, are imported together, the latest of them first.
They are imported when the latest of them would be, so an extension that is earlier than all of them still takes precedence, and an extension that requires one of them is imported after all of them.

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
