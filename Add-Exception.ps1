function Add-Exception {
    <#
    .SYNOPSIS
        Adds a new exception to the exceptions.json file in the root of the repo.

    .DESCRIPTION
        This function validates a new exception and adds it to the specified exceptions.json file. It performs validation,
        duplicate checks, and saves the new exception to the file if it passes validation.

    .PARAMETER SpnNamePatterns
        The SPN name patterns to add.

    .PARAMETER SPNDeptID
        The department ID of the SPN.

    .PARAMETER ContainerTypes
        The types of containers (RG, sub, MG).

    .PARAMETER Roles
        The roles assigned to the SPN.

    .PARAMETER Environment
        The environment of the SPN.

    .PARAMETER Dynamic
        Whether the exception is dynamic.

    .PARAMETER DynamicScope
        Whether the exception has a dynamic scope.

    .PARAMETER ExceptionType
        The type of the exception (permanent or dynamic).

    .PARAMETER ExpirationDate
        The expiration date for temporary exceptions.

    .PARAMETER ContainerDeptID
        The department ID of the container.

    .PARAMETER ContainerID
        The object ID of the container.

    .EXAMPLE
        PS C:\> Add-Exception -SpnNamePatterns $spnNamePatterns -SPNDeptID "Dept001" -ContainerTypes @("RG", "sub") -Roles @("owner") -Environment "Prod" -Dynamic $true -DynamicScope $false -ExceptionType "dynamic" -ExpirationDate (Get-Date).AddMonths(6)

        Adds a new exception to the exceptions.json file after validation and duplicate checks.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$SpnNamePatterns,
        [Parameter(Mandatory = $true)]
        [string]$SPNDeptID,
        [Parameter(Mandatory = $true)]
        [array]$ContainerTypes,
        [Parameter(Mandatory = $true)]
        [array]$Roles,
        [Parameter(Mandatory = $true)]
        [string]$Environment,
        [Parameter(Mandatory = $true)]
        [bool]$Dynamic,
        [Parameter(Mandatory = $true)]
        [bool]$DynamicScope,
        [Parameter(Mandatory = $true)]
        [string]$ExceptionType,
        [datetime]$ExpirationDate = $null,
        [string]$ContainerDeptID = $null,
        [string]$ContainerID = $null
    )

    try {
        # Path to exceptions.json
        $FilePath = Join-Path $PSScriptRoot "..\exceptions.json"

        # Build the new exception object
        $newException = @{
            spnname_patterns = $SpnNamePatterns
            spndeptid        = $SPNDeptID
            containertype    = $ContainerTypes
            role             = $Roles
            environment      = $Environment
            dynamic          = $Dynamic
            dynamic_scope    = $DynamicScope
            exception_type   = $ExceptionType
            expiration_date  = $ExpirationDate
            containerdeptid  = $ContainerDeptID
            containerid      = $ContainerID
        }

        # Convert all keys to lowercase
        $newException = $newException | ForEach-Object { $_.PSObject.Properties.Name = $_.PSObject
