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
#region Add-Exception
function Add-Exception {
    [CmdletBinding(DefaultParameterSetName = "Dynamic")]
    param (
        [Parameter(Mandatory = $true)]
        [string]$spn_object_id,

        [Parameter(Mandatory = $true)]
        [array]$roles,

        [Parameter(ParameterSetName = "Dynamic")]
        [bool]$dynamic_spn,

        [Parameter(ParameterSetName = "Dynamic")]
        [bool]$dynamic_az_scope,

        [Parameter(Mandatory = $true, ParameterSetName = "SecArch")]
        [PSCustomObject]$SecArch,

        [Parameter(Mandatory = $true, ParameterSetName = "ActionPlan")]
        [PSCustomObject]$ActionPlan,

        [Parameter(Mandatory = $true)]
        [string]$spnEnv,  # Will be converted to lowercase

        [Parameter(Mandatory = $true)]
        [string]$spn_eonid,

        [string]$azureObjectEnv,  # Will be converted to lowercase

        [string]$AzScope_eonid,  # Only required for resource groups

        [array]$spnNameLike,  # Will have * added to either side
        [array]$azureObjectNameLike  # Will have * added to either side
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

    # Prepare name-like fields with wildcards
    $spnNameLikeWildcard = $spnNameLike | ForEach-Object { "*$_*" }
    $azureObjectNameLikeWildcard = $azureObjectNameLike | ForEach-Object { "*$_*" }

    # Build the new exception object
    $newException = [pscustomobject]@{
        spn_object_id       = $spn_object_id
        roles               = $roles | ForEach-Object { $_.ToLower() }  # Convert roles to lowercase
        dynamic_spn         = $dynamic_spn
        dynamic_az_scope    = $dynamic_az_scope
        spnEnv              = $spnEnv.ToLower()  # Convert spnEnv to lowercase
        spn_eonid           = $spn_eonid
        azureObjectEnv      = $azureObjectEnv.ToLower()  # Convert azureObjectEnv to lowercase
        AzScope_eonid       = if ($AzScope_eonid) { $AzScope_eonid } else { $null }
        spnNameLike         = $spnNameLikeWildcard
        azureObjectNameLike = $azureObjectNameLikeWildcard
        SecArch             = $SecArch
        ActionPlan          = $ActionPlan
    }

    # Rename properties for JSON output
    if ($newException.AzureScope_eonid -ne $null) {
        $newException.AzureScope_eonid = $newException.AzureScope_eonid
    }

    # Determine the correct type for JSON output
    if ($newException.spn_object_id -like "*/") {
        $newException.ObjectType = "resourceGroup"  # or "subscription" based on your context
    } elseif ($newException.spn_object_id -like "*/managementGroups/*") {
        $newException.ObjectType = "managementGroup"
    } else {
        $newException.ObjectType = "subscription"
    }

    # Add the new exception to the list
    $existingExceptions += $newException

    # Write the updated list back to the JSON file in a scalable format
    $existingExceptions | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonFilePath

    Write-Host "Exception successfully added and stored in $jsonFilePath."
}
#endregion
