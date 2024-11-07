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

        # Initialize an array to hold matching exceptions if outputExceptions is set
        $matchingItems = @()

        # Iterate through each line item and apply all exceptions to check for matches
        foreach ($lineItem in $dataset) {
            # Create arrays to hold multiple matches if any
            $matchedSecArch = @()
            $matchedActionPlan = @()
            $matchedExpirationDate = @()
            $matchedDateAdded = @()

            # Check each exception to see if it matches the current line item
            foreach ($exception in $allExceptions) {
                $spnMatch = $false
                $azObjectMatch = $false
                $tenantMatch = $true  # Default to true, modify only if tenant matching is required

                # Handle SPN matching (spnObjectID vs spnNameLike)
                if ($exception.spnObjectID) {
                    $spnMatch = ($lineItem.AppObjectID -eq $exception.spnObjectID)
                } elseif ($exception.spnNameLike) {
                    $spnMatch = ($lineItem.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                    # Apply tenant matching only if spnNameLike is used
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

                # If all criteria match, add the exception details to arrays
                if ($spnMatch -and $azObjectMatch -and $tenantMatch -and
                    ($lineItem.PrivRole -eq $exception.role) -and
                    ($lineItem.ObjectType -eq $exception.az_scope_type)) {

                    # Append matched exception details to the respective arrays
                    $matchedSecArch += $exception.SecArch
                    $matchedActionPlan += $exception.ActionPlan
                    $matchedExpirationDate += $exception.expiration_date
                    $matchedDateAdded += $exception.date_added
                }
            }

            # If matches were found and outputExceptions is set, add line item with details
            if ($outputExceptions -and $matchedSecArch.Count -gt 0) {
                # Clone the line item to add exception details
                $matchedItem = $lineItem | Select-Object *

                # Add arrays as properties for multiple match details
                $matchedItem | Add-Member -MemberType NoteProperty -Name "SecArch" -Value $matchedSecArch -Force
                $matchedItem | Add-Member -MemberType NoteProperty -Name "ActionPlan" -Value $matchedActionPlan -Force
                $matchedItem | Add-Member -MemberType NoteProperty -Name "expiration_date" -Value $matchedExpirationDate -Force
                $matchedItem | Add-Member -MemberType NoteProperty -Name "date_added" -Value $matchedDateAdded -Force

                $matchingItems += $matchedItem
            }
        }

        # Output matching items if outputExceptions is set
        if ($outputExceptions) {
            if ($outputAsCsv) {
                $matchingItems | Export-Csv -Path $outputCsvPath -NoTypeInformation
                Write-Host "Exceptions matching results saved to: $outputCsvPath"
            } else {
                return $matchingItems
            }
        } else {
            # Filtered (non-excepted) dataset if outputExceptions is not set
            $filteredDataset = $dataset | Where-Object {
                # Filter out items that matched any exception
                $matchingItems -notcontains $_
            }
            if ($outputAsCsv) {
                $filteredDataset | Export-Csv -Path $outputCsvPath -NoTypeInformation
                Write-Host "Filtered results saved to: $outputCsvPath"
            } else {
                return $filteredDataset
            }
        }

    } catch {
        Write-Error "An error occurred while filtering exceptions: $_"
        throw $_
    }
}
