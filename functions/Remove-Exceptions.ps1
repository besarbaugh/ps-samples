<#
.SYNOPSIS
    Removes entries from the dataset that match exceptions in exceptions.json.

.DESCRIPTION
    This function loads the dataset and exceptions.json and removes entries from the dataset that are 
    already covered by exceptions. It compares fields like spnObjectID, spnNameLike, azObjectScopeID, 
    and azObjectNameLike to determine matches. Custom Security Attributes (CSA) will also be validated 
    if enforced via config.json.

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

    # Iterate through the dataset and filter out entries that match exceptions
    $filteredDataset = foreach ($entry in $dataset) {
        $isException = $false

        foreach ($exception in $exceptions) {
            # Check spnObjectID or spn_name_like
            if ($exception.spn_object_id) {
                if ($entry.AppObjectID -eq $exception.spn_object_id) {
                    $isException = $true
                    break
                }
            } elseif ($exception.spn_name_like) {
                if ($entry.AppDisplayName -like $exception.spn_name_like) {
                    $isException = $true
                    break
                }
            }

            # Check azObjectScopeID or azObjectNameLike
            if ($exception.azObjectScopeID) {
                if ($entry.AzureObjectScopeID -eq $exception.azObjectScopeID) {
                    $isException = $true
                    break
                }
            } elseif ($exception.azObjectNameLike) {
                if ($entry.ObjectName -like $exception.azObjectNameLike) {
                    $isException = $true
                    break
                }
            }

            # Check spnEonid if required
            if ($exception.spn_eonid) {
                if ($entry.AppEonid -ne $exception.spn_eonid) {
                    $isException = $false  # No match, reset flag
                    continue
                }
            }

            # Check tenant if required
            if ($exception.tenant) {
                if ($entry.Tenant -ne $exception.tenant) {
                    $isException = $false  # No match, reset flag
                    continue
                }
            }
        }

        # If it's not an exception, include it in the filtered dataset
        if (-not $isException) {
            $entry
        }
    }

    # Return the filtered dataset (entries without matching exceptions)
    return $filteredDataset
}

# Example usage
# Remove-Exceptions -datasetPath ".\datasets\dataset.csv" -exceptionsPath ".\exceptions\exceptions.json"
