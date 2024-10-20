#region Add-Exception
function Add-Exception {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$spn_object_id,  # Optional if spnNameLike is provided

        [Parameter(Mandatory = $false)]
        [array]$spnNameLike = @(),  # Wildcard matching for names (default to empty array)

        [Parameter(Mandatory = $true)]
        [array]$roles,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$SecArch = $null,  # Not mandatory, can be null

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$ActionPlan = $null,  # Not mandatory, can be null

        [Parameter(Mandatory = $false)]
        [string]$spnEnv,  # Will be converted to lowercase

        [Parameter(Mandatory = $true)]
        [string]$spn_eonid,

        [string]$azureObjectEnv,  # Will be converted to lowercase

        [string]$AzScope_eonid,  # Only required for resource groups

        [ValidateSet("managementGroup", "subscription", "resourceGroup")]
        [Parameter(Mandatory = $true)]
        [string]$azScopeType,  # Added as a mandatory parameter

        [array]$azureObjectNameLike = @()  # Will have * added to either side (default to empty array)
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
    if ($spn_object_id -and $spnNameLike) {
    throw "cannot have both spnNameLike and spn_obj_id"}

    # Prepare name-like fields with wildcards
    $spnNameLikeWildcard = $spnNameLike | ForEach-Object { "*$_*" }
    $azureObjectNameLikeWildcard = $azureObjectNameLike | ForEach-Object { "*$_*" }

    # Build the new exception object with CSA and other fields
    $newException = [pscustomobject]@{
        spn_object_id       = $spn_object_id
        roles               = $roles | ForEach-Object { $_.ToLower() }  # Convert roles to lowercase
        spnEnv              = $spnEnv.ToLower()  # Convert spnEnv to lowercase
        spn_eonid           = $spn_eonid
        azureObjectEnv      = $azureObjectEnv.ToLower()  # Convert azureObjectEnv to lowercase
        AzScope_eonid       = if ($AzScope_eonid) { $AzScope_eonid } else { $null }
        spnNameLike         = $spnNameLikeWildcard
        azureObjectNameLike = $azureObjectNameLikeWildcard
        SecArch             = $SecArch
        ActionPlan          = $ActionPlan
        azScopeType         = $azScopeType  # Store the validated scope type
    }

    # Add the new exception to the list
    $existingExceptions += $newException  # This should not cause op_addition error

    # Write the updated list back to the JSON file in a scalable format
    $existingExceptions | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonFilePath

    Write-Host "Exception successfully added and stored in $jsonFilePath."
}
#endregion
