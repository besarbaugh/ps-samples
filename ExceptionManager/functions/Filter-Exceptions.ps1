<#
.SYNOPSIS
    Filters the dataset by applying exceptions from the exceptions.json file.

.DESCRIPTION
    This function reads exceptions from the exceptions.json file and applies them to filter out matching records 
    from the provided dataset. It supports both object ID-based and name-like pattern filtering for SPNs and Azure objects.
    It removes matching records from the dataset based on the filtering rules.

.PARAMETER datasetObject
    Optional parameter. A PowerShell object (array of objects) representing the dataset to be filtered.

.PARAMETER datasetPath
    The file path for the dataset (CSV) if not passed as a PowerShell object.

.PARAMETER exceptionsPath
    The file path for the exceptions.json file. Defaults to the path specified in config.json.

.PARAMETER outputCsvPath
    The file path where the filtered dataset will be written (optional).

.RETURNS
    The filtered dataset as a PowerShell object, or writes the filtered dataset to CSV if outputCsvPath is specified.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.0.3
#>

function Filter-Exceptions {
    param(
        [Parameter(Mandatory = $false)][array]$datasetObject,  # Accepts dataset as an object array
        [Parameter(Mandatory = $false)][string]$datasetPath,  # Optional CSV dataset path
        [Parameter(Mandatory = $false)][string]$exceptionsPath,  # Optional exceptions.json path (default from config.json)
        [Parameter(Mandatory = $false)][string]$outputCsvPath  # Optional output CSV path
    )

    try {
        # Load configuration settings from config.json
        $configPath = ".\config.json"
        if (-not (Test-Path -Path $configPath)) {
            throw "config.json not found. Please ensure the configuration file is present."
        }

        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

        # Set exceptionsPath from config.json if not provided
        if (-not $exceptionsPath) {
            $exceptionsPath = $config.exceptionsPath
        }

        if (-not (Test-Path -Path $exceptionsPath)) {
            throw "exceptions.json file not found at: $exceptionsPath"
        }

        # Load the exceptions
        $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
        if (-not $exceptions) {
            throw "No exceptions found in $exceptionsPath"
        }

        # Load the dataset (either from object or CSV)
        if ($datasetObject) {
            $dataset = $datasetObject
        } elseif ($datasetPath) {
            if (-not (Test-Path -Path $datasetPath)) {
                throw "Dataset file not found at: $datasetPath"
            }
            $dataset = Import-Csv -Path $datasetPath
        } else {
            throw "You must provide either a dataset object or a dataset CSV file path."
        }

        # Iterate over the dataset and filter out matching entries based on the exceptions
        $filteredDataset = foreach ($entry in $dataset) {
            $isExcluded = $false

            # Loop through each exception and check if the current dataset entry matches
            foreach ($exception in $exceptions) {
                $spnMatch = $false
                $azObjectMatch = $false

                # Handle SPN matching logic
                if ($exception.spnObjectID) {
                    $spnMatch = ($entry.AppObjectID -ieq $exception.spnObjectID)
                } elseif ($exception.spnNameLike) {
                    $spnMatch = ($entry.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                }

                # Handle Azure object matching logic
                if ($exception.azObjectScopeID) {
                    $azObjectMatch = ($entry.AzureObjectScopeID -eq $exception.azObjectScopeID)
                } elseif ($exception.azObjectNameLike) {
                    $azObjectMatch = ($entry.ObjectName -ilike "*$($exception.azObjectNameLike)*")
                }

                # Ensure that all matches align for exclusion
                if (
                    $spnMatch -and $azObjectMatch -and
                    ($entry.PrivRole -ieq $exception.role) -and
                    ($entry.ObjectType -ieq $exception.azScopeType) -and
                    ($entry.Tenant -ieq $exception.tenant) -and
                    (-not $exception.expiration_date -or [datetime]$exception.expiration_date -gt (Get-Date))
                ) {
                    $isExcluded = $true
                    break  # If one exception matches, skip the entry
                }
            }

            # Only keep the entry if no exception matched
            if (-not $isExcluded) {
                $entry
            }
        }

        # Output filtered dataset
        if ($outputCsvPath) {
            $filteredDataset | Export-Csv -Path $outputCsvPath -NoTypeInformation
            Write-Host "Filtered dataset written to: $outputCsvPath"
        } else {
            return $filteredDataset
        }
    }
    catch {
        Write-Error "An error occurred in Filter-Exceptions: $_"
        throw $_
    }
}
