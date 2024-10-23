<#
.SYNOPSIS
    Removes entries from the dataset that match exceptions in exceptions.json.

.DESCRIPTION
    This function loads the dataset and exceptions.json and removes entries from the dataset that are 
    already covered by exceptions. It compares fields like spnObjectID, spnNameLike, azObjectScopeID, 
    and azObjectNameLike to determine matches. Case sensitivity is ignored for all matches.

.PARAMETER datasetPath
    The path to the dataset (CSV). Defaults to the path specified in config.json.

.PARAMETER exceptionsPath
    The path to the exceptions.json file. Defaults to the path specified in config.json.

.RETURNS
    The filtered dataset with exceptions removed.
#>

function Remove-Exceptions {
    param(
        [Parameter(Mandatory=$false)][string]$datasetPath,  # Dataset path (optional, defaults to config.json)
        [Parameter(Mandatory=$false)][string]$exceptionsPath  # Exceptions path (optional, defaults to config.json)
    )

    # Load configuration settings from config.json
    $configPath = ".\config.json"
    if (-not (Test-Path -Path $configPath)) {
        throw "config.json not found. Please ensure the configuration file is present."
    }
    $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

    # Set the paths from config.json if not provided
    if (-not $exceptionsPath) {
        $exceptionsPath = $config.exceptionsPath
    }
    if (-not $datasetPath) {
        $dataset = Get-Dataset -datasetDir $config.datasetDir -filenamePattern $config.filenamePattern
    } else {
        $dataset = Import-Csv -Path $datasetPath
    }

    # Load exceptions.json
    if (-not (Test-Path -Path $exceptionsPath)) {
        throw "exceptions.json file not found: $exceptionsPath"
    }
    $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json

    # Create an empty array to hold filtered results
    $filteredResults = @()

    # Loop through each item in the dataset
    foreach ($item in $dataset) {
        $isException = $false

        foreach ($exception in $exceptions) {
            # Check spnObjectID (case-insensitive)
            if ($exception.spn_object_id) {
                if ($item.AppObjectID -ieq $exception.spn_object_id) {
                    $isException = $true
                    break  # Exit the loop if a match is found
                }
            }

            # Check spnNameLike (case-insensitive wildcard match)
            if ($exception.spn_name_like) {
                if ($item.AppDisplayName -ilike $exception.spn_name_like) {
                    $isException = $true
                    break  # Exit the loop if a match is found
                }
            }

            # Check azObjectScopeID (case-insensitive)
            if ($exception.azObjectScopeID) {
                if ($item.AzureObjectScopeID -ieq $exception.azObjectScopeID) {
                    $isException = $true
                    break  # Exit the loop if a match is found
                }
            }

            # Check azObjectNameLike (case-insensitive wildcard match)
            if ($exception.azObjectNameLike) {
                if ($item.ObjectName -ilike $exception.azObjectNameLike) {
                    $isException = $true
                    break  # Exit the loop if a match is found
                }
            }

            # Check spnEonid if present (case-insensitive)
            if ($exception.spn_eonid) {
                if ($item.AppEonid -ine $exception.spn_eonid) {
                    $isException = $false  # Reset flag if spnEonid doesn't match
                    continue
                }
            }

            # Check tenant if present (case-insensitive)
            if ($exception.tenant) {
                if ($item.Tenant -ine $exception.tenant) {
                    $isException = $false  # Reset flag if tenant doesn't match
                    continue
                }
            }
        }

        # Add item to results if not an exception
        if (-not $isException) {
            $filteredResults += $item
        }
    }

    # Return the filtered dataset (entries without matching exceptions)
    return $filteredResults
}

# Example usage
# Remove-Exceptions -datasetPath ".\datasets\dataset.csv" -exceptionsPath ".\exceptions\exceptions.json"
