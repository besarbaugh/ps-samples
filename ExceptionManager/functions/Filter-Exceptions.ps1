<#
.SYNOPSIS
    Filters out entries from the dataset based on the exceptions in exceptions.json or a provided PSObject.

.DESCRIPTION
    This function processes the dataset (CSV or PSObject) and filters out any entries that match the exceptions 
    defined in exceptions.json or a provided object. It ensures the validation logic aligns with the removalCount 
    logic in Add-Exception.ps1, handling mutually exclusive fields like spnObjectID vs spnNameLike and azObjectScopeID 
    vs azObjectNameLike. The user can choose to input and output in either CSV or PSObject format.

    The function also outputs the exception's lastModifiedBy and LastUpdated fields for tracking purposes.

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

.PARAMETER outputExceptions
    If specified, outputs matched items instead of filtered ones, along with fields such as lastModifiedBy and LastUpdated.

.EXAMPLE
    Filter-Exceptions -exceptionsPath ".\exceptions.json" -datasetPath ".\dataset.csv" -outputAsCsv
    
    Filters the dataset based on exceptions and outputs the result as a CSV file.

.EXAMPLE
    Filter-Exceptions -datasetObject $dataset -exceptionsPath ".\exceptions.json" -outputExceptions
    
    Filters the provided dataset object based on exceptions and returns the matching (excepted) items with details as a PSObject.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.1.0
    Filters the dataset according to the exceptions, including lastModifiedBy and LastUpdated in the output.
#>

function Filter-Exceptions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)][string]$exceptionsPath = ".\exceptions.json",
        [Parameter(Mandatory = $false)][string]$datasetPath = ".\dataset.csv",
        [Parameter(Mandatory = $false)][array]$datasetObject,
        [Parameter(Mandatory = $false)][switch]$outputAsCsv,
        [Parameter(Mandatory = $false)][string]$outputCsvPath = ".\filtered_output.csv",
        [Parameter(Mandatory = $false)][switch]$outputExceptions  # New switch to output matching (excepted) items
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

        # Combine SecArchExceptions and ActionPlanExceptions for filtering
        $allExceptions = @($exceptions.SecArchExceptions + $exceptions.ActionPlanExceptions)

        # Initialize arrays for matching and non-matching items
        $matchingItems = @()
        $nonMatchingItems = @()

        # Iterate through each line item and check against each exception
        foreach ($lineItem in $dataset) {
            # Initialize properties with "NA" as default values
            $secArch = "NA"
            $actionPlan = "NA"
            $expirationDate = "NA"
            $lastModifiedBy = "NA"
            $lastUpdated = "NA"
            $matchCount = 0

            foreach ($exception in $allExceptions) {
                # Default to false for matching variables
                $spnMatch = $false
                $azObjectMatch = $false
                $tenantMatch = $true  # Default to true, modify only if tenant matching is required

                # Handle SPN matching (spnObjectID vs spnNameLike)
                if ($exception.spnObjectID) {
                    $spnMatch = ($lineItem.AppObjectId -eq $exception.spnObjectID)
                } elseif ($exception.spnNameLike) {
                    $spnMatch = ($lineItem.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                    $tenantMatch = ($lineItem.Tenant -eq $exception.tenant)
                }

                # Handle Azure Object matching (azObjectScopeID vs azObjectNameLike)
                if ($exception.azObjectScopeID) {
                    $azObjectMatch = ($lineItem.AzureObjectScopeID -eq $exception.azObjectScopeID)
                } elseif (-not $exception.azObjectScopeID -and -not $exception.azObjectNameLike) {
                    $azObjectMatch = $true  # Apply to all objects of the scope type
                } elseif ($exception.azObjectNameLike) {
                    $azObjectMatch = ($lineItem.ObjectName -ilike "*$($exception.azObjectNameLike)*")
                }

                # Check if the line item matches the exception
                if ($spnMatch -and $azObjectMatch -and $tenantMatch -and
                    ($lineItem.PrivRole -eq $exception.role) -and
                    ($lineItem.ObjectType -eq $exception.azScopeType) -and
                    ($lineItem.AppEONID -eq $exception.spnEonid)) {
                    
                    # Increment match count
                    $matchCount++

                    # Only populate exception fields on the first match
                    if ($matchCount -eq 1) {
                        $secArch = $exception.SecArch
                        $actionPlan = $exception.ActionPlan
                        $expirationDate = $exception.expiration_date
                        $lastModifiedBy = $exception.lastModifiedBy
                        $lastUpdated = $exception.LastUpdated
                    }
                }
            }

            # Add to the respective output array based on match status
            if ($matchCount -gt 0) {
                # Clone the line item to add exception details if matched
                $matchedItem = $lineItem | Select-Object *
                $matchedItem | Add-Member -MemberType NoteProperty -Name "SecArch" -Value $secArch -Force
                $matchedItem | Add-Member -MemberType NoteProperty -Name "ActionPlan" -Value $actionPlan -Force
                $matchedItem | Add-Member -MemberType NoteProperty -Name "expiration_date" -Value $expirationDate -Force
                $matchedItem | Add-Member -MemberType NoteProperty -Name "lastModifiedBy" -Value $lastModifiedBy -Force
                $matchedItem | Add-Member -MemberType NoteProperty -Name "LastUpdated" -Value $lastUpdated -Force
                $matchingItems += $matchedItem
            } else {
                # Add non-matching items directly to nonMatchingItems array
                $nonMatchingItems += $lineItem
            }
        }

        # Determine which result set to output based on outputExceptions
        if ($outputExceptions) {
            if ($outputAsCsv) {
                $matchingItems | Export-Csv -Path $outputCsvPath -NoTypeInformation
                Write-Host "Exceptions matching results saved to: $outputCsvPath"
            } else {
                return $matchingItems
            }
        } else {
            if ($outputAsCsv) {
                $nonMatchingItems | Export-Csv -Path $outputCsvPath -NoTypeInformation
                Write-Host "Filtered results saved to: $outputCsvPath"
            } else {
                return $nonMatchingItems
            }
        }

    } catch {
        Write-Error "An error occurred while filtering exceptions: $_"
        throw $_
    }
}
