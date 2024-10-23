# Get-Dataset.Tests.ps1
Describe "Get-Dataset Function" {

    BeforeAll {
        # Load the ExceptionManager module that contains the Get-Dataset function
        Import-Module "$PSScriptRoot\ExceptionManager.psm1" -ErrorAction Stop

        # Define paths and mock data
        $mockDatasetObject = @(
            [pscustomobject]@{AppObjectID="1234"; AppDisplayName="TestApp"; AzureObjectScopeID="RG1234"; ObjectName="ResourceGroup1"; AppEonid="EON1234"; PrivRole="Owner"},
            [pscustomobject]@{AppObjectID="5678"; AppDisplayName="SampleApp"; AzureObjectScopeID="MG5678"; ObjectName="ManagementGroup1"; AppEonid="EON5678"; PrivRole="Contributor"}
        )
    }

    AfterEach {
        # Reset after each test
    }

    Context "Using PowerShell Object as Input" {

        It "should return the dataset object when passed as input" {
            # Act: Call the function with the datasetObject parameter
            $result = Get-Dataset -datasetObject $mockDatasetObject

            # Assert: Ensure the result is the same as the provided object
            $result | Should -BeExactly $mockDatasetObject
        }

        It "should not attempt to load CSV if datasetObject is provided" {
            # Act: Call the function
            $result = Get-Dataset -datasetObject $mockDatasetObject

            # Assert: Ensure that no CSV-related actions are performed
            Should -Not -Invoke Import-Csv
        }
    }

    Context "Using CSV Files as Input" {

        It "should throw an error if dataset directory is not found" {
            # Arrange: Mock Test-Path to return $false for the dataset directory
            Mock Test-Path { return $false }

            # Act & Assert: Expect an error for missing directory
            { Get-Dataset -datasetDir "C:\NonExistentDir" -filenamePattern "dataset_" } | Should -Throw "Dataset directory not found"
        }

        It "should throw an error if no dataset files are found" {
            # Arrange: Mock the directory with no matching files
            Mock Get-ChildItem { @() }  # No files returned

            # Act & Assert: Expect an error for no files found
            { Get-Dataset -datasetDir "C:\DatasetDir" -filenamePattern "dataset_" } | Should -Throw "No dataset files found"
        }

        It "should load the latest dataset based on the file name date" {
            # Arrange: Mock files with dates in the name
            Mock Get-ChildItem {
                @(
                    @{ Name = "dataset_10_21_23.csv"; FullName = "C:\DatasetDir\dataset_10_21_23.csv" },
                    @{ Name = "dataset_10_22_23.csv"; FullName = "C:\DatasetDir\dataset_10_22_23.csv" },
                    @{ Name = "dataset_10_23_23.csv"; FullName = "C:\DatasetDir\dataset_10_23_23.csv" }
                ) | ForEach-Object { New-Object PSObject -Property $_ }
            }

            # Mock Import-Csv to simulate loading data
            Mock Import-Csv { return @{"Mock"="Dataset"} }

            # Act: Call the function to load the latest dataset
            $result = Get-Dataset -datasetDir "C:\DatasetDir" -filenamePattern "dataset_"

            # Assert: Ensure the latest file (dataset_10_23_23.csv) was loaded
            $result | Should -Contain @{"Mock"="Dataset"}
        }
    }

    Context "Edge Cases" {

        It "should handle files without proper date format gracefully" {
            # Arrange: Mock Get-ChildItem with files that don't match the expected date pattern
            Mock Get-ChildItem {
                @(
                    @{ Name = "dataset_invalid.csv"; FullName = "C:\DatasetDir\dataset_invalid.csv" },
                    @{ Name = "dataset_no_date.csv"; FullName = "C:\DatasetDir\dataset_no_date.csv" }
                ) | ForEach-Object { New-Object PSObject -Property $_ }
            }

            # Mock Import-Csv to simulate data
            Mock Import-Csv { return @{"Mock"="Dataset"} }

            # Act & Assert: The function should not throw an error but skip invalid files
            { Get-Dataset -datasetDir "C:\DatasetDir" -filenamePattern "dataset_" } | Should -Not -Throw
        }

        It "should return the correct error when there is no valid input (PowerShell object or CSV)" {
            # Act & Assert: Expect an error when no valid input is provided
            { Get-Dataset } | Should -Throw "Dataset directory must be provided."
        }
    }
}
