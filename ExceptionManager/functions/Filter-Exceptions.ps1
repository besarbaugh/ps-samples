<#
.SYNOPSIS
    Filters out entries from the dataset based on the exceptions in exceptions.json or a provided PSObject.

.DESCRIPTION
    This function processes the dataset (CSV or PSObject) and filters out any entries that match the exceptions 
    defined in exceptions.json or a provided object. It ensures the validation logic aligns with the removalCount 
    logic in Add-Exception.ps1, handling mutually exclusive fields like spnObjectID vs spnNameLike and azObjectScopeID 
    vs azObjectNameLike. The user can choose to input and output in either CSV or PSObject format.

.PARAMETER exceptionsPath
    The file path for the exceptions.json file. Defaults to the value from config.json if not provided.

.PARAMETER datasetPath
    The file path for the dataset (CSV). Defaults to the value from config.json if not provided.

.PARAMETER datasetObject
    A PowerShell object (array of objects) representing the dataset. If provided, this will be used instead of the CSV.

.PARAMETER outputAsCsv
    A switch parameter to indicate if the output should be written to a CSV file. If this switch is not used, the result will be returned as a PSObject.

.PARAMETER outputCsvPath
    Optional. The file path to write the filtered results if outputAsCsv is used. Defaults to filtered_output.csv.

.EXAMPLE
    Filter-Exceptions -exceptionsPath ".\exceptions.json" -datasetPath ".\dataset.csv" -outputAsCsv
    
    Filters the dataset based on exceptions and outputs the result as a CSV file.

.EXAMPLE
    Filter-Exceptions -datasetObject $dataset -exceptionsPath ".\exceptions.json"
    
    Filters the provided dataset object based on exceptions and returns the result as a PSObject.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.1.1
    Filters the dataset according to the exceptions defined in exceptions.json or a provided object, and outputs the result in either PSObject or CSV format.
#>

function Filter-Exceptions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)][string]$exceptionsPath = ".\exceptions.json",
        [Parameter(Mandatory = $false)][string]$datasetPath = ".\dataset.csv",
        [Parameter(Mandatory = $false)][array]$datasetObject,  # Accepts a PowerShell object array
        [Parameter(Mandatory = $false)][switch]$outputAsCsv,   # If set, output will be CSV
        [Parameter(Mandatory = $false)][string]$outputCsvPath = ".\filtered_output.csv"  # Output CSV file path
    )

    try {
        # Load configuration settings from config.json if paths are not provided
        $configPath = ".\config.json"
        if (-not (Test-Path -Path $configPath)) {
            throw "config.json not found."
        }
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

        if (-not $exceptionsPath) {
            $exceptionsPath = $config.exceptionsPath
        }
        if (-not $datasetPath -and -not $datasetObject) {
            $datasetPath = $config.datasetPath
        }

        # Load exceptions from the JSON file
        if (-not (Test-Path -Path $exceptionsPath)) {
            throw "Exceptions file not found at path: $exceptionsPath"
        }
        $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json

        # Load dataset either from CSV or PSObject input
        $dataset = if ($datasetObject) {
            $datasetObject
        } else {
            if (-not (Test-Path -Path $datasetPath)) {
                throw "Dataset file not found at path: $datasetPath"
            }
            Import-Csv -Path $datasetPath
        }

        # Iterate through each exception to filter out matching entries from the dataset
        foreach ($exception in $exceptions) {
            $dataset = $dataset | Where-Object {
                $spnMatch = $false
                $azObjectMatch = $false
                $tenantMatch = $true  # Default to true, modify only if tenant matching is required

                # Handle SPN matching (spnObjectID vs spnNameLike)
                if ($exception.spnObjectID) {
                    $spnMatch = ($_.AppObjectID -eq $exception.spnObjectID)
                } elseif ($exception.spnNameLike) {
                    $spnMatch = ($_.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                    # Apply tenant matching only if spnNameLike is used
                    $tenantMatch = ($_.Tenant -eq $exception.tenant)
                }

                # Handle Azure Object matching (azObjectScopeID vs azObjectNameLike)
                if ($exception.azObjectScopeID) {
                    $azObjectMatch = ($_.AzureObjectScopeID -eq $exception.azObjectScopeID)
                } elseif (-not $exception.azObjectScopeID -and -not $exception.azObjectNameLike) {
                    $azObjectMatch = $true  # Apply to all objects of the scope type
                } elseif ($exception.azObjectNameLike) {
                    $azObjectMatch = ($_.ObjectName -ilike "*$($exception.azObjectNameLike)*")
                }

                # Apply exclusion logic (remove entries that match all conditions)
                -not ($spnMatch -and $azObjectMatch -and $tenantMatch -and
                      ($_.PrivRole -eq $exception.role) -and
                      ($_.ObjectType -eq $exception.azScopeType))
            }
        }

        # Output as CSV if specified, otherwise return as PSObject
        if ($outputAsCsv) {
            $dataset | Export-Csv -Path $outputCsvPath -NoTypeInformation
            Write-Host "Filtered results saved to: $outputCsvPath"
        } else {
            return $dataset
        }

    } catch {
        Write-Error "An error occurred while filtering exceptions: $_"
        throw $_
    }
}
