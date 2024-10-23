<#
.SYNOPSIS
    Loads the dataset from the newest file based on a wildcard pattern in the dataset path.

.DESCRIPTION
    This function searches for the most recent CSV file in the specified folder matching the given wildcard pattern 
    (with a date suffix) and loads it into memory for validation purposes.

.PARAMETER datasetDir
    The directory where the dataset files are stored.

.PARAMETER filenamePattern
    The base filename pattern for the dataset files (e.g., "filename_"). The function will search for files 
    that match this pattern followed by a date in MM_DD_YY format.

.RETURNS
    The loaded dataset as a CSV.
#>

function Get-Dataset {
    param(
        [Parameter(Mandatory=$true)][string]$datasetDir,          # Directory for dataset files
        [Parameter(Mandatory=$true)][string]$filenamePattern     # Filename pattern (e.g., "filename_")
    )

    # Ensure the dataset directory exists
    if (-not (Test-Path -Path $datasetDir)) {
        throw "Dataset directory not found: $datasetDir"
    }

    # Find all matching files based on the filename pattern
    $files = Get-ChildItem -Path $datasetDir -Filter "$filenamePattern*.csv"

    if ($files.Count -eq 0) {
        throw "No dataset files found matching the pattern: $filenamePattern*.csv"
    }

    # Sort the files by the date portion of the filename (assumes MM_DD_YY format)
    $latestFile = $files | Sort-Object {
        # Extract the date from the filename and convert to a [DateTime] object
        $dateString = ($_ -replace "$filenamePattern", "") -replace ".csv", ""
        [datetime]::ParseExact($dateString, "MM_dd_yy", $null)
    } | Select-Object -Last 1

    # Load and return the dataset
    return Import-Csv -Path $latestFile.FullName
}
