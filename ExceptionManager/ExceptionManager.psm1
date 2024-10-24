# ExceptionManager.psm1
# Author: Brian Sarbaugh
# Version: 1.0.0
# Description: PowerShell module for managing Azure exceptions with support for SPN and Azure object role validation, schema validation, 
#              and CSA enforcement. The module includes functions for adding, removing, and validating exceptions.
# Created: October 2024

# Import individual functions from the ExceptionManager/functions folder
. "$PSScriptRoot\functions\Get-Dataset.ps1"
. "$PSScriptRoot\functions\Add-Exception.ps1"
. "$PSScriptRoot\functions\Test-SchemaValidation.ps1"
. "$PSScriptRoot\functions\Remove-Exception.ps1"

# Export module members
Export-ModuleMember -Function Get-Dataset, Add-Exception, Test-SchemaValidation, Remove-Exception

# Version History
# Version 1.0.0 - Initial version of ExceptionManager