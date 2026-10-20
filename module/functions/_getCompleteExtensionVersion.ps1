# <copyright file="_getCompleteExtensionVersion.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getCompleteExtensionVersion {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Version
    )

    # Accept versions with fewer than 3 numeric parts (e.g. '1.4'), as PowerShell does for module versions, and add the
    # missing parts (e.g. '1.4.0'), so that they can be compared with installed versions. Returns nothing for any other
    # text.
    if ($Version -notmatch '^(?<numbers>\d+(\.\d+){0,2})(?<label>-[0-9A-Za-z.-]+)?$') {
        return $null
    }
    $parts = @($Matches.numbers -split '\.') + @('0', '0')

    return "$($parts[0]).$($parts[1]).$($parts[2])$($Matches['label'])"
}
