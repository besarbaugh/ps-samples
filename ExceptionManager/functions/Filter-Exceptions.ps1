<#
.SYNOPSIS
    Filters out exceptions from the dataset based on the exceptions.json file.

.DESCRIPTION
    This function filters out over-privileged entries from the dataset based on the rules stored in the exceptions.json file.
    You can filter by SPN object ID, spnNameLike patterns, azObjectScopeID, azObjectNameLike, and more. Each exception is applied 
    to the dataset, and matching entries are removed, unless the ActionPlan has expired.

.PARAMETER exceptionFilePath
    The path to the exceptions.json file. Defaults to the path specified in config.json.

.PARAMETER dataset
    The dataset as an array of PowerShell objects to be filtered. Used when input/output is an array of objects.

.PARAMETER datasetPath
    The path to the daily audit dataset (CSV). Used when input/output is a CSV.

.PARAMETER outputObject
    Switch to output the filtered dataset as an array of PowerShell objects.

.PARAMETER outputPath
    The path where the filtered dataset (CSV) will be saved. Used when input/output is a CSV.

.EXAMPLE
    Filter-Exceptions -datasetPath "auditReport.csv" -outputPath "filteredReport.csv"
    
    Filters out entries in the auditReport.csv based on the exceptions in the exceptions.json file and saves the result to filteredReport.csv.

.EXAMPLE
    $dataset = Import-Csv "auditReport.csv"
    $filteredDataset = Filter-Exceptions -dataset $dataset
    
    Filters out entries in the dataset object based on the exceptions in the exceptions.json file and returns the filtered dataset as an object.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.1.2
#>

function Filter-Exceptions {
    [CmdletBinding(DefaultParameterSetName = 'CSV')]
    param (
        # Optional exception file path. If not provided, it defaults to the path in config.json.
        [Parameter(Mandatory = $false)]
        [string]$exceptionFilePath,

        # For object-based input/output
        [Parameter(Mandatory = $true, ParameterSetName = 'Object')]
        [array]$dataset,  # Dataset as an array of PowerShell objects

        [Parameter(Mandatory = $false, ParameterSetName = 'Object')]
        [switch]$outputObject,  # Output as an array of objects (default behavior in 'Object' set)

        # For CSV-based input/output
        [Parameter(Mandatory = $true, ParameterSetName = 'CSV')]
        [string]$datasetPath,  # Path to the dataset CSV

        [Parameter(Mandatory = $true, ParameterSetName = 'CSV')]
        [string]$outputPath  # Path to save the filtered dataset as a CSV
    )

    try {
        # Load configuration settings from config.json
        $configPath = ".\config.json"
        if (-not (Test-Path -Path $configPath)) {
            throw "config.json not found. Please ensure the configuration file is present."
        }

        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

        # Use exceptionFilePath from config.json if not provided as a parameter
        if (-not $exceptionFilePath) {
            $exceptionFilePath = $config.exceptionsPath
        }

        # Load existing exceptions
        if (-not (Test-Path -Path $exceptionFilePath)) {
            throw "Exceptions file not found at path: $exceptionFilePath"
        }

        $exceptions = Get-Content -Raw -Path $exceptionFilePath | ConvertFrom-Json

        # Handle dataset based on parameter set
        if ($PSCmdlet.ParameterSetName -eq 'Object') {
            # Input is an array of PowerShell objects
            $dataset = $dataset
        } elseif ($PSCmdlet.ParameterSetName -eq 'CSV') {
            # Input is a CSV file
            $dataset = Import-Csv -Path $datasetPath
        }

        # Loop over each exception and filter out matching entries from the dataset
        foreach ($exception in $exceptions) {
            # Check if ActionPlan has expired (if expiration_date exists)
            if ($exception.ActionPlan -and $exception.expiration_date) {
                $expirationDate = [datetime]::ParseExact($exception.expiration_date, 'MM/dd/yyyy', $null)
                if ($expirationDate -lt (Get-Date)) {
                    Write-Host "Skipping expired ActionPlan with expiration date $($exception.expiration_date)."
                    continue  # Skip this exception if the ActionPlan has expired
                }
            }

            # Apply the same filtering logic as in Add-Exception
            $dataset = $dataset | Where-Object {
                $spnMatch = $false
                $azObjectMatch = $false

                # Handle spnObjectID vs spnNameLike logic
                if ($exception.spnObjectID) {
                    # If using spnObjectID, ignore spnNameLike filtering
                    $spnMatch = ($_.AppObjectID -ieq $exception.spnObjectID)
                } elseif ($exception.spnNameLike) {
                    # If using spnNameLike, ignore spnObjectID filtering
                    $spnMatch = ($_.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                }

                # Handle azObjectScopeID vs azObjectNameLike logic
                if ($exception.azObjectScopeID) {
                    # If using azObjectScopeID, ignore azObjectNameLike filtering
                    $azObjectMatch = ($_.AzureObjectScopeID -eq $exception.azObjectScopeID)
                } elseif ($exception.azObjectNameLike) {
                    # If using azObjectNameLike, ignore azObjectScopeID filtering
                    $azObjectMatch = ($_.ObjectName -ilike "*$($exception.azObjectNameLike)*")
                }

                # Return only entries that DO NOT match the exception logic
                -not (
                    $spnMatch -and
                    $azObjectMatch -and
                    ($_.PrivRole -eq $exception.role) -and
                    ($_.ObjectType -eq $exception.azScopeType) -and
                    ($_.Tenant -ieq $exception.tenant)
                )
            }
        }

        # Output the filtered dataset
        if ($PSCmdlet.ParameterSetName -eq 'Object') {
            # Return filtered dataset as an object if outputObject switch is set
            if ($outputObject) {
                return $dataset
            }
        } elseif ($PSCmdlet.ParameterSetName -eq 'CSV') {
            # Save the filtered dataset as a CSV file
            $dataset | Export-Csv -Path $outputPath -NoTypeInformation
            Write-Host "Filtered dataset saved to $outputPath."
        }
    }
    catch {
        Write-Error "An error occurred in Filter-Exceptions: $_"
        throw $_
    }
}

