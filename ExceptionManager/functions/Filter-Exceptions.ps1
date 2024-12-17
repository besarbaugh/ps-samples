<#
.SYNOPSIS
    Filters a dataset to exclude SecArch-covered items and flags items under ActionPlan with AP_Number and Due_Date.

.DESCRIPTION
    Processes a dataset (CSV or object array) and filters out rows matching exceptions covered by SecArch.
    Rows matching ActionPlan exceptions are retained and annotated with new columns: AP_Number and Due_Date.

.PARAMETER exceptionsPath
    The path to the exceptions JSON file.

.PARAMETER datasetPath
    The path to the input dataset CSV file.

.PARAMETER outputPath
    Optional. Path to save the filtered output dataset. If not provided, the function returns the filtered dataset.

.PARAMETER verboseLogging
    Optional switch to enable detailed logging during execution for debugging purposes.

.OUTPUTS
    - A filtered dataset with SecArch items removed and ActionPlan matches annotated.
    - Returns the data object or writes to a CSV file.

.EXAMPLE
    Filter-Exceptions -exceptionsPath ".\exceptions.json" -datasetPath ".\dataset.csv" -outputPath ".\filtered_output.csv"

.EXAMPLE
    $filteredData = Filter-Exceptions -exceptionsPath ".\exceptions.json" -datasetPath ".\dataset.csv" -verboseLogging
    $filteredData | Format-Table
#>

function Filter-Exceptions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Path to the exceptions JSON file.")]
        [string]$exceptionsPath,

        [Parameter(Mandatory = $true, HelpMessage = "Path to the input dataset CSV file.")]
        [string]$datasetPath,

        [Parameter(Mandatory = $false, HelpMessage = "Path to save the output CSV file.")]
        [string]$outputPath,

        [Parameter(Mandatory = $false, HelpMessage = "Enable detailed logging.")]
        [switch]$verboseLogging
    )

    try {
        # Step 1: Validate File Paths
        if (-not (Test-Path -Path $exceptionsPath)) {
            throw "Exceptions file not found: $exceptionsPath"
        }
        if (-not (Test-Path -Path $datasetPath)) {
            throw "Dataset file not found: $datasetPath"
        }

        # Step 2: Load Exceptions and Dataset
        Write-Verbose "Loading exceptions from: $exceptionsPath"
        $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
        if (-not $exceptions) { throw "Exceptions file is empty or invalid JSON." }

        Write-Verbose "Loading dataset from: $datasetPath"
        $dataset = Import-Csv -Path $datasetPath
        if (-not $dataset) { throw "Dataset file is empty or not properly formatted." }

        # Step 3: Prepare Output Dataset
        $remainingDataset = @()

        Write-Verbose "Starting exception filtering..."
        foreach ($lineItem in $dataset) {
            # Default values for AP columns
            $AP_Number = "N/A"
            $Due_Date = "N/A"
            $isSecArch = $false

            foreach ($exception in $exceptions) {
                # Match Logic
                $spnMatch = $false
                $azObjectMatch = $false

                # SPN Matching Logic
                if ($exception.spnObjectID) {
                    $spnMatch = ($lineItem.AppObjectID -eq $exception.spnObjectID)
                } elseif ($exception.spnNameLike) {
                    $spnMatch = ($lineItem.AppDisplayName -ilike "*$($exception.spnNameLike)*") `
                                -and ($lineItem.AppEONID -eq $exception.spnEonid)
                }

                # Azure Object Matching Logic
                if ($exception.azObjectScopeID) {
                    $azObjectMatch = ($lineItem.AzureObjectScopeID -eq $exception.azObjectScopeID)
                } elseif ($exception.azObjectNameLike) {
                    $azObjectMatch = ($lineItem.ObjectName -ilike "*$($exception.azObjectNameLike)*") `
                                     -and ($lineItem.AppEONID -eq $exception.spnEonid)
                }

                # Final Match Condition
                if (
                    ($spnMatch -or $azObjectMatch) -and
                    ($lineItem.PrivRole -eq $exception.role) -and
                    ($lineItem.ObjectType -eq $exception.azScopeType) -and
                    ($lineItem.AppEONID -eq $exception.spnEonid)
                ) {
                    if ($exception.SecArch) {
                        Write-Verbose "SecArch match found. Skipping line: $($lineItem.AppObjectID)"
                        $isSecArch = $true
                        break
                    }
                    if ($exception.ActionPlan) {
                        $AP_Number = $exception.ActionPlan
                        $Due_Date = $exception.expiration_date
                    }
                }
            }

            # Add non-SecArch rows to output
            if (-not $isSecArch) {
                $lineItem | Add-Member -MemberType NoteProperty -Name "AP_Number" -Value $AP_Number -Force
                $lineItem | Add-Member -MemberType NoteProperty -Name "Due_Date" -Value $Due_Date -Force
                $remainingDataset += $lineItem
            }
        }

        # Step 4: Output Results
        if ($outputPath) {
            Write-Verbose "Saving filtered dataset to: $outputPath"
            $remainingDataset | Export-Csv -Path $outputPath -NoTypeInformation
            Write-Host "Filtered dataset saved to: $outputPath"
        } else {
            Write-Verbose "Returning filtered dataset as object."
            return $remainingDataset
        }

    } catch {
        Write-Error "An error occurred in Filter-Exceptions: $_"
        throw $_
    }
}
