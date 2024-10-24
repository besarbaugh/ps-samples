<#
.SYNOPSIS
    Adds a new exception to the exceptions.json file after validating the schema and following CSA rules (if enforced).

.DESCRIPTION
    This function adds a new exception to the exceptions.json file. It supports both spnObjectID-based exceptions 
    and spn_name_like patterns, ensuring mutual exclusivity. The function also validates the tenant and spnEonid 
    when adding spn_name_like patterns, and it integrates future support for Custom Security Attributes (CSA) 
    by reading from a config file to determine if CSA is enforced. If CSA is enforced, it will validate against 
    `spnEonid` and `spnEnv` from the `$dataset`. The parameter `OverPrivExceptionCSA` is included for future use 
    when CSAs are fully enforced.

.PARAMETER spnObjectID
    The SPN Object ID for a single SPN-based exception. This is mutually exclusive with spn_name_like.

.PARAMETER spnNameLike
    A wildcard pattern for a name-like SPN exception. This is mutually exclusive with spnObjectID. Requires spnEonid and tenant.

.PARAMETER azScopeType
    The type of Azure scope (MG, RG, Sub). Mandatory for all exceptions.

.PARAMETER PrivRole
    The role being assigned to the SPN (Owner, Contributor, User Access Administrator, or AppDevContributor). Only one role per exception.

.PARAMETER azObjectScopeID
    The ID of the Azure object (e.g., RG, Sub, MG) for specific object exceptions. Mutually exclusive with azObjectNameLike.

.PARAMETER azObjectNameLike
    A wildcard pattern for an Azure object name. Mutually exclusive with azObjectScopeID.

.PARAMETER spnEonid
    The EonID for the SPN, required for spn_name_like patterns.

.PARAMETER tenant
    The tenant identifier. Accepted values: "TENANT_A", "TENANT_B", "TENANT_C". Translated to those tenant names in the exceptions.json file.

.PARAMETER SecArch
    The SecArch approval identifier. Automatically has a 'date added'. Mutually exclusive with ActionPlan.

.PARAMETER ActionPlan
    The ActionPlan identifier. Automatically has a 'date added' and requires an expiration date. Mutually exclusive with SecArch.

.PARAMETER expiration_date
    The expiration date for the ActionPlan (required if ActionPlan is provided). Format: mm/dd/yyyy.

.PARAMETER OverPrivExceptionCSA
    A future parameter that will eventually replace spn_name_like for CSA-based exceptions (currently not in use).

.PARAMETER exceptionsPath
    The file path for the exceptions.json file. Defaults to the path specified in config.json.

.PARAMETER datasetPath
    The file path for the dataset (CSV). Defaults to the path specified in config.json.

.PARAMETER removalCount
    Optional switch to output the count of how many items would be removed from the dataset based on this new exception.
#>

function Add-Exception {
    param(
        [Parameter(Mandatory=$false)][string]$spnObjectID,  # Used for single SPN pattern
        [Parameter(Mandatory=$false)][string]$spnNameLike,  # Used for name-like SPNs
        [Parameter(Mandatory=$true)][ValidateSet('MG', 'RG', 'Sub')][string]$azScopeType,  # Always required
        [Parameter(Mandatory=$true)][ValidateSet('Owner', 'Contributor', 'User Access Administrator', 'AppDevContributor')][string]$PrivRole,  # Single role per exception
        [Parameter(Mandatory=$false)][string]$azObjectScopeID,  # Used for specific object scope
        [Parameter(Mandatory=$false)][string]$azObjectNameLike,  # Used for name-like objects
        [Parameter(Mandatory=$false)][string]$spnEonid,  # Required for name-like SPNs
        [Parameter(Mandatory=$false)][ValidateSet('1', '2', '3')][string]$tenant,  # Tenant validation, translated to Prod, QA, Dev
        [Parameter(Mandatory=$false)][string]$SecArch,  # Mutually exclusive with ActionPlan
        [Parameter(Mandatory=$false)][string]$ActionPlan,  # Mutually exclusive with SecArch
        [Parameter(Mandatory=$false)][datetime]$expiration_date,  # Required for ActionPlan
        [Parameter(Mandatory=$false)][string]$OverPrivExceptionCSA,  # Placeholder for future CSA-based parameter
        [Parameter(Mandatory=$false)][string]$exceptionsPath,  # File path for exceptions.json
        [Parameter(Mandatory=$false)][string]$datasetPath  # Dataset path (optional, default to config.json)
    )

    # Start of error handling block
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
            # Load dataset using the Get-Dataset function (defined elsewhere)
            $dataset = Get-Dataset -datasetDir $config.datasetDir -filenamePattern $config.filenamePattern
        } else {
            $dataset = Import-Csv -Path $datasetPath
        }

        # Check if CSA is enforced
        $csaEnforced = $config.csaEnforced

        # Validate mutually exclusive parameters
        if ($spnObjectID -and $spnNameLike) {
            throw "Cannot use both spnObjectID and spnNameLike at the same time."
        }

        if ($azObjectScopeID -and $azObjectNameLike) {
            throw "Cannot use both azObjectScopeID and azObjectNameLike at the same time."
        }

        # Validate tenant translation
        if ($spnNameLike) {
            if (-not $tenant) {
                throw "Tenant is required when using spnNameLike."
            }
            if (-not $spnEonid) {
                throw "spnEonid is required when using spnNameLike."
            }

            # Translate tenant values to Prod, QA, Dev
            switch ($tenant) {
                '1' { $tenant = 'Prod' }
                '2' { $tenant = 'QA' }
                '3' { $tenant = 'Dev' }
            }

            # If CSA is enforced, validate spnEonid and spnEnv against $dataset
            if ($csaEnforced -eq $true) {
                if (-not ($dataset | Where-Object { $_.spnEonid -eq $spnEonid })) {
                    throw "Invalid spnEonid. The EonID does not match any CSA data in the dataset."
                }
            }
        }

        # Ensure only SecArch or ActionPlan is provided
        if ($SecArch -and $ActionPlan) {
            throw "Cannot have both SecArch and ActionPlan."
        }

        # Ensure expiration_date is provided if ActionPlan is used
        if ($ActionPlan -and -not $expiration_date) {
            throw "ActionPlan requires an expiration date."
        }

        # Initialize 'date added' for SecArch or ActionPlan
        $dateAdded = Get-Date -Format "MM/dd/yyyy"
        $exception = @{}

        if ($SecArch) {
            $exception.SecArch = $SecArch
            $exception.date_added = $dateAdded
        } elseif ($ActionPlan) {
            $exception.ActionPlan = $ActionPlan
            $exception.date_added = $dateAdded
            $exception.expiration_date = $expiration_date
        }

        # Construct the exception object
        $exception.az_scope_type = $azScopeType
        $exception.PrivRole = $PrivRole

        if ($spnObjectID) {
            $exception.spn_object_id = $spnObjectID
        } elseif ($spnNameLike) {
            $exception.spn_name_like = $spnNameLike
            $exception.spn_eonid = $spnEonid
            $exception.tenant = $tenant  # Store translated tenant (Prod, QA, Dev)
        }

        if ($azObjectScopeID) {
            $exception.azObjectScopeID = $azObjectScopeID
        } elseif ($azObjectNameLike) {
            $exception.azObjectNameLike = $azObjectNameLike
        }

        # Check if the exceptions.json file exists, create if it does not
        if (-not (Test-Path -Path $exceptionsPath)) {
            # Initialize the exceptions.json file with an empty array
            "[]" | Set-Content -Path $exceptionsPath
        }

        # Read existing exceptions
        $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json

        # Add the new exception to the list
        $exceptions += $exception

        # Write the updated exceptions back to the file
        $exceptions | ConvertTo-Json | Set-Content -Path $exceptionsPath
    }
    catch {
        Write-Error "An error occurred: $_"
        throw $_  # Rethrow the exception to propagate it further
    }
}
