<#
.SYNOPSIS
    Filters dataset based on exceptions.json:
    - Removes rows covered by SecArch exceptions.
    - Marks remaining rows with ActionPlan details (`AP_Number` and `Due_Date`) if applicable.

.DESCRIPTION
    - SecArch matches take precedence: Rows are removed immediately.
    - ActionPlan matches mark rows with `AP_Number` and `Due_Date`.
    - Input dataset fields are preserved, and new columns are added dynamically.

.PARAMETER exceptionsPath
    Path to the `exceptions.json` file.

.PARAMETER datasetPath
    Path to the dataset CSV file.

.PARAMETER outputAsCsv
    Outputs the filtered dataset to a CSV file.

.PARAMETER outputCsvPath
    Path for the output CSV file.

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

        # Step 1: Filter SecArch exceptions
        $remainingDataset = @()
        foreach ($lineItem in $dataset) {
            $isSecArch = $false

            foreach ($exception in $exceptions) {
                if ($exception.SecArch) {
                    # Matching logic for SecArch
                    $spnMatch = $false
                    $azObjectMatch = $false

                    if ($exception.spnObjectID) {
                        $spnMatch = ($lineItem.AppObjectID -eq $exception.spnObjectID)
                    } elseif ($exception.spnNameLike) {
                        $spnMatch = ($lineItem.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                    }

                    if ($exception.azObjectScopeID) {
                        $azObjectMatch = ($lineItem.AzureObjectScopeID -eq $exception.azObjectScopeID)
                    } elseif ($exception.azObjectNameLike) {
                        $azObjectMatch = ($lineItem.ObjectName -ilike "*$($exception.azObjectNameLike)*")
                    }

                    if ($spnMatch -and $azObjectMatch -and
                        ($lineItem.PrivRole -eq $exception.role) -and
                        ($lineItem.ObjectType -eq $exception.azScopeType) -and
                        ($lineItem.AppEONID -eq $exception.spnEonid)) {
                        $isSecArch = $true
                        break
                    }
                }
            }

            if (-not $isSecArch) {
                $remainingDataset += $lineItem
            }
        }

        # Step 2: Process ActionPlan matches
        $finalDataset = @()
        foreach ($lineItem in $remainingDataset) {
            # Default AP fields to blank
            $AP_Number = ""
            $Due_Date = ""

            foreach ($exception in $exceptions) {
                if ($exception.ActionPlan) {
                    # Matching logic for ActionPlan
                    $spnMatch = $false
                    $azObjectMatch = $false

                    if ($exception.spnObjectID) {
                        $spnMatch = ($lineItem.AppObjectID -eq $exception.spnObjectID)
                    } elseif ($exception.spnNameLike) {
                        $spnMatch = ($lineItem.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                    }

                    if ($exception.azObjectScopeID) {
                        $azObjectMatch = ($lineItem.AzureObjectScopeID -eq $exception.azObjectScopeID)
                    } elseif ($exception.azObjectNameLike) {
                        $azObjectMatch = ($lineItem.ObjectName -ilike "*$($exception.azObjectNameLike)*")
                    }

                    if ($spnMatch -and $azObjectMatch -and
                        ($lineItem.PrivRole -eq $exception.role) -and
                        ($lineItem.ObjectType -eq $exception.azScopeType) -and
                        ($lineItem.AppEONID -eq $exception.spnEonid)) {
                        $AP_Number = $exception.ActionPlan
                        $Due_Date = $exception.expiration_date
                        break  # Stop at the first AP match
                    }
                }
            }

            # Add AP fields dynamically
            $line = $lineItem | Select-Object *
            $line | Add-Member -MemberType NoteProperty -Name "AP_Number" -Value $AP_Number -Force
            $line | Add-Member -MemberType NoteProperty -Name "Due_Date" -Value $Due_Date -Force
            $finalDataset += $line
        }

        # Step 3: Output results
        if ($outputAsCsv) {
            $finalDataset | Export-Csv -Path $outputCsvPath -NoTypeInformation
            Write-Host "Filtered dataset saved to: $outputCsvPath"
        } else {
            return $finalDataset
        }
    }
    catch {
        Write-Error "An error occurred: $_"
        throw $_
    }
}
