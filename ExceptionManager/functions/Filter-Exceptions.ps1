<#
.SYNOPSIS
    Filters exceptions from a dataset by removing line items based on the exceptions.json file.

.DESCRIPTION
    This function filters a dataset by removing entries that match the criteria specified in the exceptions.json file. 
    It handles both SPN object ID-based exceptions and SPN name-like patterns, with mutual exclusivity. It also supports 
    filtering by Azure object scope or name-like patterns, and by role, scope type, and tenant. Expired ActionPlan exceptions are ignored.

.PARAMETER exceptionsPath
    The file path for the exceptions.json file. Defaults to the path specified in config.json.

.PARAMETER datasetPath
    The file path for the dataset (CSV). Defaults to the path specified in config.json.

.PARAMETER outputPath
    The file path to save the filtered dataset after removing exceptions.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.0.0
    This function filters out dataset entries that match exceptions in exceptions.json.

.EXAMPLE
    Filter-Exceptions -datasetPath "dataset.csv" -outputPath "filtered_dataset.csv"
    
    Filters out exceptions from the dataset and saves the filtered dataset to a new file.
#>

function Filter-Exceptions {
    param(
        [Parameter(Mandatory = $false)][string]$exceptionsPath,  # Path to exceptions.json
        [Parameter(Mandatory = $false)][string]$datasetPath,  # Path to the dataset CSV
        [Parameter(Mandatory = $true)][string]$outputPath  # Path to save the filtered dataset
    )

    try {
        # Load configuration settings
        $configPath = ".\config.json"
        if (-not (Test-Path -Path $configPath)) {
            throw "config.json not found."
        }
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

        if (-not $exceptionsPath) {
            $exceptionsPath = $config.exceptionsPath
        }
        if (-not $datasetPath) {
            $datasetPath = $config.datasetPath
        }

        # Load dataset and exceptions
        $dataset = Import-Csv -Path $datasetPath
        if (-not (Test-Path -Path $exceptionsPath)) {
            throw "exceptions.json not found at $exceptionsPath"
        }
        $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json

        # Loop through each exception and remove matching entries from the dataset
        foreach ($exception in $exceptions) {
            if ($exception.ActionPlan -and ($exception.expiration_date -lt (Get-Date))) {
                # Skip expired ActionPlan exceptions
                continue
            }

            # Remove matching entries from the dataset
            $dataset = $dataset | Where-Object {
                $spnMatch = $false
                $azObjectMatch = $false

                # Handle spnObjectID vs spnNameLike logic
                if ($exception.spnObjectID) {
                    # If spnObjectID is provided, match it
                    $spnMatch = ($_.AppObjectID -eq $exception.spnObjectID)
                } elseif ($exception.spnNameLike) {
                    # If spnNameLike is provided, match using wildcard
                    $spnMatch = ($_.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                } else {
                    # Apply to all if no SPN criteria are provided
                    $spnMatch = $true
                }

                # Handle azObjectScopeID vs azObjectNameLike logic
                if ($exception.azObjectScopeID) {
                    # If azObjectScopeID is provided, match it
                    $azObjectMatch = ($_.AzureObjectScopeID -eq $exception.azObjectScopeID)
                } elseif ($exception.azObjectNameLike) {
                    # If azObjectNameLike is provided, match using wildcard
                    $azObjectMatch = ($_.ObjectName -ilike "*$($exception.azObjectNameLike)*")
                } else {
                    # Apply to all if no Azure object criteria are provided
                    $azObjectMatch = $true
                }

                # Exclude entries that match all criteria (SPN, Azure object, role, scope type, tenant)
                -not ($spnMatch -and $azObjectMatch -and
                ($_.PrivRole -eq $exception.role) -and
                ($_.ObjectType -eq $exception.azScopeType) -and
                ($_.Tenant -eq $exception.tenant))
            }
        }

        # Save the filtered dataset
        $dataset | Export-Csv -Path $outputPath -NoTypeInformation
        Write-Host "Filtered dataset saved to $outputPath"

    }
    catch {
        Write-Error "An error occurred: $_"
        throw $_
    }
}
