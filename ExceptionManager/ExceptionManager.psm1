# ExceptionManager.psm1
# Author: Brian Sarbaugh
# Version: 1.1.1
# Description: PowerShell module for managing Azure exceptions with support for SPN and Azure object role validation, 
#              and CSA enforcement. The module includes functions for adding, updating, removing, and filtering exceptions.
# Created: October 2024

# Import individual functions from the ExceptionManager/functions folder
. "$PSScriptRoot\functions\Get-Dataset.ps1"
. "$PSScriptRoot\functions\Add-Exception.ps1"
. "$PSScriptRoot\functions\Update-Exception.ps1"
. "$PSScriptRoot\functions\Remove-Exception.ps1"
. "$PSScriptRoot\functions\Filter-Exceptions.ps1"

# Export module members
Export-ModuleMember -Function Get-Dataset, Add-Exception, Update-Exception, Remove-Exception, Filter-Exceptions

# Version History
# Version 1.1.1 - November 2024
# - Removed Test-SchemaValidation function from module
# - Added Update-Exception function with support for LastUpdated and lastModifiedBy fields
# - Enhanced Filter-Exceptions function to include GUID and modification tracking
# - Updated Add-Exception function to validate lastModifiedBy email and set LastUpdated and lastModifiedBy
# - Introduced Get-Dataset function to dynamically load datasets based on file pattern

# Version 1.0.0 - Initial version of ExceptionManager
# - Added Add-Exception, Remove-Exception, and Get-Dataset functions
