# Load the function to test
. "$PSScriptRoot/../functions/Filter-Exceptions.ps1"

Describe "Filter-Exceptions" {
    Context "Filtering a dataset with exceptions" {
        It "Should filter out matching items based on exceptions" {
            $dataset = @(
                @{ AppObjectID = "SPN1234"; AppDisplayName = "sampleApp"; PrivRole = "Owner"; ObjectType = "resourceGroup"; Tenant = "prodten"; AppEONID = "EON123" }
            )
            $result = Filter-Exceptions -datasetObject $dataset -exceptionsPath "$PSScriptRoot/../exceptions.json" -outputExceptions
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should return an empty array if no exceptions match the dataset" {
            $dataset = @(
                @{ AppObjectID = "SPN5678"; AppDisplayName = "nonMatchingApp"; PrivRole = "Contributor"; ObjectType = "subscription"; Tenant = "qaten"; AppEONID = "EON999" }
            )
            $result = Filter-Exceptions -datasetObject $dataset -exceptionsPath "$PSScriptRoot/../exceptions.json" -outputExceptions
            $result.Count | Should -Be 0
        }
    }
}
