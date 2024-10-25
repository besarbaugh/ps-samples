<#
.SYNOPSIS
    Adds a new exception to the exceptions.json file after validating the schema and preventing duplicates.

.DESCRIPTION
    This function adds a new exception to the exceptions.json file after validating its schema. It supports both 
    spnObjectID-based exceptions and spnNameLike patterns, ensuring mutual exclusivity. It also validates the 
    tenant and spnEonid when adding spnNameLike patterns. Wildcard lookups for AppDisplayName and AzureObjectName 
    are supported. Additionally, the function prevents exact duplicate exceptions from being added to the exceptions.json file.

.PARAMETER spnEonid
    The EonID for the SPN. This is required for all exceptions.

.PARAMETER spnObjectID
    The SPN Object ID for a single SPN-based exception. This is mutually exclusive with spnNameLike.

.PARAMETER spnNameLike
    A wildcard pattern for a name-like SPN exception. This is mutually exclusive with spnObjectID. Requires spnEonid and tenant.

.PARAMETER tenant
    The tenant identifier. Accepted values are: "prodten", "qaten", "devten". This is required if spnNameLike is used.

.PARAMETER azScopeType
    The type of Azure scope (managementGroup, resourceGroup, subscription). Mandatory for all exceptions.

.PARAMETER role
    The role being assigned to the SPN (Owner, Contributor, User Access Administrator, or AppDevContributor). Only one role per exception.

.PARAMETER azObjectScopeID
    The ID of the Azure object (e.g., resourceGroup, subscription, managementGroup) for specific object exceptions. Mutually exclusive with azObjectNameLike.

.PARAMETER azObjectNameLike
    A wildcard pattern for an Azure object name. Mutually exclusive with azObjectScopeID.

.PARAMETER SecArch
    The SecArch approval identifier. Automatically includes a 'date added'. Either SecArch or ActionPlan is required.

.PARAMETER ActionPlan
    The ActionPlan identifier. Automatically includes a 'date added' and requires an expiration date. Either SecArch or ActionPlan is required.

.PARAMETER expiration_date
    The expiration date for the ActionPlan (required if ActionPlan is provided). Format: mm/dd/yyyy.

.PARAMETER exceptionsPath
    The file path for the exceptions.json file. Defaults to the path specified in config.json.

.PARAMETER datasetPath
    The file path for the dataset (CSV). Defaults to the path specified in config.json.

.PARAMETER removalCount
    Optional switch to output the count of how many items would be removed from the dataset based on this new exception.

.EXAMPLE
    Add-Exception -spnObjectID "SPN1234" -spnEonid "EON123" -azScopeType "resourceGroup" -role "Owner"
    
    Adds an exception for a specific SPN object ID, granting Owner role on all resourceGroups. The tenant is derived from spnEonid.

.EXAMPLE
    Add-Exception -spnNameLike "*sampleApp*" -spnEonid "EON123" -tenant "prodten" -azScopeType "managementGroup" -role "Contributor"
    
    Adds an exception for SPNs with a name-like pattern, granting Contributor role on any managementGroup, filtered by spnEonid.

.EXAMPLE
    Add-Exception -spnObjectID "SPN5678" -spnEonid "EON456" -azScopeType "subscription" -role "User Access Administrator" -SecArch "Sec123"
    
    Adds an exception for a specific SPN object ID, granting User Access Administrator role on all subscriptions with SecArch approval.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.0.5
    This function prevents the addition of exact duplicate exceptions and validates the schema before adding. It also supports counting how many existing entries in the dataset would be removed by this exception.
#>

function Add-Exception {
    [CmdletBinding(DefaultParameterSetName = 'spnObjectIDSet')]
    param(
        [Parameter(Mandatory = $true)][string]$spnEonid,  # Now mandatory for all
        [Parameter(Mandatory = $true, ParameterSetName = 'spnObjectIDSet')][string]$spnObjectID,  # Mutually exclusive with spnNameLike
        [Parameter(Mandatory = $true, ParameterSetName = 'spnNameLikeSet')][string]$spnNameLike,  # Mutually exclusive with spnObjectID
        [Parameter(Mandatory = $true, ParameterSetName = 'spnNameLikeSet')][ValidateSet('prodten', 'qaten', 'devten')][string]$tenant,
        [Parameter(Mandatory = $true)][ValidateSet('managementGroup', 'resourceGroup', 'subscription')][string]$azScopeType,
        [Parameter(Mandatory = $true)][ValidateSet('Owner', 'Contributor', 'User Access Administrator', 'AppDevContributor')][string]$role,
        [Parameter(Mandatory = $false)][string]$azObjectScopeID,  # Mutually exclusive with azObjectNameLike
        [Parameter(Mandatory = $false)][string]$azObjectNameLike,  # Mutually exclusive with azObjectScopeID
        [Parameter(Mandatory = $false)][string]$SecArch,  # SecArch or ActionPlan required
        [Parameter(Mandatory = $false)][string]$ActionPlan,  # SecArch or ActionPlan required
        [Parameter(Mandatory = $false)][datetime]$expiration_date,  # Required if ActionPlan is provided
        [Parameter(Mandatory = $false)][string]$exceptionsPath,  # Path for exceptions.json
        [Parameter(Mandatory = $false)][string]$datasetPath,  # Path for dataset (CSV)
        [Parameter(Mandatory = $false)][switch]$removalCount  # Optional removal count test
    )

    try {
        # Load configuration settings
        $configPath = ".\config.json"
        if (-not (Test-Path -Path $configPath)) {
            throw "config.json not found."
        }
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

        if (-not $exceptionsPath) {
            $exceptionsPath = $config.exceptionsPath
        }
        if (-not $datasetPath) {
            $dataset = Get-Dataset -datasetDir $config.datasetDir -filenamePattern $config.filenamePattern
        } else {
            $dataset = Import-Csv -Path $datasetPath
        }

        # Validate mutually exclusive parameters
        if ($spnObjectID -and $spnNameLike) {
            throw "Cannot use both spnObjectID and spnNameLike at the same time."
        }
        if ($azObjectScopeID -and $azObjectNameLike) {
            throw "Cannot use both azObjectScopeID and azObjectNameLike at the same time."
        }
        if (-not $SecArch -and -not $ActionPlan) {
            throw "Either SecArch or ActionPlan must be provided."
        }
        if ($ActionPlan -and -not $expiration_date) {
            throw "An expiration date is required if using ActionPlan."
        }

        # Initialize the exception object
        $exception = @{
            spnEonid = $spnEonid
            azScopeType = $azScopeType
            role = $role
            date_added = (Get-Date).ToString('MM/dd/yyyy')
        }

        if ($spnObjectID) { $exception.spnObjectID = $spnObjectID }
        if ($spnNameLike) { 
            $exception.spnNameLike = $spnNameLike
            $exception.tenant = $tenant
        }
        if ($azObjectScopeID) { $exception.azObjectScopeID = $azObjectScopeID }
        if ($azObjectNameLike) { $exception.azObjectNameLike = $azObjectNameLike }
        if ($SecArch) { $exception.SecArch = $SecArch }
        if ($ActionPlan) { 
            $exception.ActionPlan = $ActionPlan 
            $exception.expiration_date = $expiration_date 
        }

        # Load existing exceptions and check for duplicates
        if (-not (Test-Path -Path $exceptionsPath)) {
            $exceptions = @()
        } else {
            [array]$exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
        }

        if ($exceptions -contains $exception) {
            throw "An identical exception already exists."
        }

        # Add the new exception
        $exceptions += $exception
        $exceptions | ConvertTo-Json -Depth 10 | Set-Content -Path $exceptionsPath

        # RemovalCount logic (optional)
        if ($removalCount) {
            $removalMatches = $dataset | Where-Object {
                $spnMatch = $false
                $azObjectMatch = $false

                if ($exception.spnObjectID) {
                    $spnMatch = ($_.AppObjectID -eq $exception.spnObjectID)
                } elseif ($exception.spnNameLike) {
                    $spnMatch = ($_.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                }

                if ($exception.azObjectScopeID) {
                    $azObjectMatch = ($_.AzureObjectScopeID -eq $exception.azObjectScopeID)
                } elseif (-not $exception.azObjectScopeID -and -not $exception.azObjectNameLike) {
                    $azObjectMatch = $true  # Apply to all objects of the scope type
                } elseif ($exception.azObjectNameLike) {
                    $azObjectMatch = ($_.ObjectName -ilike "*$($exception.azObjectNameLike)*")
                }

                # Check if all criteria match (SPN, Azure object, role, scope type, and tenant)
                $spnMatch -and $azObjectMatch -and
                ($_.PrivRole -eq $exception.role) -and
                ($_.ObjectType -eq $exception.azScopeType) -and
                ($_.Tenant -eq $exception.tenant)
            }

            # Output the number of matches found
            Write-Host "Removal count: $($removalMatches.Count)"
        }
    }
    catch {
        Write-Error "An error occurred: $_"
        throw $_
    }
}
