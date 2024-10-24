<#
.SYNOPSIS
    Removes an exception from the exceptions.json file based on provided filters.

.DESCRIPTION
    This function removes an exception from the exceptions.json file by matching based on the provided criteria. You can remove an exception by SPN object ID, scope, PrivRole, or a combination of other attributes. 

.PARAMETER exceptionFilePath
    The path to the exceptions.json file. Defaults to ".\exceptions.json".

.PARAMETER spnObjectId
    The SPN object ID to match when removing the exception.

.PARAMETER spnNameLike
    The SPN name pattern to match when removing the exception.

.PARAMETER azScopeType
    The Azure scope type (RG, MG, or Sub) to match when removing the exception.

.PARAMETER privRole
    The privileged role (Owner, Contributor, User Access Administrator, AppDevContributor) to match when removing the exception.

.PARAMETER azScopeObjectId
    The Azure object ID (resource group, subscription, management group) to match when removing the exception.

.EXAMPLE
    Remove-Exceptions -spnObjectId "1234"

.EXAMPLE
    Remove-Exceptions -spnNameLike "*SampleApp*" -azScopeType "RG" -privRole "Contributor"

.NOTES
    Author: Brian Sarbaugh
    Version: 1.2.1
#>

function Remove-Exceptions {
    param (
        [Parameter(Mandatory=$false)]
        [string]$exceptionFilePath = ".\exceptions.json",

        [Parameter(Mandatory=$false)]
        [string]$spnObjectId,

        [Parameter(Mandatory=$false)]
        [string]$spnNameLike,

        [Parameter(Mandatory=$false)]
        [ValidateSet("RG", "MG", "Sub")]
        [string]$azScopeType,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Owner", "Contributor", "User Access Administrator", "AppDevContributor")]
        [string]$privRole,

        [Parameter(Mandatory=$false)]
        [string]$azScopeObjectId
    )

    # Load existing exceptions
    if (-not (Test-Path -Path $exceptionFilePath)) {
        throw "Exceptions file not found at path: $exceptionFilePath"
    }

    $exceptions = Get-Content -Raw -Path $exceptionFilePath | ConvertFrom-Json

    # Filter out the matching exceptions
    $newExceptions = $exceptions | Where-Object {
        (-not $spnObjectId -or $_.spn_object_id -ne $spnObjectId) -and
        (-not $spnNameLike -or $_.spn_name_like -notlike $spnNameLike) -and
        (-not $azScopeType -or $_.az_scope_type -ne $azScopeType) -and
        (-not $privRole -or $_.PrivRole -ne $privRole) -and
        (-not $azScopeObjectId -or $_.az_scope_object_id -ne $azScopeObjectId)
    }

    # Check if there were any exceptions removed
    if ($exceptions.Count -eq $newExceptions.Count) {
        Write-Warning "No exceptions were removed. Check the filter criteria."
    }
    else {
        # Save the updated list of exceptions
        $newExceptions | ConvertTo-Json -Depth 10 | Set-Content -Path $exceptionFilePath
        Write-Host "Exception(s) removed successfully."
    }
}
