function Save-Exceptions {
    <#
    .SYNOPSIS
        Saves the updated exceptions list to the exceptions.json file in the root of the repo.

    .DESCRIPTION
        This function takes a hashtable of exceptions and writes it to the specified exceptions.json file.

    .EXAMPLE
        PS C:\> Save-Exceptions -ExceptionsList $exceptions

        Saves the exceptions list to the exceptions.json file.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$ExceptionsList
    )
    
    try {
        $FilePath = Join-Path $PSScriptRoot "..\exceptions.json"
        $jsonContent = $ExceptionsList | ConvertTo-Json -Depth 10
        $jsonContent | Out-File -FilePath $FilePath -Force
    } catch {
        Write-Error "Failed to save exceptions to $FilePath : $_"
    }
}
