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

        # Iterate through each exception to find matching entries in the dataset
        foreach ($exception in $allExceptions) {
            $dataset = $dataset | ForEach-Object {
                $lineItem = $_
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

                # If outputExceptions switch is set, capture matching items
                if ($outputExceptions) {
                    if ($spnMatch -and $azObjectMatch -and $tenantMatch -and
                        ($lineItem.PrivRole -eq $exception.role) -and
                        ($lineItem.ObjectType -eq $exception.az_scope_type)) {
                        
                        # Create a copy of the line item and add exception-specific fields
                        $matchedItem = $lineItem | Select-Object *
                        $matchedItem | Add-Member -MemberType NoteProperty -Name "SecArch" -Value $exception.SecArch -Force
                        $matchedItem | Add-Member -MemberType NoteProperty -Name "ActionPlan" -Value $exception.ActionPlan -Force
                        $matchedItem | Add-Member -MemberType NoteProperty -Name "expiration_date" -Value $exception.expiration_date -Force
                        $matchedItem | Add-Member -MemberType NoteProperty -Name "date_added" -Value $exception.date_added -Force
                        
                        $matchingItems += $matchedItem
                    }
                    $lineItem  # Passes the item through to the next iteration
                } else {
                    # Otherwise, remove matching items from the dataset
                    if (!($spnMatch -and $azObjectMatch -and $tenantMatch -and
                          ($lineItem.PrivRole -eq $exception.role) -and
                          ($lineItem.ObjectType -eq $exception.az_scope_type))) {
                        $lineItem  # Include non-matching items in output
                    }
                }
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
            # Otherwise, output the filtered dataset
            if ($outputAsCsv) {
                $dataset | Export-Csv -Path $outputCsvPath -NoTypeInformation
                Write-Host "Filtered results saved to: $outputCsvPath"
            } else {
                return $dataset
            }
        }

    } catch {
        Write-Error "An error occurred while filtering exceptions: $_"
        throw $_
    }
}
