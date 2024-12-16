<#
.SYNOPSIS
    Filters dataset based on exceptions.json:
    - Removes entries matching SecArch exceptions.
    - Adds ActionPlan details (`AP_Number` and `Due_Date`) as new columns.

.DESCRIPTION
    - SecArch exceptions remove the entry completely.
    - ActionPlan exceptions retain the entry and add new columns for `AP_Number` and `Due_Date`.
    - Non-matching entries retain all original fields with blank new columns.

.PARAMETER exceptionsPath
    Path to the `exceptions.json` file.

.PARAMETER datasetPath
    Path to the dataset CSV file.

.PARAMETER outputAsCsv
    If specified, outputs the filtered dataset to a CSV file.

.PARAMETER outputCsvPath
    File path for the output CSV file.

.EXAMPLE
    Filter-Exceptions -exceptionsPath ".\exceptions.json" -datasetPath ".\violations.csv" -outputAsCsv -outputCsvPath ".\filtered_output.csv"
#>

function Filter-Exceptions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$exceptionsPath,
        [Parameter(Mandatory = $true)][string]$datasetPath,
        [Parameter(Mandatory = $false)][switch]$outputAsCsv,
        [Parameter(Mandatory = $false)][string]$outputCsvPath = ".\filtered_output.csv"
    )

    try {
        # Load exceptions
        if (-not (Test-Path -Path $exceptionsPath)) { throw "Exceptions file not found." }
        $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json

        # Load dataset
        if (-not (Test-Path -Path $datasetPath)) { throw "Dataset file not found." }
        $dataset = Import-Csv -Path $datasetPath

        # Initialize output array
        $filteredDataset = @()

        foreach ($lineItem in $dataset) {
            # Default AP columns to blank
            $AP_Number = ""
            $Due_Date = ""

            $isSecArchMatched = $false
            $isActionPlanMatched = $false

            foreach ($exception in $exceptions) {
                # Match SPN and Azure object
                $spnMatch = $false
                if ($exception.spnObjectID) {
                    $spnMatch = ($lineItem.AppObjectID -eq $exception.spnObjectID)
                } elseif ($exception.spnNameLike) {
                    $spnMatch = ($lineItem.AppDisplayName -like "*$($exception.spnNameLike)*")
                }

                $azObjectMatch = $false
                if ($exception.azObjectScopeID) {
                    $azObjectMatch = ($lineItem.AzureObjectScopeID -eq $exception.azObjectScopeID)
                } elseif ($exception.azObjectNameLike) {
                    $azObjectMatch = ($lineItem.ObjectName -like "*$($exception.azObjectNameLike)*")
                }

                # Full match condition
                if ($spnMatch -and $azObjectMatch -and
                    ($lineItem.PrivRole -eq $exception.role) -and
                    ($lineItem.ObjectType -eq $exception.azScopeType) -and
                    ($lineItem.AppEONID -eq $exception.spnEonid)) {

                    # Check for SecArch match
                    if ($exception.SecArch) {
                        $isSecArchMatched = $true
                        break
                    }

                    # Check for ActionPlan match
                    if ($exception.ActionPlan) {
                        $isActionPlanMatched = $true
                        $AP_Number = $exception.ActionPlan
                        $Due_Date = $exception.expiration_date
                    }
                }
            }

            # Skip SecArch matches
            if ($isSecArchMatched) { continue }

            # Add ActionPlan details to the current line
            $line = $lineItem | Select-Object *  # Preserve all columns dynamically
            $line | Add-Member -MemberType NoteProperty -Name "AP_Number" -Value $AP_Number -Force
            $line | Add-Member -MemberType NoteProperty -Name "Due_Date" -Value $Due_Date -Force

            # Append line item to filtered dataset
            $filteredDataset += $line
        }

        # Output results
        if ($outputAsCsv) {
            $filteredDataset | Export-Csv -Path $outputCsvPath -NoTypeInformation
            Write-Host "Filtered dataset saved to: $outputCsvPath"
        } else {
            return $filteredDataset
        }
    }
    catch {
        Write-Error "An error occurred: $_"
        throw $_
    }
}
