<#
.SYNOPSIS
    Updates an existing exception in the exceptions.json file based on uniqueID.

.DESCRIPTION
    This function updates an existing exception in the exceptions.json file. It searches for the exception using the 
    provided uniqueID and allows updating of specified fields. Only fields provided as parameters will be updated, 
    while other fields will remain unchanged.

.PARAMETER uniqueID
    The unique identifier of the exception to be updated.

.PARAMETER spnEonid
    The EonID for the SPN. Optional parameter for updating.

.PARAMETER spnObjectID
    The SPN Object ID for a single SPN-based exception. Optional parameter for updating.

.PARAMETER spnNameLike
    A wildcard pattern for a name-like SPN exception. Optional parameter for updating.

.PARAMETER tenant
    The tenant identifier. Accepted values are: "prodten", "qaten", "devten". Optional parameter for updating.

.PARAMETER azScopeType
    The type of Azure scope (managementGroup, resourceGroup, subscription). Optional parameter for updating.

.PARAMETER role
    The role being assigned to the SPN (Owner, Contributor, User Access Administrator, or AppDevContributor). Optional parameter for updating.

.PARAMETER azObjectScopeID
    The ID of the Azure object (e.g., resourceGroup, subscription, managementGroup) for specific object exceptions. Optional parameter for updating.

.PARAMETER azObjectNameLike
    A wildcard pattern for an Azure object name. Optional parameter for updating.

.PARAMETER SecArch
    The SecArch approval identifier. Optional parameter for updating.

.PARAMETER ActionPlan
    The ActionPlan identifier. Optional parameter for updating.

.PARAMETER expiration_date
    The expiration date for the ActionPlan (required if ActionPlan is provided). Format: mm/dd/yyyy. Optional parameter for updating.

.PARAMETER exceptionsPath
    The file path for the exceptions.json file. Defaults to ".\exceptions.json".

.EXAMPLE
    Update-Exception -uniqueID "4e5cdfaf-5d02-4e71-a6fc-b6925aa00ff8" -role "Contributor" -SecArch "NewSecArch123"
    
    Updates the role and SecArch fields of the exception with the specified uniqueID.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.1.0
    This function allows updating specific fields of an existing exception in the exceptions.json file.
#>

function Update-Exception {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$uniqueID,
        [Parameter(Mandatory = $false)][string]$spnEonid,
        [Parameter(Mandatory = $false)][string]$spnObjectID,
        [Parameter(Mandatory = $false)][string]$spnNameLike,
        [Parameter(Mandatory = $false)][ValidateSet('prodten', 'qaten', 'devten')][string]$tenant,
        [Parameter(Mandatory = $false)][ValidateSet('managementGroup', 'resourceGroup', 'subscription')][string]$azScopeType,
        [Parameter(Mandatory = $false)][ValidateSet('Owner', 'Contributor', 'User Access Administrator', 'AppDevContributor')][string]$role,
        [Parameter(Mandatory = $false)][string]$azObjectScopeID,
        [Parameter(Mandatory = $false)][string]$azObjectNameLike,
        [Parameter(Mandatory = $false)][string]$SecArch,
        [Parameter(Mandatory = $false)][string]$ActionPlan,
        [Parameter(Mandatory = $false)][datetime]$expiration_date,
        [Parameter(Mandatory = $false)][string]$exceptionsPath = ".\exceptions.json"
    )

    try {
        # Load existing exceptions
        if (-not (Test-Path -Path $exceptionsPath)) {
            throw "exceptions.json file not found."
        }
        $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json

        # Determine if the exception is in SecArchExceptions or ActionPlanExceptions
        $targetGroup = if ($exceptions.SecArchExceptions | Where-Object { $_.uniqueID -eq $uniqueID }) {
            "SecArchExceptions"
        } elseif ($exceptions.ActionPlanExceptions | Where-Object { $_.uniqueID -eq $uniqueID }) {
            "ActionPlanExceptions"
        } else {
            throw "Exception with uniqueID $uniqueID not found."
        }

        # Find and update the exception
        $exception = $exceptions.$targetGroup | Where-Object { $_.uniqueID -eq $uniqueID }
        if ($spnEonid) { $exception.spn_eonid = $spnEonid }
        if ($spnObjectID) { $exception.spnObjectID = $spnObjectID }
        if ($spnNameLike) { $exception.spnNameLike = $spnNameLike }
        if ($tenant) { $exception.tenant = $tenant }
        if ($azScopeType) { $exception.az_scope_type = $azScopeType }
        if ($role) { $exception.role = $role }
        if ($azObjectScopeID) { $exception.azObjectScopeID = $azObjectScopeID }
        if ($azObjectNameLike) { $exception.azObjectNameLike = $azObjectNameLike }
        if ($SecArch) { $exception.SecArch = $SecArch }
        if ($ActionPlan) { $exception.ActionPlan = $ActionPlan }
        if ($expiration_date) { $exception.expiration_date = $expiration_date }

        # Save the updated exceptions
        $exceptions | ConvertTo-Json -Depth 10 | Set-Content -Path $exceptionsPath
        Write-Host "Exception with uniqueID $uniqueID has been updated."
    }
    catch {
        Write-Error "An error occurred while updating the exception: $_"
        throw $_
    }
}
