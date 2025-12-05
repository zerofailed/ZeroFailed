---
document type: cmdlet
external help file: ZeroFailed-Help.xml
HelpUri: ''
Locale: en-GB
Module Name: ZeroFailed
ms.date: 12/04/2025
PlatyPS schema version: 2024-05-01
title: Copy-FolderFromGitRepo
---

# Copy-FolderFromGitRepo

## SYNOPSIS

Clones a Git repository and copies a specified folder from the cloned repository to a destination.

## SYNTAX

### __AllParameterSets

```
Copy-FolderFromGitRepo [-RepoUrl] <string> [-RepoFolderPath] <string> [-DestinationPath] <string>
 [[-GitRef] <string>] [[-GitCmd] <string>] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

The function clones the specified Git repository into a temporary directory,
retrieves the folder indicated by RepoFolderPath, and copies its contents to the specified DestinationPath.
It validates the existence of Git CLI and cleans up the temporary clone after the operation.

## EXAMPLES

### EXAMPLE 1

Copy-FolderFromGitRepo -RepoUrl 'https://github.com/example/repo.git' -RepoFolderPath 'src' -DestinationPath 'C:\target'

## PARAMETERS

### -DestinationPath

The path where the folder's contents will be copied.

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

### -GitCmd

The Git command to use.
Defaults to expecting 'git' to be in the PATH.

```yaml
Type: System.String
DefaultValue: git
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 4
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -GitRef

The branch or tag to check out from the repository.
Defaults to 'main'.

```yaml
Type: System.String
DefaultValue: main
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

### -RepoFolderPath

The relative path within the repository of the folder to be copied.

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

### -RepoUrl

The URL of the Git repository to clone.

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

### System.Void

This function has no outputs.

## NOTES

Requires Git CLI to be installed.

## RELATED LINKS

- []()
