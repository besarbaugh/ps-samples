<#
.SYNOPSIS
    Removes role assignments for an Azure Service Principal across specified scopes and logs the operations for potential rollback.

.DESCRIPTION
    This script removes role assignments (like "Owner" or "Contributor") from a Service Principal (SP) within specified Azure resource scopes.
    It logs each removal operation to a CSV file with a timestamp (including date and time), which can be used to rollback the removals later.
    The script ensures a single tenant is processed at a time and includes authentication using Connect-AzAccount.

.PARAMETER spObjectId
    The Azure Service Principal object ID for which the role assignment needs to be removed.

.PARAMETER scopeId
    The full scope ID where the role is assigned (e.g., a Management Group ID, Subscription ID, or Resource Group ID).

.PARAMETER roleName
    The role assignment to be removed (e.g., "Owner", "Contributor", "User Access Administrator").

.PARAMETER Tenant
    The Azure tenant where the removal is being processed. Allowed values are "Prod", "QA", or "Dev".
    The actual tenant names will be mapped internally.

.PARAMETER Rollback
    Optional switch to undo the removals based on the CSV log file. When this is enabled, roles will be reassigned as per the log.

.EXAMPLE
    Remove role assignments for a Service Principal from a Management Group in the Prod tenant:
    
    Manage-AzureRoleAssignment -spObjectId "spn-object-id-1" -scopeId "/providers/Microsoft.Management/managementGroups/your-mg-id" -roleName "Owner" -Tenant "Prod"

.EXAMPLE
    Rollback role assignments based on the CSV log:

    foreach ($logEntry in Import-Csv -Path ".\RoleRemovalLog_2024-10-24_1530.csv") {
        Manage-AzureRoleAssignment -spObjectId $logEntry.SPObjectID -scopeId $logEntry.ScopeID -roleName $logEntry.RoleName -Tenant $logEntry.Tenant -Rollback
    }

.EXAMPLE
    To import a CSV file with multiple role removals:
    
    The CSV should have columns for SPObjectID, ScopeID, RoleName, and Tenant.
    Example CSV:

    SPObjectID,ScopeID,RoleName,Tenant
    spn-object-id-1,/subscriptions/your-subscription-id,Owner,Prod
    spn-object-id-2,/providers/Microsoft.Management/managementGroups/your-mg-id,Contributor,QA

    Import and process:
    
    $removals = Import-Csv -Path ".\RoleAssignmentsToRemove.csv"
    
    foreach ($entry in $removals) {
        Manage-AzureRoleAssignment -spObjectId $entry.SPObjectID -scopeId $entry.ScopeID -roleName $entry.RoleName -Tenant $entry.Tenant
    }

.NOTES
    The `ScopeId` should be provided in its full format (e.g., Management Group, Subscription, or Resource Group).
    When importing a log or CSV for bulk role removals, ensure that the columns include `SPObjectID`, `ScopeID`, `RoleName`, and `Tenant`.

    Example of importing and filtering log data:

    ```powershell
    $logFile = Import-Csv -Path ".\RoleRemovalLog_2024-10-24_1530.csv"
    $filteredLog = $logFile | Where-Object { $_.RoleName -eq 'Owner' -and $_.Tenant -eq 'Prod' }
    
    foreach ($entry in $filteredLog) {
        Manage-AzureRoleAssignment -spObjectId $entry.SPObjectID -scopeId $entry.ScopeID -roleName $entry.RoleName -Tenant $entry.Tenant -Rollback
    }
    ```

#>

function Manage-AzureRoleAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$spObjectId,  # Single SP Object ID

        [Parameter(Mandatory = $true)]
        [string]$scopeId,     # Full Resource Scope ID (e.g., MG, Subscription, or RG)

        [Parameter(Mandatory = $true)]
        [string]$roleName,    # Role Assignment Name (e.g., "Owner", "Contributor")

        [Parameter(Mandatory = $true)]
        [ValidateSet("Prod", "QA", "Dev")]  # Mandatory tenant with validation
        [string]$Tenant,

        [switch]$Rollback  # If provided, the script will reassign roles based on the CSV log
    )

    # Connect to Azure (always ensure authentication before processing)
    Connect-AzAccount -ErrorAction Stop

    # Generate a timestamped log file name (with date and time)
    $currentDateTime = Get-Date -Format "yyyy-MM-dd_HHmm"
    $logFilePath = ".\RoleRemovalLog_$currentDateTime.csv"

    # Ensure only one tenant is allowed per execution
    switch ($Tenant) {
        "Prod" { $tenantName = "your-prod-tenant-name" }
        "QA" { $tenantName = "your-qa-tenant-name" }
        "Dev" { $tenantName = "your-dev-tenant-name" }
        default { throw "Unknown tenant: $Tenant" }
    }

    if ($Rollback) {
        # If performing rollback, reassign roles based on the log
        try {
            New-AzRoleAssignment -ObjectId $spObjectId -Scope $scopeId -RoleDefinitionName $roleName
            Write-Host "Successfully rolled back role assignment: $roleName for SP: $spObjectId on scope: $scopeId in tenant: $tenantName"
        }
        catch {
            Write-Host "Error rolling back role assignment for SP: $spObjectId on scope: $scopeId with role: $roleName in tenant: $tenantName. Error: $_"
        }
    }
    else {
        # Perform role removal and log it to the CSV file
        try {
            # Get the role assignment object
            $roleAssignment = Get-AzRoleAssignment -ObjectId $spObjectId -Scope $scopeId -RoleDefinitionName $roleName

            if ($roleAssignment) {
                # Remove the role assignment
                Remove-AzRoleAssignment -ObjectId $spObjectId -Scope $scopeId -RoleDefinitionName $roleName -Confirm:$false
                Write-Host "Successfully removed role assignment: $roleName for SP: $spObjectId on scope: $scopeId in tenant: $tenantName"

                # Log the removal to the CSV file
                $logEntry = [PSCustomObject]@{
                    SPObjectID = $spObjectId
                    ScopeID = $scopeId
                    RoleName = $roleName
                    Tenant = $tenantName
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $logEntry | Export-Csv -Path $logFilePath -Append -NoTypeInformation
            } else {
                Write-Host "No role assignment found for SP: $spObjectId on scope: $scopeId with role: $roleName in tenant: $tenantName"
            }
        }
        catch {
            Write-Host "Error removing role assignment for SP: $spObjectId on scope: $scopeId with role: $roleName in tenant: $tenantName. Error: $_"
        }
    }
}

# Example usage for bulk removal:
$spObjectIds = @("spn-object-id-1", "spn-object-id-2")  # Replace with your list of SP Object IDs
$scopeIds = @("/subscriptions/your-subscription-id", "/providers/Microsoft.Management/managementGroups/your-mg-id")  # Replace with your full Scope IDs
$roleName = "Owner"  # Replace with the role assignment you want to remove
$tenant = "Prod"  # Replace with the tenant name

foreach ($spObjectId in $spObjectIds) {
    foreach ($scopeId in $scopeIds) {
        Manage-AzureRoleAssignment -spObjectId $spObjectId -scopeId $scopeId -roleName $roleName -Tenant $tenant
    }
}

# Example usage for performing rollback:
# (You can also specify the same parameters as the removal loop)
foreach ($logEntry in Import-Csv -Path ".\RoleRemovalLog_$currentDateTime.csv") {
    Manage-AzureRoleAssignment -spObjectId $logEntry.SPObjectID -scopeId $logEntry.ScopeID -roleName $logEntry.RoleName -Tenant $logEntry.Tenant -Rollback
}
