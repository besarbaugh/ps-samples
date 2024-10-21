<#
.SYNOPSIS
    Matches the given object ID against the exception's object ID.

.DESCRIPTION
    This function checks if the object ID of the outObject matches the object ID specified in the exception.

.PARAMETER ObjectID
    The ID of the current object being checked.

.PARAMETER ExceptionObjectID
    The ID from the exception being compared.

.EXAMPLE
    $match = Match-ByObjectID -ObjectID "12345" -ExceptionObjectID "12345"
    # Returns $true

.NOTES
    Use this function to compare IDs directly.
#>
function Match-ByObjectID {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ObjectID,

        [Parameter(Mandatory = $false)]
        [string]$ExceptionObjectID
    )
    
    return ($ObjectID -eq $ExceptionObjectID)
}

<#
.SYNOPSIS
    Matches the given object name against the exception's name pattern.

.DESCRIPTION
    This function checks if the object name of the outObject matches a name-like pattern specified in the exception.

.PARAMETER ObjectName
    The name of the current object being checked.

.PARAMETER ExceptionNameLike
    A pattern from the exception to match against.

.EXAMPLE
    $match = Match-ByNameLike -ObjectName "Admin-Resource" -ExceptionNameLike "*Admin*"
    # Returns $true

.NOTES
    Use this function to compare object names using wildcard patterns.
#>
function Match-ByNameLike {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ObjectName,

        [Parameter(Mandatory = $false)]
        [string]$ExceptionNameLike
    )

    return ($ExceptionNameLike -and $ObjectName -like $ExceptionNameLike)
}

<#
.SYNOPSIS
    Matches the given EonID against the exception's EonID.

.DESCRIPTION
    This function checks if the EonID of the outObject matches the EonID specified in the exception.

.PARAMETER ObjectEonID
    The EonID of the current object being checked.

.PARAMETER ExceptionEonID
    The EonID from the exception to compare against.

.EXAMPLE
    $match = Match-ByEonID -ObjectEonID "Dept-001" -ExceptionEonID "Dept-001"
    # Returns $true

.NOTES
    Use this function to ensure consistency in EonID comparisons.
#>
function Match-ByEonID {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ObjectEonID,

        [Parameter(Mandatory = $false)]
        [string]$ExceptionEonID
    )

    return ($ExceptionEonID -and $ObjectEonID -eq $ExceptionEonID)
}

<#
.SYNOPSIS
    Matches the given role against the exception's role.

.DESCRIPTION
    This function checks if the role of the outObject matches the role specified in the exception.

.PARAMETER ObjectRole
    The role of the current object being checked.

.PARAMETER ExceptionRole
    The role from the exception to compare against.

.EXAMPLE
    $match = Match-ByRole -ObjectRole "Owner" -ExceptionRole "Owner"
    # Returns $true

.NOTES
    Use this function to ensure consistency in role comparisons.
#>
function Match-ByRole {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ObjectRole,

        [Parameter(Mandatory = $false)]
        [string]$ExceptionRole
    )

    return ($ExceptionRole -and $ObjectRole -eq $ExceptionRole)
}

<#
.SYNOPSIS
    Matches the given environment against the exception's environment.

.DESCRIPTION
    This function checks if the environment of the outObject matches the environment specified in the exception.

.PARAMETER ObjectEnv
    The environment of the current object being checked.

.PARAMETER ExceptionEnv
    The environment from the exception to compare against.

.EXAMPLE
    $match = Match-ByEnvironment -ObjectEnv "Prod" -ExceptionEnv "Prod"
    # Returns $true

.NOTES
    Use this function to ensure consistency in environment comparisons.
#>
function Match-ByEnvironment {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ObjectEnv,

        [Parameter(Mandatory = $false)]
        [string]$ExceptionEnv
    )

    return ($ExceptionEnv -and $ObjectEnv -eq $ExceptionEnv)
}

<#
.SYNOPSIS
    Determines if the given outObject matches any exceptions from the JSON file.

.DESCRIPTION
    This function loads a list of exceptions from a JSON file and applies comprehensive rules to determine if the
    given outObject matches any of these exceptions. It utilizes helper functions for each type of comparison.

.PARAMETER OutObject
    A PowerShell object that represents the current entry being checked.

.PARAMETER ExceptionsFilePath
    The path to the JSON file that contains the list of exceptions.

.EXAMPLE
    $isException = Is-Exception -OutObject $myOutObject -ExceptionsFilePath "C:\path\to\exceptions.json"
    # Returns $true if the outObject matches any exceptions.

.NOTES
    This function combines logic from multiple helper functions to perform a comprehensive check against all exceptions.
#>
function Is-Exception {
    param (
        [Parameter(Mandatory = $true)]
        [pscustomobject]$OutObject,

        [Parameter(Mandatory = $true)]
        [string]$ExceptionsFilePath
    )

    # Load exceptions from the JSON file
    $exceptions = @()
    if (Test-Path $ExceptionsFilePath) {
        $exceptions = Get-Content -Path $ExceptionsFilePath -Raw | ConvertFrom-Json
    }

    # Loop through each exception and apply comprehensive rules for comparison
    foreach ($exception in $exceptions) {
        # Initialize match status
        $isMatch = $false

        # Apply individual match checks based on schema logic
        if (Match-ByObjectID -ObjectID $OutObject.AppObjectID -ExceptionObjectID $exception.SPNObjectID) {
            $isMatch = $true
        }

        if (Match-ByNameLike -ObjectName $OutObject.AppDisplayName -ExceptionNameLike $exception.SPNNameLike) {
            $isMatch = $true
        }

        if (Match-ByObjectID -ObjectID $OutObject.AzureObjeccScopeID -ExceptionObjectID $exception.AzScopeObjectID) {
            $isMatch = $true
        }

        if (Match-ByNameLike -ObjectName $OutObject.ObjectName -ExceptionNameLike $exception.AzScopeNameLike) {
            $isMatch = $true
        }

        if (Match-ByEonID -ObjectEonID $OutObject.AppEONID -ExceptionEonID $exception.SPNEonID) {
            $isMatch = $true
        }

        if (Match-ByRole -ObjectRole $OutObject.PrivRole -ExceptionRole $exception.Role) {
            $isMatch = $true
        }

        if (Match-ByEnvironment -ObjectEnv $OutObject.Env -ExceptionEnv $exception.Env) {
            $isMatch = $true
        }

        # If any matches are found, return true indicating an exception
        if ($isMatch) {
            return $true
        }
    }

    # If no matches found, return false indicating not an exception
    return $false
}
