<#
.SYNOPSIS
    Validates the schema of an exception to ensure all required fields and logic are correct.

.DESCRIPTION
    This function validates an exception schema, ensuring mandatory fields are present and mutually exclusive fields
    like spnObjectID and spnNameLike, azObjectScopeID and azObjectNameLike, and SecArch and ActionPlan are handled properly.

.PARAMETER exception
    The exception hashtable to validate.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.0.1
    Throws errors if the schema validation fails.

.EXAMPLE
    $exception = @{
        spnObjectID = "SPN1234"
        azScopeType = "resourceGroup"
        role = "Owner"
        tenant = "prodten"
    }
    Test-SchemaValidation -exception $exception
#>

function Test-SchemaValidation {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$exception
    )

    # Validate mandatory fields for spnObjectID or spnNameLike based on the parameter set
    if (-not $exception.spnObjectID -and -not $exception.spnNameLike) {
        throw "Either spnObjectID or spnNameLike must be provided."
    }

    # Ensure mutually exclusive fields
    if ($exception.spnObjectID -and $exception.spnNameLike) {
        throw "spnObjectID and spnNameLike cannot be used together."
    }

    if ($exception.azObjectScopeID -and $exception.azObjectNameLike) {
        throw "azObjectScopeID and azObjectNameLike cannot be used together."
    }

    if ($exception.SecArch -and $exception.ActionPlan) {
        throw "SecArch and ActionPlan cannot be used together."
    }

    # Check required fields for spnNameLike set
    if ($exception.spnNameLike) {
        if (-not $exception.spnEonid) {
            throw "spnEonid is required when using spnNameLike."
        }
        if (-not $exception.tenant) {
            throw "Tenant is required when using spnNameLike."
        }
    }

    # Validate azScopeType
    if (-not ($exception.azScopeType -in @('managementGroup', 'resourceGroup', 'subscription'))) {
        throw "Invalid azScopeType. Must be 'managementGroup', 'resourceGroup', or 'subscription'."
    }

    # Validate role
    if (-not ($exception.role -in @('Owner', 'Contributor', 'User Access Administrator', 'AppDevContributor'))) {
        throw "Invalid role. Must be 'Owner', 'Contributor', 'User Access Administrator', or 'AppDevContributor'."
    }

    # Validate expiration_date for ActionPlan
    if ($exception.ActionPlan -and -not $exception.expiration_date) {
        throw "ActionPlan requires an expiration date."
    }
    elseif ($exception.expiration_date -and -not ([datetime]::TryParse($exception.expiration_date, [ref]$null))) {
        throw "expiration_date must be a valid date in the format 'mm/dd/yyyy'."
    }

    # Everything passed, return success
    Write-Host "Schema validation passed."
}
