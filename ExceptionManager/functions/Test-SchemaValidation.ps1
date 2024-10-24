<#
.SYNOPSIS
    Validates the schema of an exception object.

.DESCRIPTION
    This function validates the schema of an exception object based on the specified fields, including handling of SPN object ID,
    spn_name_like, SecArch, ActionPlan, and CSA enforcement rules. It ensures that required fields are present and mutually exclusive
    fields are not used together. If CSA enforcement is enabled, it checks the spnEonid against the dataset.

.PARAMETER exception
    The exception object to validate. It should be a hashtable or a PSCustomObject with fields like spn_object_id, spn_name_like, 
    az_scope_type, PrivRole, and others.

.PARAMETER dataset
    The dataset (e.g., imported from a CSV file) that contains data for validating spnEonid and other fields when CSA is enforced. 
    This is only required if CSA enforcement is enabled.

.EXAMPLE
    # Validate an exception with an SPN object ID
    $exception = @{
        spn_object_id = "1234"
        az_scope_type = "RG"
        PrivRole = "Owner"
        SecArch = "ARCH1234"
    }
    Test-SchemaValidation -exception $exception

.EXAMPLE
    # Validate an exception with spn_name_like and CSA enforcement
    $exception = @{
        spn_name_like = "*SampleApp*"
        az_scope_type = "MG"
        PrivRole = "Contributor"
        spn_eonid = "EON5678"
        tenant = "QA"
    }
    Test-SchemaValidation -exception $exception -dataset $dataset

.NOTES
    Author: Brian Sarbaugh
    Version: 1.2.0
#>

function Test-SchemaValidation {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$exception,

        [Parameter(Mandatory=$false)]
        [array]$dataset
    )

    # Explicit type checking to prevent issues
    if (-not ($exception -is [hashtable] -or $exception -is [pscustomobject])) {
        throw "The exception parameter must be a hashtable or a PSCustomObject."
    }

    # Load configuration settings from config.json for CSA enforcement
    $configPath = Join-Path $PSScriptRoot "config.json"
    if (-not (Test-Path -Path $configPath)) {
        throw "config.json not found. Please ensure the configuration file is present."
    }

    $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
    $csaEnforced = $config.csaEnforced

    # Optional logging for troubleshooting or debugging
    Write-Verbose "Starting schema validation."

    # Validate that either spn_object_id or spn_name_like is provided, but not both
    if (-not $exception.spn_object_id -and -not $exception.spn_name_like) {
        throw "Either spn_object_id or spn_name_like must be provided."
    }

    if ($exception.spn_object_id -and $exception.spn_name_like) {
        throw "Cannot use both spn_object_id and spn_name_like at the same time."
    }

    # Validate the Azure scope type (RG, MG, Sub)
    if (-not $exception.az_scope_type) {
        throw "az_scope_type is required (RG, MG, or Sub)."
    }

    # Validate that a role is provided and matches the allowed roles
    $allowedRoles = @('Owner', 'Contributor', 'User Access Administrator', 'AppDevContributor')
    if (-not $exception.PrivRole -or ($exception.PrivRole -notin $allowedRoles)) {
        throw "Invalid PrivRole '$($exception.PrivRole)'. Allowed roles are: Owner, Contributor, User Access Administrator, AppDevContributor."
    }

    # Validate SecArch and ActionPlan - cannot both be provided
    if ($exception.SecArch -and $exception.ActionPlan) {
        throw "Cannot have both SecArch and ActionPlan."
    }

    # If ActionPlan is provided, ensure expiration_date is also provided
    if ($exception.ActionPlan -and -not $exception.expiration_date) {
        throw "ActionPlan requires an expiration date."
    }

    # If spn_name_like is used, spnEonid and tenant must be provided
    if ($exception.spn_name_like) {
        if (-not $exception.spn_eonid) {
            throw "spnEonid is required when using spn_name_like."
        }
        if (-not $exception.tenant) {
            throw "tenant is required when using spn_name_like."
        }
    }

    # CSA enforcement: validate spnEonid and spnEnv against the dataset if CSA is enabled
    if ($csaEnforced -eq $true -and $exception.spn_name_like) {
        if (-not $dataset) {
            throw "Dataset is required for CSA validation."
        }

        # Validate spnEonid in dataset
        Test-CSA -exception $exception -dataset $dataset
    }

    Write-Verbose "Schema validation completed successfully."
    return $true
}

function Test-CSA {
    param (
        [hashtable]$exception,
        [array]$dataset
    )

    # Validate spnEonid against dataset
    if (-not ($dataset | Where-Object { $_.AppEonid -eq $exception.spn_eonid })) {
        throw "Invalid spnEonid. The EonID does not match any CSA data in the dataset."
    }

    return $true
}
