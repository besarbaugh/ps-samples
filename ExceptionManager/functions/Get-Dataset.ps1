<#
.SYNOPSIS
    Loads the dataset from a PowerShell object or the newest file based on a wildcard pattern in the dataset path.

.DESCRIPTION
    This function accepts either a PowerShell object (array of objects) or a CSV file path. If a file path is 
    provided, it will load the newest CSV file in the specified folder matching the given wildcard pattern 
    (with a date suffix) and load it into memory.

.PARAMETER datasetObject
    Optional parameter. A PowerShell object (array of objects) representing the dataset. If provided, the object will be returned directly.

.PARAMETER datasetDir
    Optional parameter. The directory where the dataset files are stored. If no datasetObject is passed, this must be provided.

.PARAMETER filenamePattern
    Optional parameter. The base filename pattern for the dataset files (e.g., "filename_"). The function will search 
    for files that match this pattern followed by a date in MM_DD_YY format, and return the latest file based on modification time.

.RETURNS
    The loaded dataset as an array of objects or a CSV file.

.NOTES
    Author: Brian Sarbaugh
    Version: 1.0.0
    The function ensures that the most recent dataset file is used if datasetObject is not provided.

.EXAMPLE
    # Load a dataset from a PowerShell object
    $myDataset = @(
        @{AppObjectID = "1234"; AppDisplayName = "sampleApp"; PrivRole = "Owner"},
        @{AppObjectID = "5678"; AppDisplayName = "anotherApp"; PrivRole = "Contributor"}
    )
    Get-Dataset -datasetObject $myDataset

.EXAMPLE
    # Load the newest dataset file based on a pattern and directory
    Get-Dataset -datasetDir "C:\Datasets\" -filenamePattern "myDataset_"
#>

function Get-Dataset {
    param(
        [Parameter(Mandatory = $false)][array]$datasetObject,  # Accepts a PowerShell object array
        [Parameter(Mandatory = $false)][string]$datasetDir,  # Directory containing dataset CSV files
        [Parameter(Mandatory = $false)][string]$filenamePattern  # Pattern to match dataset filenames
    )

    try {
        if ($datasetObject) {
            # If datasetObject is passed, return it directly
            Write-Verbose "Returning provided PowerShell object as dataset."
            return $datasetObject
        }

        if (-not $datasetDir) {
            throw "Dataset directory must be provided if no datasetObject is passed."
        }

        if (-not (Test-Path -Path $datasetDir)) {
            throw "Dataset directory not found: $datasetDir"
        }

        # Get the latest dataset file based on the filename pattern
        $files = Get-ChildItem -Path $datasetDir -Filter "$filenamePattern*.csv" | Sort-Object LastWriteTime -Descending

        if (-not $files) {
            throw "No dataset files found matching the pattern '$filenamePattern' in $datasetDir."
        }

        $latestFile = $files[0]

        # Load the dataset from the latest CSV file
        $dataset = Import-Csv -Path $latestFile.FullName

        Write-Host "Successfully loaded dataset from file: $($latestFile.FullName)"
        return $dataset
    }
    catch {
        Write-Error "An error occurred in Get-Dataset: $_"
        throw $_
    }
}
