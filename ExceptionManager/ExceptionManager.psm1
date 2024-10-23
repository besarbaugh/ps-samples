<#
.SYNOPSIS
    ExceptionManager Module - Handles loading, validating, and adding exceptions to exceptions.json with CSA support.

.DESCRIPTION
    This module includes functions for loading datasets from network shares, validating exception schemas, and 
    adding new exceptions to the system. It integrates support for Custom Security Attributes (CSA) and 
    configurable dataset paths and file patterns via config.json.

#>

# Import required functions from the functions directory
. "$PSScriptRoot\functions\Get-Dataset.ps1"
. "$PSScriptRoot\functions\Add-Exception.ps1"
. "$PSScriptRoot\functions\Test-SchemaValidation.ps1"
. "$PSScriptRoot\functions\Remove-Exceptions.ps1"

# Export the core functions for use
Export-ModuleMember -Function Get-Dataset, Add-Exception, Test-SchemaValidation, Remove-Exceptions

