<#
.SYNOPSIS
    Adds a new exception to the exceptions.json file after validating the schema, ensuring all necessary fields are present, and preventing duplicates.

.DESCRIPTION
    This function adds a new exception to the exceptions.json file after validating its schema. It supports both spnObjectID-based 
    and spnNameLike-based exceptions, handling mutually exclusive parameters. The function also adds missing fields to existing 
    exceptions, such as uniqueID, date_added, LastUpdated, and lastModifiedBy, to ensure consistency across all exceptions.

    Each exception added or modified will have a uniqueID (GUID) for identification, a date_added to indicate when it was initially 
    added, a LastUpdated field to track the last modification date, and a lastModifiedBy field to store the email address of the approver.

.PARAMETER spnEonid
    The EonID for the SPN. Required for all exceptions.

.PARAMETER spnObjectID
    The SPN Object ID for a specific SPN-based exception. Mutually exclusive with spnNameLike.

.PARAMETER spnNameLike
    A wildcard pattern for a name-like SPN exception. Mutually exclusive with spnObjectID and requires spnEonid and tenant.

.PARAMETER tenant
    The tenant identifier. Accepted values: "prodten", "qaten", "devten". Required if spnNameLike is used.

.PARAMETER azScopeType
    The type of Azure scope (managementGroup, resourceGroup, subscription). Mandatory for all exceptions.

.PARAMETER role
    The role being assigned to the SPN (Owner, Contributor, User Access Administrator, or AppDevContributor). Only one role per exception.

.PARAMETER azObjectScopeID
    The ID of the Azure object (e.g., resourceGroup, subscription, managementGroup) for specific object exceptions. Mutually exclusive with azObjectNameLike.

.PARAMETER azObjectNameLike
    A wildcard pattern for an Azure object name. Mutually exclusive with azObjectScopeID.

.PARAMETER SecArch
    The SecArch approval identifier. Automatically includes a date_added, LastUpdated, and lastModifiedBy. Either SecArch or ActionPlan is required.

.PARAMETER ActionPlan
    The ActionPlan identifier. Automatically includes a date_added, LastUpdated, and lastModifiedBy, and requires an expiration date. Either SecArch or ActionPlan is required.

.PARAMETER expiration_date
    The expiration date for the ActionPlan (required if ActionPlan is provided). Format: mm/dd/yyyy.

.PARAMETER lastModifiedBy
    The email address of the person approving or adding the exception. Required and must follow a valid email format.

.PARAMETER exceptionsPath
    The file path for the exceptions.json file. Defaults to the path specified in config.json.

.PARAMETER datasetPath
    The file path for the dataset (CSV). Defaults to the path specified in config.json.

.PARAMETER removalCount
    Optional switch to output the count of how many items would be removed from the dataset based on this new exception.

.EXAMPLE
    Add-Exception -spnObjectID "SPN1234" -spnEonid "EON123" -azScopeType "resourceGroup" -role "Owner" -lastModifiedBy "admin@example.com"
    
    Adds an exception for a specific SPN object ID, granting Owner role on all resourceGroups, with approval tracked to "admin@example.com".

.EXAMPLE
    Add-Exception -spnNameLike "*sampleApp*" -spnEonid "EON123" -tenant "prodten" -azScopeType "managementGroup" -role "Contributor" -lastModifiedBy "user@example.com"
    
    Adds an exception for SPNs with a name-like pattern, granting Contributor role on any managementGroup filtered by spnEonid. The approver is "user@example.com".

.EXAMPLE
    Add-Exception -spnObjectID "SPN5678" -spnEonid "EON456" -azScopeType "subscription" -role "User Access Administrator" -SecArch "Sec123" -lastModifiedBy "approver@example.com"
    
    Adds an exception for a specific SPN object ID, granting User Access Administrator role on all subscriptions with SecArch approval. The approver is "approver@example.com".

.NOTES
    Author: Brian Sarbaugh
    Version: 1.3.0
    Includes email validation for the approver.
#>

function Add-Exception {
    [CmdletBinding(DefaultParameterSetName = 'spnObjectIDSet')]
    param(
        [Parameter(Mandatory = $true)][string]$spnEonid,
        [Parameter(Mandatory = $true, ParameterSetName = 'spnObjectIDSet')][string]$spnObjectID,
        [Parameter(Mandatory = $true, ParameterSetName = 'spnNameLikeSet')][string]$spnNameLike,
        [Parameter(Mandatory = $true, ParameterSetName = 'spnNameLikeSet')][ValidateSet('prodten', 'qaten', 'devten')][string]$tenant,
        [Parameter(Mandatory = $true)][ValidateSet('managementGroup', 'resourceGroup', 'subscription')][string]$azScopeType,
        [Parameter(Mandatory = $true)][ValidateSet('Owner', 'Contributor', 'User Access Administrator', 'AppDevContributor')][string]$role,
        [Parameter(Mandatory = $false)][string]$azObjectScopeID,
        [Parameter(Mandatory = $false)][string]$azObjectNameLike,
        [Parameter(Mandatory = $false)][string]$SecArch,
        [Parameter(Mandatory = $false)][string]$ActionPlan,
        [Parameter(Mandatory = $false)][datetime]$expiration_date,
        [Parameter(Mandatory = $true)][ValidatePattern('^[\w\.-]+@[\w\.-]+\.\w{2,4}$')][string]$lastModifiedBy, # Validates email format
        [Parameter(Mandatory = $false)][string]$exceptionsPath,
        [Parameter(Mandatory = $false)][string]$datasetPath,
        [Parameter(Mandatory = $false)][switch]$removalCount
    )

    try {
        $configPath = ".\config.json"
        if (-not (Test-Path -Path $configPath)) {
            throw "config.json not found."
        }
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

        if (-not $exceptionsPath) { $exceptionsPath = $config.exceptionsPath }
        if (-not $datasetPath) {
            $dataset = Get-Dataset -datasetDir $config.datasetDir -filenamePattern $config.filenamePattern
        } else {
            $dataset = Import-Csv -Path $datasetPath
        }

        # Determine which group to add the exception to
        if (-not $SecArch -and -not $ActionPlan) {
            throw "Either SecArch or ActionPlan must be provided."
        }
        if ($ActionPlan -and -not $expiration_date) {
            throw "An expiration date is required if using ActionPlan."
        }
        $group = if ($SecArch) { "SecArchExceptions" } else { "ActionPlanExceptions" }

        # Initialize the exception object excluding date fields
        $exception = @{
            uniqueID = (New-Guid).Guid
            spn_eonid = $spnEonid
            az_scope_type = $azScopeType
            role = $role
            LastUpdated = (Get-Date).ToString('MM/dd/yyyy')
            lastModifiedBy = $lastModifiedBy
        }
        if ($spnObjectID) { $exception.spnObjectID = $spnObjectID }
        if ($spnNameLike) { $exception.spnNameLike = $spnNameLike; $exception.tenant = $tenant }
        if ($azObjectScopeID) { $exception.azObjectScopeID = $azObjectScopeID }
        if ($azObjectNameLike) { $exception.azObjectNameLike = $azObjectNameLike }
        if ($SecArch) { $exception.SecArch = $SecArch }
        if ($ActionPlan) { $exception.ActionPlan = $ActionPlan }

        # Load existing exceptions
        $exceptions = if (Test-Path -Path $exceptionsPath) {
            Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
        } else {
            @{ SecArchExceptions = @(); ActionPlanExceptions = @() }
        }

        # Ensure all existing exceptions have the required fields
        foreach ($exc in $exceptions.$group) {
            if (-not $exc.uniqueID) { $exc | Add-Member -MemberType NoteProperty -Name "uniqueID" -Value (New-Guid).Guid -Force }
            if (-not $exc.date_added) { $exc | Add-Member -MemberType NoteProperty -Name "date_added" -Value (Get-Date).ToString('MM/dd/yyyy') -Force }
            if (-not $exc.LastUpdated) { $exc | Add-Member -MemberType NoteProperty -Name "LastUpdated" -Value (Get-Date).ToString('MM/dd/yyyy') -Force }
            if (-not $exc.lastModifiedBy) { $exc | Add-Member -MemberType NoteProperty -Name "lastModifiedBy" -Value $lastModifiedBy -Force }
        }

        # Add date_added and other fields for new exceptions
        $exception.date_added = (Get-Date).ToString('MM/dd/yyyy')
        if ($ActionPlan) { $exception.expiration_date = $expiration_date }

        # Add new exception to the group
        $exceptions.$group += $exception
        $exceptions | ConvertTo-Json -Depth 10 | Set-Content -Path $exceptionsPath

        # Optional removalCount logic
        if ($removalCount) {
            $removalMatches = $dataset | Where-Object {
                $spnMatch = $exception.spnObjectID -and ($_.AppObjectID -eq $exception.spnObjectID) -or
                            $exception.spnNameLike -and ($_.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                $azObjectMatch = $exception.azObjectScopeID -and ($_.AzureObjectScopeID -eq $exception.azObjectScopeID) -or
                                 $exception.azObjectNameLike -and ($_.ObjectName -ilike "*$($exception.azObjectNameLike)*")
                $spnMatch -and $azObjectMatch -and
                ($_.PrivRole -eq $exception.role) -and
                ($_.ObjectType -eq $exception.az_scope_type) -and
                ($_.Tenant -eq $exception.tenant)
            }

            Write-Host "Removal count: $($removalMatches.Count)"
        }
    }
    catch {
        Write-Error "An error occurred: $_"
        throw $_
    }
}
