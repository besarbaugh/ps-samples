# ExceptionManager.psm1
# Author: Brian Sarbaugh
# Version: 1.0.0
# Description: PowerShell module for managing Azure exceptions with support for SPN and Azure object role validation, schema validation, 
#              and CSA enforcement. The module includes functions for adding, removing, and validating exceptions.
# Created: October 2024

# Import individual functions
. "$PSScriptRoot\functions\Get-Dataset.ps1"
. "$PSScriptRoot\functions\Add-Exception.ps1"
. "$PSScriptRoot\functions\Test-SchemaValidation.ps1"
. "$PSScriptRoot\functions\Remove-Exceptions.ps1"

# Export module members
Export-ModuleMember -Function Get-Dataset, Add-Exception, Test-SchemaValidation, Remove-Exceptions

# Version History
# Version 1.0.0 - Initial version of ExceptionManager