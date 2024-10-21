function Get-Exceptions {
    <#
    .SYNOPSIS
        Loads exceptions from the exceptions.json file in the root of the repo.

    .DESCRIPTION
        This function reads and returns the exceptions from the specified exceptions.json file.

    .EXAMPLE
        PS C:\> Get-Exceptions

        Retrieves the list of exceptions from the JSON file.
    #>
    try {
        $FilePath = Join-Path $PSScriptRoot "..\exceptions.json"
        if (-Not (Test-Path $FilePath)) {
            throw "File not found"
        }
        $jsonContent = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
        return $jsonContent
    } catch {
        throw "Failed to load exceptions from $FilePath : $_"
    }
}
