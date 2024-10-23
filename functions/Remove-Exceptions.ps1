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
        [Parameter(Mandatory = $true)][array]$data,  # Dataset loaded as array of objects
        [Parameter(Mandatory = $true)][string]$exceptionsJsonPath,  # Path to exceptions.json
        [Parameter(Mandatory = $false)][switch]$removalCount  # Optional: Count removed entries
    )

    try {
        if (-not (Test-Path -Path $exceptionsJsonPath)) {
            throw "exceptions.json file not found at $exceptionsJsonPath"
        }

        # Load exceptions from the JSON file
        $exceptions = Get-Content -Path $exceptionsJsonPath | ConvertFrom-Json

        if (-not $exceptions) {
            throw "No exceptions found in $exceptionsJsonPath"
        }

        # Initialize a counter for removed entries if needed
        $removedEntriesCount = 0

        # Filter out entries that match any exception
        $filteredResults = $data | Where-Object {
            $isException = $false

            foreach ($exception in $exceptions) {
                if ($_.AppObjectID -eq $exception.spn_object_id -and
                    $_.AppEonid -eq $exception.spn_eonid -and
                    $_.Tenant -eq $exception.tenant) {
                    $isException = $true
                    break
                }

                if ($_.AppDisplayName -like "*$($exception.spn_name_like)*" -and
                    $_.AppEonid -eq $exception.spn_eonid -and
                    $_.Tenant -eq $exception.tenant) {
                    $isException = $true
                    break
                }

                if ($_.ObjectName -like "*$($exception.azObjectNameLike)*" -and
                    $_.PrivRole -eq $exception.PrivRole) {
                    $isException = $true
                    break
                }
            }

            if ($isException) {
                $removedEntriesCount++
            }

            return -not $isException
        }

        # Output the removal count if requested
        if ($removalCount.IsPresent) {
            Write-Host "Removed entries count: $removedEntriesCount"
        }

        return $filteredResults
    }
    catch {
        Write-Error "An error occurred in Remove-Exceptions: $_"
        throw $_
    }
}

# Example usage
# Remove-Exceptions -datasetPath ".\datasets\dataset.csv" -exceptionsPath ".\exceptions\exceptions.json"
