function Test-ExceptionSchema {
    <#
    .SYNOPSIS
        Validates an exception against the predefined schema.

    .DESCRIPTION
        This function validates that the given exception adheres to the required schema, checking for required fields,
        correct data types, and allowed values. It also checks that the SPN Department ID and Container Department ID are present when required.

    .PARAMETER Exception
        A hashtable representing the exception to validate.

    .EXAMPLE
        PS C:\> Test-ExceptionSchema -Exception $newException

        Validates the $newException object against the schema.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Exception
    )

    $validationErrors = @()

    # Convert keys to lowercase to ensure case insensitivity
    $Exception = $Exception | ForEach-Object { $_.PSObject.Properties.Name = $_.PSObject.Properties.Name.ToLower(); $_ }

    # Required field check for SPNdeptID
    if (-not $Exception.ContainsKey("spndeptid")) {
        $validationErrors += "Missing required field: SPNdeptID."
    }

    # Required field check for other fields
    if (-not $Exception.ContainsKey("containertype")) {
        $validationErrors += "Missing required field: containertype."
    }
    if (-not $Exception.ContainsKey("role")) {
        $validationErrors += "Missing required field: role."
    }
    if (-not $Exception.ContainsKey("environment")) {
        $validationErrors += "Missing required field: environment."
    }
    if (-not $Exception.ContainsKey("dynamic")) {
        $validationErrors += "Missing required field: dynamic."
    }
    if (-not $Exception.ContainsKey("dynamic_scope")) {
        $validationErrors += "Missing required field: dynamic_scope."
    }
    if (-not $Exception.ContainsKey("exception_type")) {
        $validationErrors += "Missing required field: exception_type."
    }

    # If TakeAwayID is present, expiration_date must be present
    if ($Exception.ContainsKey("takeawayid") -and -not $Exception.ContainsKey("expiration_date")) {
        $validationErrors += "TakeAwayID is present, but expiration_date is missing."
    }

    # If both SPNdeptID and containerdeptid are present, ensure they match (if required)
    if ($Exception.ContainsKey("spndeptid") -and $Exception.ContainsKey("containerdeptid")) {
        if ($Exception.spndeptid -ne $Exception.containerdeptid) {
            $validationErrors += "SPNdeptID and ContainerDeptID do not match."
        }
    }

    # Enum validation for certain fields
    $validContainerTypes = @("rg", "sub", "mg")
    if ($Exception.containertype -and !($validContainerTypes -contains $Exception.containertype)) {
        $validationErrors += "Field containertype contains invalid values. Allowed values are 'RG', 'sub', 'MG'."
    }

    $validRoles = @("uaa", "owner", "contributor")
    if ($Exception.role -and !($validRoles -contains $Exception.role)) {
        $validationErrors += "Field role contains invalid values. Allowed values are 'UAA', 'owner', 'contributor'."
    }

    $validEnvironments = @("prod", "qa", "uat", "dev")
    if ($Exception.environment -and !($validEnvironments -contains $Exception.environment)) {
        $validationErrors += "Field environment contains invalid values. Allowed values are 'Prod', 'QA', 'UAT', 'Dev'."
    }

    # Return validation results
    if ($validationErrors.Count -eq 0) {
        Write-Host "Validation passed."
        return $true
    } else {
        Write-Host "Validation failed with errors:"
        $validationErrors | ForEach-Object { Write-Host $_ }
        return $false
    }
}
