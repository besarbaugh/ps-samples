#region Test-DateFormat
<#
.SYNOPSIS
    Tests a date input to ensure it matches the required format 'yyyy-MM-dd'.

.DESCRIPTION
    The Test-DateFormat function checks whether a provided date string is in the 'yyyy-MM-dd' format. It attempts to parse the date to confirm that it is valid. If the date format is incorrect or the date is invalid, the function returns false and provides a descriptive error message. Otherwise, it returns true.

.PARAMETER date
    A string parameter representing the date string to be validated. The date should be in the 'yyyy-MM-dd' format.

.EXAMPLE
    PS C:\> Test-DateFormat -date "2024-10-21"
    True

    This example tests a date in the correct 'yyyy-MM-dd' format and returns true.

.EXAMPLE
    PS C:\> Test-DateFormat -date "2024-02-30"
    Invalid date format: '2024-02-30' is not a valid date.
    False

    This example attempts to test a date that doesn't exist, resulting in an error message and false being returned.

.EXAMPLE
    PS C:\> Test-DateFormat -date "10-21-2024"
    Date format should be yyyy-MM-dd.
    False

    This example attempts to test a date in an incorrect format, resulting in an error message and false being returned.

.EXAMPLE
    PS C:\> Test-DateFormat -date ""
    Date format should be yyyy-MM-dd.
    False

    This example attempts to test an empty date string, resulting in an error message and false being returned.

.NOTES
    Author: Brian Sarbaugh
    Created On: 2024-10-21
    Purpose: To provide consistent and reliable testing for date fields across different functions, such as schema validation and Add-Exception.

.LINK
    https://docs.microsoft.com/en-us/powershell/scripting/overview
#>
function Test-DateFormat {
    param (
        [string]$date
    )

    # Check if the date is empty
    if ([string]::IsNullOrWhiteSpace($date)) {
        Write-Host "Date format should be yyyy-MM-dd."
        return $false
    }

    # Check if the date matches the yyyy-MM-dd format
    if ($date -match '^\d{4}-\d{2}-\d{2}$') {
        try {
            [DateTime]::ParseExact($date, "yyyy-MM-dd", [CultureInfo]::InvariantCulture) | Out-Null
            return $true
        } catch {
            Write-Host "Invalid date format: '$date' is not a valid date."
            return $false
        }
    } else {
        Write-Host "Date format should be yyyy-MM-dd."
        return $false
    }
}
#endregion

#region Test-SchemaValidation
<#
.SYNOPSIS
    Validates the exception schema, including custom security attributes (CSA) and conditions for `AzScope_eonid` at the resource group level.

.DESCRIPTION
    This function validates the structure of an exception object, ensuring that required fields are present, CSA fields are properly formatted, and `AzScope_eonid` is validated when the scope type is a resource group (RG). It also ensures that either SecArch or ActionPlan is provided but not both, and validates dates using the `Test-DateFormat` function.

.PARAMETER exception
    The exception object to be validated.

.EXAMPLE
    PS C:\> Test-SchemaValidation -exception $exception
    Schema validation passed.

.NOTES
    Author: Brian Sarbaugh
    Created On: 2024-10-21
    Purpose: To validate that exceptions conform to the required schema before being processed or added.

.LINK
    https://docs.microsoft.com/en-us/powershell/scripting/overview
#>

#region Load-Config
function Get-Config {
    param(
        [string]$configPath = ".\config.json"   
    )
    if (Test-Path $configPath) {
        $config = Get-Content -Path $configPath | ConvertFrom-Json
        return $config
    } else {
        throw "Configuration file not found."
    }
}
#endregion

#region Add-Exception with CSA and Scalable JSON Storage
<#
.SYNOPSIS
    Adds an exception to a JSON file, supporting dynamic/non-dynamic scenarios, SecArch or ActionPlan, and custom security attributes (CSA).

.DESCRIPTION
    This function adds an exception for either a dynamic or non-dynamic service principal or Azure scope. It handles SecArch or ActionPlan and incorporates CSA fields (spnEnv, spn_eonid, azureObjectEnv, and AzScope_eonid).
    The function ensures data is written to a JSON file in a scalable format for mid- to long-term storage.

.PARAMETER spn_object_id
    The object ID of the service principal. Required for all exceptions.

.PARAMETER roles
    An array of roles (e.g., 'Owner', 'Contributor', 'User Access Administrator'). Required for all exceptions.

.PARAMETER dynamic_spn
    A boolean indicating if the SP is dynamic. Optional for dynamic exceptions.

.PARAMETER dynamic_az_scope
    A boolean indicating if the Azure scope is dynamic. Optional for dynamic exceptions.

.PARAMETER SecArch
    The SecArch details, including ID and date_added. This is required if no ActionPlan is provided.

.PARAMETER ActionPlan
    The ActionPlan details, including ID, date_added, and expiration_date. This is required if no SecArch is provided.

.PARAMETER spnEnv
    The environment of the SP, derived from custom security attributes (CSA).

.PARAMETER spn_eonid
    The EonID of the SP, derived from CSA.

.PARAMETER azureObjectEnv
    The environment of the Azure object (RG, subscription, etc.), derived from CSA.

.PARAMETER AzScope_eonid
    The EonID for the Azure scope, derived from CSA, only applicable to resource groups.

.PARAMETER spnNameLike
    Wildcard patterns for matching SPNs by name.

.PARAMETER azureObjectNameLike
    Wildcard patterns for matching Azure objects by name.

.EXAMPLE
    PS C:\> Add-Exception -spn_object_id "abc123" -roles @("Owner") -dynamic_spn $true -SecArch @{ id="sec-001"; date_added="2024-10-21" } -spnEnv "Prod" -spn_eonid "eon-001" -jsonFilePath ".\exceptions.json"

    This example adds a dynamic SP exception with SecArch details and CSA information to the JSON file.
#>
function Add-Exception {
    [CmdletBinding(DefaultParameterSetName = "Dynamic")]
    param (
        # Required for all cases
        [Parameter(Mandatory = $true)]
        [string]$spn_object_id,

        [Parameter(Mandatory = $true)]
        [array]$roles,

        # Dynamic or Non-Dynamic (both optional)
        [Parameter(ParameterSetName = "Dynamic")]
        [bool]$dynamic_spn,

        [Parameter(ParameterSetName = "Dynamic")]
        [bool]$dynamic_az_scope,

        # SecArch ParameterSet
        [Parameter(Mandatory = $true, ParameterSetName = "SecArch")]
        [PSCustomObject]$SecArch,

        # ActionPlan ParameterSet
        [Parameter(Mandatory = $true, ParameterSetName = "ActionPlan")]
        [PSCustomObject]$ActionPlan,

        # CSA-based fields
        [Parameter(Mandatory = $true)]
        [string]$spnEnv,

        [Parameter(Mandatory = $true)]
        [string]$spn_eonid,

        [string]$azureObjectEnv,

        [string]$AzScope_eonid,  # Only required for resource groups

        # Name-like wildcard patterns
        [array]$spnNameLike,

        [array]$azureObjectNameLike
    )

    # Load configuration settings
    $config = Get-Config
    $jsonFilePath = $config.jsonFilePath

    # Load existing exceptions from the JSON file
    if (Test-Path $jsonFilePath) {
        $existingExceptions = Get-Content -Path $jsonFilePath | ConvertFrom-Json
    } else {
        $existingExceptions = @() # Create an empty array if the file does not exist
    }

    # Ensure that only SecArch or ActionPlan is provided
    if ($SecArch -and $ActionPlan) {
        throw "Cannot have both SecArch and ActionPlan."
    }

    # Build the new exception object with CSA and other fields
    $newException = [pscustomobject]@{
        spn_object_id       = $spn_object_id
        roles               = $roles
        dynamic_spn         = $dynamic_spn
        dynamic_az_scope    = $dynamic_az_scope
        spnEnv              = $spnEnv
        spn_eonid           = $spn_eonid
        azureObjectEnv      = $azureObjectEnv
        AzScope_eonid       = if ($AzScope_eonid) { $AzScope_eonid } else { $null }
        spnNameLike         = $spnNameLike
        azureObjectNameLike = $azureObjectNameLike
        SecArch             = $SecArch
        ActionPlan          = $ActionPlan
    }

    # Add the new exception to the list
    $existingExceptions += $newException

    # Write the updated list back to the JSON file in a scalable format
    $existingExceptions | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonFilePath

    Write-Host "Exception successfully added and stored in $jsonFilePath."
}
#endregion
