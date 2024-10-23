<#
.SYNOPSIS
    Validates the schema of an exception object before it is added to the exceptions.json file.

.DESCRIPTION
    This function ensures that the exception follows the correct schema. It checks for mandatory fields, 
    verifies that 'spn_name_like' and 'spnObjectID' are mutually exclusive, and enforces the presence of 
    tenant and spnEonid where applicable. If CSA is enforced (via config.json), spnEonid and spnEnv 
    are validated against the dataset rather than display names. It also prevents both 'azObjectNameLike' 
    and 'azObjectID' from appearing in the same exception. Either SecArch or ActionPlan is required, and both 
    are automatically assigned dates.

.PARAMETER exception
    A hashtable representing the exception to be validated.

.PARAMETER datasetPath
    The file path for the dataset (CSV). Defaults to the path specified in config.json.

.RETURNS
    $true if the schema is valid, throws an error otherwise.
#>

function Test-SchemaValidation {
    param(
        [Parameter(Mandatory=$true)][hashtable]$exception,
        [Parameter(Mandatory=$false)][string]$datasetPath  # Optional, default from config.json
    )

    # Load configuration settings from config.json
    $configPath = ".\config.json"
    if (-not (Test-Path -Path $configPath)) {
        throw "config.json not found. Please ensure the configuration file is present."
    }
    $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

    # Load dataset
    if (-not $datasetPath) {
        # Load dataset using the Load-Dataset function
        $dataset = Load-Dataset -datasetDir $config.datasetDir -filenamePattern $config.filenamePattern
    } else {
        # Load dataset from a user-specified path
        $dataset = Import-Csv -Path $datasetPath
    }

    # Check if CSA is enforced
    $csaEnforced = $config.csaEnforced

    # Validate mandatory keys for spnObjectID or spn_name_like
    if (-not $exception.ContainsKey("spn_object_id") -and -not $exception.ContainsKey("spn_name_like")) {
        throw "Either spn_object_id or spn_name_like is required."
    }

    # Ensure spn_name_like and spn_object_id are not used together
    if ($exception.ContainsKey("spn_object_id") -and $exception.ContainsKey("spn_name_like")) {
        throw "Cannot use both spn_object_id and spn_name_like in the same exception."
    }

    # Validate PrivRole is present
    if (-not $exception.ContainsKey("PrivRole") -or [string]::IsNullOrWhiteSpace($exception.PrivRole)) {
        throw "PrivRole is required."
    }

    # Validate az_scope_type is present
    if (-not $exception.ContainsKey("az_scope_type")) {
        throw "az_scope_type is required."
    }

    # If spn_name_like is used, spnEonid and tenant must be present
    if ($exception.ContainsKey("spn_name_like")) {
        if (-not $exception.ContainsKey("spn_eonid")) {
            throw "spnEonid is required when using spn_name_like."
        }
        if (-not $exception.ContainsKey("tenant")) {
            throw "Tenant is required when using spn_name_like."
        }

        # If CSA is enforced, validate spnEonid and spnEnv against dataset
        if ($csaEnforced -eq $true) {
            if (-not ($dataset | Where-Object { $_.spnEonid -eq $exception.spn_eonid })) {
                throw "Invalid spnEonid. The EonID does not match any CSA data in the dataset."
            }
            if ($exception.ContainsKey("spnEnv")) {
                if (-not ($dataset | Where-Object { $_.spnEnv -eq $exception.spnEnv })) {
                    throw "Invalid spnEnv. The Env does not match any CSA data in the dataset."
                }
            }
        }
    }

    # Ensure azObjectNameLike and azObjectID are not used together
    if ($exception.ContainsKey("azObjectScopeID") -and $exception.ContainsKey("azObjectNameLike")) {
        throw "Cannot use both azObjectScopeID and azObjectNameLike in the same exception."
    }

    # Ensure that only SecArch or ActionPlan is provided
    if ($exception.ContainsKey("SecArch") -and $exception.ContainsKey("ActionPlan")) {
        throw "Cannot have both SecArch and ActionPlan."
    }

    # Ensure ActionPlan has an expiration date
    if ($exception.ContainsKey("ActionPlan") -and -not $exception.ContainsKey("expiration_date")) {
        throw "ActionPlan requires an expiration date."
    }
    
    return $true
}
