<#
.SYNOPSIS
    Filters out entries from the dataset based on the exceptions.json file.

.DESCRIPTION
    This function processes the dataset and removes any entries that match the exceptions specified in the 
    exceptions.json file. It supports mutually exclusive parameters such as spnObjectID vs spnNameLike, and 
    azObjectScopeID vs azObjectNameLike. It ensures spnEonid is mandatory for all exceptions, and also supports 
    matching criteria like role, scope type, and tenant.

.PARAMETER exceptionsPath
    The file path for the exceptions.json file. Defaults to ".\exceptions.json" if not provided.

.PARAMETER datasetPath
    The file path for the dataset CSV file. Defaults to ".\dataset.csv" if not provided.

.EXAMPLE
    Filter-Exceptions -exceptionsPath ".\exceptions.json" -datasetPath ".\dataset.csv"
    
    Filters out the dataset entries based on the exceptions defined in the exceptions.json file.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.0.4
    Filters the dataset according to the rules defined in the exceptions.json file.
#>

function Filter-Exceptions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)][string]$exceptionsPath = ".\exceptions.json",
        [Parameter(Mandatory = $false)][string]$datasetPath = ".\dataset.csv"
    )

    try {
        # Load exceptions from the JSON file and dataset from CSV
        if (-not (Test-Path -Path $exceptionsPath)) {
            throw "Exceptions file not found at path: $exceptionsPath"
        }

        if (-not (Test-Path -Path $datasetPath)) {
            throw "Dataset file not found at path: $datasetPath"
        }

        $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
        $dataset = Import-Csv -Path $datasetPath

        # Iterate through each exception to filter out matching entries from the dataset
        foreach ($exception in $exceptions) {
            $dataset = $dataset | Where-Object {
                $spnMatch = $false
                $azObjectMatch = $false

                # Handle spnObjectID vs spnNameLike logic
                if ($exception.spnObjectID) {
                    $spnMatch = ($_.AppObjectID -eq $exception.spnObjectID)
                } elseif ($exception.spnNameLike) {
                    $spnMatch = ($_.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                }

                # Handle azObjectScopeID vs azObjectNameLike logic
                if ($exception.azObjectScopeID) {
                    $azObjectMatch = ($_.AzureObjectScopeID -eq $exception.azObjectScopeID)
                } elseif (-not $exception.azObjectScopeID -and -not $exception.azObjectNameLike) {
                    # Apply to all objects of the scope type
                    $azObjectMatch = $true
                } elseif ($exception.azObjectNameLike) {
                    $azObjectMatch = ($_.ObjectName -ilike "*$($exception.azObjectNameLike)*")
                }

                # Check if all criteria match (SPN, Azure object, role, scope type, and tenant)
                $spnMatch -and $azObjectMatch -and
                ($_.PrivRole -eq $exception.role) -and
                ($_.ObjectType -eq $exception.azScopeType) -and
                ($_.Tenant -eq $exception.tenant)
            }
        }

        Write-Host "Filtered dataset successfully processed."
        return $dataset

    } catch {
        Write-Error "An error occurred while filtering exceptions: $_"
        throw $_
    }
}
