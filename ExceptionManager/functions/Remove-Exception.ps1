<#
.SYNOPSIS
    Updates an existing exception in the exceptions.json file, updating fields and tracking the person making the modification.

.DESCRIPTION
    This function searches for an existing exception in the exceptions.json file using a provided uniqueID or matching criteria.
    Once found, it updates the specified fields, adds any missing fields (such as uniqueID, date_added, LastUpdated, and lastModifiedBy),
    and sets the LastUpdated and lastModifiedBy fields to reflect the modification.

.PARAMETER uniqueID
    The unique GUID of the exception to update. Required for identifying the exception to modify.

.PARAMETER spnEonid
    The EonID for the SPN. Optional if only updating specific fields.

.PARAMETER spnObjectID
    The SPN Object ID for a specific SPN-based exception. Mutually exclusive with spnNameLike.

.PARAMETER spnNameLike
    A wildcard pattern for a name-like SPN exception. Mutually exclusive with spnObjectID and requires spnEonid and tenant.

.PARAMETER tenant
    The tenant identifier. Accepted values: "prodten", "qaten", "devten". Required if spnNameLike is used.

.PARAMETER azScopeType
    The type of Azure scope (managementGroup, resourceGroup, subscription). Optional if only updating specific fields.

.PARAMETER role
    The role being assigned to the SPN (Owner, Contributor, User Access Administrator, or AppDevContributor). Optional.

.PARAMETER azObjectScopeID
    The ID of the Azure object (e.g., resourceGroup, subscription, managementGroup) for specific object exceptions. Mutually exclusive with azObjectNameLike.

.PARAMETER azObjectNameLike
    A wildcard pattern for an Azure object name. Mutually exclusive with azObjectScopeID.

.PARAMETER SecArch
    The SecArch approval identifier. Automatically includes LastUpdated and lastModifiedBy fields.

.PARAMETER ActionPlan
    The ActionPlan identifier. Automatically includes LastUpdated and lastModifiedBy fields, and requires an expiration date.

.PARAMETER expiration_date
    The expiration date for the ActionPlan (required if ActionPlan is provided). Format: mm/dd/yyyy.

.PARAMETER lastModifiedBy
    The email address of the person modifying the exception. Required and must follow a valid email format.

.PARAMETER exceptionsPath
    The file path for the exceptions.json file. Defaults to the path specified in config.json.

.EXAMPLE
    Update-Exception -uniqueID "123e4567-e89b-12d3-a456-426614174000" -spnEonid "EON123" -lastModifiedBy "admin@example.com"
    
    Updates an exception's spnEonid field and logs the approver's email as "admin@example.com".

.EXAMPLE
    Update-Exception -uniqueID "123e4567-e89b-12d3-a456-426614174000" -ActionPlan "AP456" -expiration_date "12/31/2024" -lastModifiedBy "admin@example.com"
    
    Updates an exception with a new ActionPlan and expiration date, recording "admin@example.com" as the approver.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.0.0
    Ensures all exceptions have a consistent structure with LastUpdated and lastModifiedBy fields.
#>

function Update-Exception {
    [CmdletBinding()]
    param(
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
        [Parameter(Mandatory = $true)][ValidatePattern('^[\w\.-]+@[\w\.-]+\.\w{2,4}$')][string]$lastModifiedBy, # Validates email format
        [Parameter(Mandatory = $false)][string]$exceptionsPath
    )

    try {
        $configPath = ".\config.json"
        if (-not (Test-Path -Path $configPath)) {
            throw "config.json not found."
        }
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
        if (-not $exceptionsPath) { $exceptionsPath = $config.exceptionsPath }

        # Load existing exceptions
        $exceptions = if (Test-Path -Path $exceptionsPath) {
            Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
        } else {
            throw "Exceptions file not found at path: $exceptionsPath"
        }

        # Find the exception to update by uniqueID
        $exceptionToUpdate = ($exceptions.SecArchExceptions + $exceptions.ActionPlanExceptions) | Where-Object { $_.uniqueID -eq $uniqueID }
        if (-not $exceptionToUpdate) {
            throw "Exception with uniqueID $uniqueID not found."
        }

        # Update fields if provided
        if ($spnEonid) { $exceptionToUpdate.spn_eonid = $spnEonid }
        if ($spnObjectID) { $exceptionToUpdate.spnObjectID = $spnObjectID }
        if ($spnNameLike) { $exceptionToUpdate.spnNameLike = $spnNameLike; $exceptionToUpdate.tenant = $tenant }
        if ($azScopeType) { $exceptionToUpdate.az_scope_type = $azScopeType }
        if ($role) { $exceptionToUpdate.role = $role }
        if ($azObjectScopeID) { $exceptionToUpdate.azObjectScopeID = $azObjectScopeID }
        if ($azObjectNameLike) { $exceptionToUpdate.azObjectNameLike = $azObjectNameLike }
        if ($SecArch) { $exceptionToUpdate.SecArch = $SecArch; $exceptionToUpdate.ActionPlan = $null; $exceptionToUpdate.expiration_date = $null }
        if ($ActionPlan) { $exceptionToUpdate.ActionPlan = $ActionPlan; $exceptionToUpdate.expiration_date = $expiration_date; $exceptionToUpdate.SecArch = $null }

        # Update LastUpdated and lastModifiedBy fields
        $exceptionToUpdate.LastUpdated = (Get-Date).ToString('MM/dd/yyyy')
        $exceptionToUpdate.lastModifiedBy = $lastModifiedBy

        # Save changes to exceptions.json
        $exceptions | ConvertTo-Json -Depth 10 | Set-Content -Path $exceptionsPath
        Write-Host "Exception with uniqueID $uniqueID successfully updated."

    }
    catch {
        Write-Error "An error occurred while updating the exception: $_"
        throw $_
    }
}
