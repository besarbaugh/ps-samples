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
