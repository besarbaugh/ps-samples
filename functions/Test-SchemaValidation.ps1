<#
.SYNOPSIS
    Validates the schema of an exception object before it is added to the exceptions.json file.

.DESCRIPTION
    This function ensures that the exception follows the correct schema. It checks for mandatory fields, 
    verifies that 'spn_name_like' and 'spnObjectID' are mutually exclusive, and enforces the presence of 
    tenant and spnEonid where applicable. If CSA is enforced (via config.json), spnEonid and spnEnv 
    are validated against the dataset rather than display names. It also prevents both 'azObjectNameLike' 
    and 'azObjectID' from appearing in the same exception. Either SecArch or ActionPlan is required, and both 
    are automatically assigned dates.

.PARAMETER exception
    A hashtable representing the exception to be validated.

.PARAMETER datasetPath
    The file path for the dataset (CSV). Defaults to the path specified in config.json.

.RETURNS
    $true if the schema is valid, throws an error otherwise.
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
