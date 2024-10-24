<#
.SYNOPSIS
    Adds a new exception to the exceptions.json file after validating the schema and preventing duplicates.

.DESCRIPTION
    This function adds a new exception to the exceptions.json file after validating its schema. It supports both 
    spnObjectID-based exceptions and spnNameLike patterns, ensuring mutual exclusivity. The function validates the 
    tenant and spnEonid when adding spnNameLike patterns. Wildcard lookups for AppDisplayName and AzureObjectName 
    are supported. The function also prevents exact duplicate exceptions from being added to the exceptions.json file.

.PARAMETER spnObjectID
    The SPN Object ID for a single SPN-based exception. This is mutually exclusive with spnNameLike.

.PARAMETER spnNameLike
    A wildcard pattern for a name-like SPN exception. This is mutually exclusive with spnObjectID. Requires spnEonid.

.PARAMETER azScopeType
    The type of Azure scope (managementGroup, resourceGroup, subscription). Mandatory for all exceptions.

.PARAMETER role
    The role being assigned to the SPN (Owner, Contributor, User Access Administrator, or AppDevContributor). Only one role per exception.

.PARAMETER azObjectScopeID
    The ID of the Azure object (e.g., resourceGroup, subscription, managementGroup) for specific object exceptions. Mutually exclusive with azObjectNameLike.

.PARAMETER azObjectNameLike
    A wildcard pattern for an Azure object name. Mutually exclusive with azObjectScopeID.

.PARAMETER tenant
    The tenant identifier. Accepted values: "prodten", "qaten", "devten". Required if spnNameLike is used.

.PARAMETER spnEonid
    The EonID for the SPN. Required for spnNameLike patterns.

.PARAMETER SecArch
    The SecArch approval identifier. Automatically includes a 'date added'. Mutually exclusive with ActionPlan.

.PARAMETER ActionPlan
    The ActionPlan identifier. Automatically includes a 'date added' and requires an expiration date. Mutually exclusive with SecArch.

.PARAMETER expiration_date
    The expiration date for the ActionPlan (required if ActionPlan is provided). Format: mm/dd/yyyy.

.PARAMETER removalCount
    Optional switch to output the count of how many items would be removed from the dataset based on this new exception.

.PARAMETER exceptionsPath
    The file path for the exceptions.json file. Defaults to the path specified in config.json.

.PARAMETER datasetPath
    The file path for the dataset (CSV). Defaults to the path specified in config.json.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.0.4
    This function prevents the addition of exact duplicate exceptions and validates the schema before adding.

.EXAMPLE
    Add-Exception -spnObjectID "SPN1234" -azScopeType "resourceGroup" -role "Owner"
    
    Adds an exception for a specific SPN object ID, granting Owner role on all resourceGroups. Tenant and spnEonid are derived.

.EXAMPLE
    Add-Exception -spnNameLike "*sampleApp*" -azScopeType "managementGroup" -role "Contributor" -spnEonid "EON123" -tenant "prodten"
    
    Adds an exception for SPNs with a name-like pattern, granting Contributor role on any managementGroup, filtered by spnEonid.
#>

function Add-Exception {
    [CmdletBinding(DefaultParameterSetName = 'spnObjectIDSet')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'spnObjectIDSet')][string]$spnObjectID,
        [Parameter(Mandatory = $true, ParameterSetName = 'spnNameLikeSet')][string]$spnNameLike,
        [Parameter(Mandatory = $true, ParameterSetName = 'spnNameLikeSet')][string]$spnEonid,
        [Parameter(Mandatory = $true, ParameterSetName = 'spnNameLikeSet')][ValidateSet('prodten', 'qaten', 'devten')][string]$tenant,
        [Parameter(Mandatory = $true)][ValidateSet('managementGroup', 'resourceGroup', 'subscription')][string]$azScopeType,
        [Parameter(Mandatory = $true)][ValidateSet('Owner', 'Contributor', 'User Access Administrator', 'AppDevContributor')][string]$role,
        [Parameter(Mandatory = $false)][string]$azObjectScopeID,
        [Parameter(Mandatory = $false)][string]$azObjectNameLike,
        [Parameter(Mandatory = $false)][string]$SecArch,
        [Parameter(Mandatory = $false)][string]$ActionPlan,
        [Parameter(Mandatory = $false)][datetime]$expiration_date,
        [Parameter(Mandatory = $false)][string]$exceptionsPath,
        [Parameter(Mandatory = $false)][string]$datasetPath,
        [Parameter(Mandatory = $false)][switch]$removalCount
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

        # Handle spnObjectID logic
        if ($PSCmdlet.ParameterSetName -eq 'spnObjectIDSet') {
            $spnDetails = $dataset | Where-Object { $_.AppObjectID -ieq $spnObjectID } | Select-Object -First 1
            if ($spnDetails) {
                $spnEonid = $spnDetails.AppEonid
                $tenantChar = $spnDetails.AppDisplayName[2]
                switch ($tenantChar) {
                    'p' { $tenant = 'prodten' }
                    'q' { $tenant = 'qaten' }
                    'd' { $tenant = 'devten' }
                    default { throw "Invalid tenant identifier derived from AppDisplayName." }
                }
            } else {
                throw "SPN details not found for spnObjectID."
            }
        }

        # Handle spnNameLike logic
        if ($PSCmdlet.ParameterSetName -eq 'spnNameLikeSet') {
            $matchedSPNs = $dataset | Where-Object { $_.AppDisplayName -icontains "$spnNameLike" }
            if ($matchedSPNs.Count -eq 0) {
                throw "No SPN found with AppDisplayName matching the spnNameLike pattern."
            }
        }

        # Initialize the exception object
        $exception = @{
            azScopeType = $azScopeType
            role = $role
            tenant = $tenant
            spnEonid = $spnEonid
            date_added = (Get-Date).ToString('MM/dd/yyyy')
        }

        if ($spnObjectID) { $exception.spnObjectID = $spnObjectID }
        if ($spnNameLike) { $exception.spnNameLike = $spnNameLike }
        if ($azObjectScopeID) { $exception.azObjectScopeID = $azObjectScopeID }
        if ($azObjectNameLike) { $exception.azObjectNameLike = $azObjectNameLike }
        if ($SecArch) { $exception.SecArch = $SecArch }
        if ($ActionPlan) {
            $exception.ActionPlan = $ActionPlan
            $exception.expiration_date = $expiration_date
        }

        # Read exceptions and prevent exact duplicates
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

        # RemovalCount logic
        if ($removalCount) {
            $removalMatches = $dataset | Where-Object {
                $spnMatch = $false
                $azObjectMatch = $false

                if ($exception.spnObjectID) {
                    $spnMatch = ($_.AppObjectID -ieq $exception.spnObjectID)
                } elseif ($exception.spnNameLike) {
                    $spnMatch = ($_.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                }

                if ($exception.azObjectScopeID) {
                    $azObjectMatch = ($_.AzureObjectScopeID -eq $exception.azObjectScopeID)
                } elseif (-not $exception.azObjectScopeID -and -not $exception.azObjectNameLike) {
                    # If no azObjectScopeID and no azObjectNameLike, it applies to all objects of the scope
                    $azObjectMatch = $true
                } elseif ($exception.azObjectNameLike) {
                    $azObjectMatch = ($_.ObjectName -ilike "*$($exception.azObjectNameLike)*")
                }

                $spnMatch -and $azObjectMatch -and
                ($_.PrivRole -ieq $exception.role) -and
                ($_.ObjectType -ieq $exception.azScopeType) -and
                ($_.Tenant -ieq $exception.tenant)
            }
            Write-Host "Removal count: $($removalMatches.Count)"
        }
    }
    catch {
        Write-Error "An error occurred: $_"
        throw $_
    }
}
