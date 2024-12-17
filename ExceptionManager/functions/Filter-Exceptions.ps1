function Filter-Exceptions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$exceptionsPath,
        [Parameter(Mandatory = $true)][string]$datasetPath,
        [Parameter(Mandatory = $false)][string]$outputPath
    )

    try {
        # Validate file paths
        if (-not (Test-Path -Path $exceptionsPath)) {
            throw "Exceptions file not found: $exceptionsPath"
        }
        if (-not (Test-Path -Path $datasetPath)) {
            throw "Dataset file not found: $datasetPath"
        }

        # Load exceptions and dataset
        $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
        $dataset = Import-Csv -Path $datasetPath

        # Prepare output dataset
        $remainingDataset = @()

        Write-Verbose "Filtering dataset with SecArch and ActionPlan exceptions..."

        foreach ($lineItem in $dataset) {
            $isSecArch = $false
            $AP_Number = "N/A"
            $Due_Date = "N/A"

            foreach ($exception in $exceptions) {
                # Initialize flags
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
                        $isSecArch = $true
                        break
                    }

                    if ($exception.ActionPlan) {
                        $AP_Number = $exception.ActionPlan
                        $Due_Date = $exception.expiration_date
                    }
                }
            }

            # Keep items not covered by SecArch and add AP columns
            if (-not $isSecArch) {
                $lineItem | Add-Member -MemberType NoteProperty -Name "AP_Number" -Value $AP_Number -Force
                $lineItem | Add-Member -MemberType NoteProperty -Name "Due_Date" -Value $Due_Date -Force
                $remainingDataset += $lineItem
            }
        }

        # Output results
        if ($outputPath) {
            $remainingDataset | Export-Csv -Path $outputPath -NoTypeInformation
            Write-Host "Filtered dataset saved to: $outputPath"
        } else {
            return $remainingDataset
        }

    } catch {
        Write-Error "An error occurred: $_"
        throw $_
    }
}
