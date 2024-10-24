# Get-Dataset.Tests.ps1
# Purpose: Pester tests for Get-Dataset function in the ExceptionManager module

Describe 'Get-Dataset Function Tests' {

    # No need for BeforeAll to set up the test data, as TestAll.ps1 already does that

    Context 'Validating Get-Dataset Function' {

        It 'Should return the provided dataset object directly' {
            # Call Get-Dataset with datasetObject
            $datasetObject = @(
                [pscustomobject]@{ AppEonid = "EON123"; AppEnv = "Prod"; AppName = "App1"; AppObjectID = "AppObject123"; PrivRole = "Owner"; AzureScopeType = "RG"; AzureObjectScopeID = "RGObjectID1"; AzureObjectName = "RGName1" },
                [pscustomobject]@{ AppEonid = "EON456"; AppEnv = "QA"; AppName = "App2"; AppObjectID = "AppObject456"; PrivRole = "Contributor"; AzureScopeType = "MG"; AzureObjectScopeID = "MGObjectID2"; AzureObjectName = "MGName2" }
            )

            $result = Get-Dataset -datasetObject $datasetObject

            # Verify that the returned object is the same as the input datasetObject
            $result.Count | Should -Be $datasetObject.Count
            $result[0].AppEonid | Should -Be $datasetObject[0].AppEonid
        }

        It 'Should load the latest dataset from a file' {
            # Call Get-Dataset to load from the dataset file (assumes TestAll has already created the dataset file)
            $testDatasetDir = ".\tests\testdata"
            $filenamePattern = "dataset_"
            $result = Get-Dataset -datasetDir $testDatasetDir -filenamePattern $filenamePattern

            # Verify that the dataset was loaded from the file
            $result.Count | Should -Be 2
            $result[0].AppEonid | Should -Be "EON123"
        }

        It 'Should throw an error if no dataset directory is provided' {
            { Get-Dataset -datasetObject $null } | Should -Throw "Dataset directory must be provided."
        }

        It 'Should throw an error if no matching files are found in datasetDir' {
            { Get-Dataset -datasetDir ".\tests\testdata" -filenamePattern "invalid_pattern_" } | Should -Throw "No dataset files found"
        }

        It 'Should throw an error if datasetDir is invalid' {
            { Get-Dataset -datasetDir ".\invalid_dir" -filenamePattern "dataset_" } | Should -Throw "Dataset directory not found"
        }
    }

    # No AfterAll block needed as TestAll handles cleanup
}
