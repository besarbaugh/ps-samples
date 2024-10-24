<#
.SYNOPSIS
    Adds a new exception to the exceptions.json file after validating the schema and following CSA rules (if enforced).

.DESCRIPTION
    This function adds a new exception to the exceptions.json file. It supports both spnObjectID-based exceptions 
    and spnNameLike patterns, ensuring mutual exclusivity. The function also validates the tenant and spnEonid 
    when adding spnNameLike patterns. If CSA is enforced, additional checks on spnEonid and spnEnv are performed.
    The function integrates wildcard lookups for AppName patterns and Azure object name patterns.
    It includes an optional 'removalCount' switch to show how many entries from the dataset would be removed by this exception.

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
    The tenant identifier. Accepted values: "prodten", "qaten", "devten". Mandatory for spnNameLike cases.

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

.EXAMPLE
    Add-Exception -spnObjectID "SPN1234" -azScopeType "resourceGroup" -role "Owner"
    
    Adds an exception for a specific SPN object ID, granting Owner role on any resourceGroup. Tenant and spnEonid are derived.

.EXAMPLE
    Add-Exception -spnNameLike "*sampleApp*" -azScopeType "managementGroup" -role "Contributor" -spnEonid "EON123" -tenant "prodten"
    
    Adds an exception for SPNs with a name-like pattern, granting Contributor role on any managementGroup, filtered by spnEonid.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.0.0
#>

function Add-Exception {
    [CmdletBinding(DefaultParameterSetName = 'spnObjectIDSet')]
    param(
        # spnObjectIDSet - Tenant and EonID are derived from dataset
        [Parameter(Mandatory = $true, ParameterSetName = 'spnObjectIDSet')][string]$spnObjectID,

        # spnNameLikeSet - Handles name-like SPN cases, tenant required
        [Parameter(Mandatory = $true, ParameterSetName = 'spnNameLikeSet')][string]$spnNameLike,

        # Mandatory for all parameter sets
        [Parameter(Mandatory = $true)][ValidateSet('managementGroup', 'resourceGroup', 'subscription')][string]$azScopeType,

        [Parameter(Mandatory = $true)][ValidateSet('Owner', 'Contributor', 'User Access Administrator', 'AppDevContributor')][string]$role,

        # These two parameters are mutually exclusive
        [Parameter(Mandatory = $false)][string]$azObjectScopeID,  # Used for specific object scope
        [Parameter(Mandatory = $false)][string]$azObjectNameLike,  # Used for object name-like pattern

        # spnNameLikeSet requires tenant
        [Parameter(Mandatory = $true, ParameterSetName = 'spnNameLikeSet')][ValidateSet('prodten', 'qaten', 'devten')][string]$tenant,

        [Parameter(Mandatory = $false)][string]$spnEonid,  # EonID required for name-like SPNs (if applicable)

        [Parameter(Mandatory = $false)][string]$SecArch,  # Mutually exclusive with ActionPlan
        [Parameter(Mandatory = $false)][string]$ActionPlan,  # Mutually exclusive with SecArch
        [Parameter(Mandatory = $false)][datetime]$expiration_date,  # Required for ActionPlan

        [Parameter(Mandatory = $false)][string]$exceptionsPath,  # File path for exceptions.json
        [Parameter(Mandatory = $false)][string]$datasetPath,  # Dataset path (optional, default to config.json)

        [Parameter(Mandatory = $false)][switch]$removalCount  # Optional switch to count how many entries would be removed by this exception
    )

    try {
        # Load configuration settings from config.json
        $configPath = ".\config.json"
        if (-not (Test-Path -Path $configPath)) {
            throw "config.json not found. Please ensure the configuration file is present."
        }

        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

        # Set the exceptionsPath and datasetPath from config.json if not provided
        if (-not $exceptionsPath) {
            $exceptionsPath = $config.exceptionsPath
        }
        if (-not $datasetPath) {
            $dataset = Get-Dataset -datasetDir $config.datasetDir -filenamePattern $config.filenamePattern
        } else {
            $dataset = Import-Csv -Path $datasetPath
        }

        # Handle spnObjectIDSet (tenant and EonID are derived)
        if ($PSCmdlet.ParameterSetName -eq 'spnObjectIDSet') {
            $spnDetails = $dataset | Where-Object { $_.AppObjectID -ieq $spnObjectID }
            if ($spnDetails) {
                $spnEonid = $spnDetails.AppEonid
                $spnEnv = $spnDetails.AppEnv

                # Parse tenant based on 2nd character of display name section
                $tenantChar = $spnDetails.AppName[2]
                switch ($tenantChar) {
                    '1' { $tenant = 'prodten' }
                    '2' { $tenant = 'qaten' }
                    '3' { $tenant = 'devten' }
                    default { throw "Invalid tenant identifier derived from AppName." }
                }
            } else {
                throw "SPN details could not be found in the dataset for spnObjectID."
            }
        }

        # Handle spnNameLikeSet (wildcard lookup for spnNameLike)
        if ($PSCmdlet.ParameterSetName -eq 'spnNameLikeSet') {
            $matchedSPNs = $dataset | Where-Object { $_.AppName -ilike "*$spnNameLike*" }

            if ($matchedSPNs.Count -eq 1) {
                $spnEonid = $matchedSPNs.AppEonid
                $spnEnv = $matchedSPNs.AppEnv
            }
            elseif ($matchedSPNs.Count -eq 0) {
                throw "No SPN found with AppName matching the spnNameLike pattern."
            }
            else {
                throw "Multiple SPNs found with AppName matching the spnNameLike pattern. Please refine your search."
            }
        }

        # Ensure mutually exclusive parameters
        if ($spnObjectID -and $spnNameLike) {
            throw "Cannot use both spnObjectID and spnNameLike at the same time."
        }
        if ($azObjectScopeID -and $azObjectNameLike) {
            throw "Cannot use both azObjectScopeID and azObjectNameLike at the same time."
        }
        if ($SecArch -and $ActionPlan) {
            throw "Cannot have both SecArch and ActionPlan."
        }
        if ($ActionPlan -and -not $expiration_date) {
            throw "ActionPlan requires an expiration date."
        }

        # Initialize the exception object
        $exception = @{
            azScopeType = $azScopeType
            role = $role
            tenant = $tenant
            spnEonid = $spnEonid  # Ensure spnEonid is always included in the exception
            date_added = (Get-Date).ToString('MM/dd/yyyy')
        }

        if ($spnObjectID) { $exception.spn_object_id = $spnObjectID }
        if ($spnNameLike) { $exception.spn_name_like = $spnNameLike }
        if ($azObjectScopeID) { $exception.azObjectScopeID = $azObjectScopeID }
        if ($azObjectNameLike) { $exception.azObjectNameLike = $azObjectNameLike }
        if ($SecArch) { $exception.SecArch = $SecArch }
        if ($ActionPlan) { 
            $exception.ActionPlan = $ActionPlan 
            $exception.expiration_date = $expiration_date 
        }

        # Check if the exceptions.json file exists, create if it does not
        if (-not (Test-Path -Path $exceptionsPath)) {
            "[]" | Set-Content -Path $exceptionsPath
        }

        # Read existing exceptions and add new exception
        $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
        $exceptions += $exception
        $exceptions | ConvertTo-Json -Depth 10 | Set-Content -Path $exceptionsPath

        # RemovalCount logic
        if ($removalCount) {
            $removalMatches = $dataset | Where-Object {
                ($_.AppObjectID -eq $exception.spn_object_id -or $_.AppName -ilike "*$exception.spn_name_like*") -and
                ($_.AzureObjectScopeID -eq $exception.azObjectScopeID -or $_.ObjectName -ilike "*$exception.azObjectNameLike*") -and
                ($_.PrivRole -eq $exception.role) -and
                ($_.ObjectType -eq $exception.azScopeType) -and
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
