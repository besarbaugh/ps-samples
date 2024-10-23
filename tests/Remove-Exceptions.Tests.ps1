# Remove-Exceptions.Tests.ps1
Describe "Remove-Exceptions Function" {

    BeforeAll {
        # Load the ExceptionManager module that contains the Remove-Exceptions function
        Import-Module "$PSScriptRoot\ExceptionManager.psm1" -ErrorAction Stop

        # Define mock dataset
        $mockDataset = @(
            [pscustomobject]@{ AppObjectID="1234"; AppDisplayName="TestApp"; ObjectName="ResourceGroup1"; AppEonid="EON1234"; PrivRole="Owner"; Tenant="Prod" },
            [pscustomobject]@{ AppObjectID="5678"; AppDisplayName="SampleApp"; ObjectName="ManagementGroup1"; AppEonid="EON5678"; PrivRole="Contributor"; Tenant="QA" },
            [pscustomobject]@{ AppObjectID="9101"; AppDisplayName="AnotherApp"; ObjectName="ResourceGroup2"; AppEonid="EON9101"; PrivRole="Owner"; Tenant="Dev" }
        )

        # Define mock exceptions.json
        $mockExceptions = @(
            @{ spn_object_id = "1234"; spn_name_like = $null; azObjectScopeID = $null; azObjectNameLike = $null; spn_eonid = "EON1234"; tenant = "Prod" },
            @{ spn_object_id = $null; spn_name_like = "*SampleApp*"; azObjectScopeID = $null; azObjectNameLike = $null; spn_eonid = "EON5678"; tenant = "QA" }
        ) | ConvertTo-Json

        # Write mock exceptions.json to file
        Set-Content -Path "$PSScriptRoot\mock-exceptions.json" -Value $mockExceptions
    }

    Context "Removing entries by spn_object_id" {

        It "should remove entries that match spn_object_id in exceptions" {
            # Act: Call the Remove-Exceptions function
            $result = Remove-Exceptions -data $mockDataset -exceptionsJsonPath "$PSScriptRoot\mock-exceptions.json"

            # Assert: Ensure the entry with spn_object_id 1234 is removed
            $result.AppObjectID | Should -Not -Contain "1234"
        }
    }

    Context "Removing entries by spn_name_like" {

        It "should remove entries that match spn_name_like pattern in exceptions" {
            # Act: Call the Remove-Exceptions function
            $result = Remove-Exceptions -data $mockDataset -exceptionsJsonPath "$PSScriptRoot\mock-exceptions.json"

            # Assert: Ensure the entry with spn_name_like *SampleApp* is removed
            $result.AppDisplayName | Should -Not -Contain "SampleApp"
        }
    }

    Context "Handling entries not in exceptions" {

        It "should not remove entries that do not match any exceptions" {
            # Act: Call the Remove-Exceptions function
            $result = Remove-Exceptions -data $mockDataset -exceptionsJsonPath "$PSScriptRoot\mock-exceptions.json"

            # Assert: Ensure the entry 'AnotherApp' is not removed
            $result.AppDisplayName | Should -Contain "AnotherApp"
        }
    }

    Context "Error Handling" {

        It "should throw an error if exceptions.json is not found" {
            # Arrange: Simulate missing exceptions.json file
            Remove-Item -Path "$PSScriptRoot\mock-exceptions.json" -Force

            # Act & Assert: Validate an error is thrown
            { Remove-Exceptions -data $mockDataset -exceptionsJsonPath "$PSScriptRoot\mock-exceptions.json" } | Should -Throw "exceptions.json file not found"
        }

        It "should throw an error if dataset is not provided" {
            # Act & Assert: Validate an error is thrown if dataset is missing
            { Remove-Exceptions -exceptionsJsonPath "$PSScriptRoot\mock-exceptions.json" } | Should -Throw "Dataset is required."
        }
    }

    Context "Case Insensitive Matching" {

        It "should handle case-insensitive matches for spn_name_like" {
            # Arrange: Modify the spn_name_like in exceptions to test case-insensitivity
            $mockExceptions = @(
                @{ spn_object_id = "1234"; spn_name_like = $null; azObjectScopeID = $null; azObjectNameLike = $null; spn_eonid = "EON1234"; tenant = "Prod" },
                @{ spn_object_id = $null; spn_name_like = "*sampleapp*"; azObjectScopeID = $null; azObjectNameLike = $null; spn_eonid = "EON5678"; tenant = "QA" }
            ) | ConvertTo-Json
            Set-Content -Path "$PSScriptRoot\mock-exceptions.json" -Value $mockExceptions

            # Act: Call the Remove-Exceptions function
            $result = Remove-Exceptions -data $mockDataset -exceptionsJsonPath "$PSScriptRoot\mock-exceptions.json"

            # Assert: Ensure case-insensitive match removes SampleApp
            $result.AppDisplayName | Should -Not -Contain "SampleApp"
        }
    }

    Context "Counting Removed Entries" {

        It "should output the correct removal count when using -removalCount" {
            # Arrange: Mock dataset and exceptions

            # Act: Call the Remove-Exceptions function with -removalCount
            $result = Remove-Exceptions -data $mockDataset -exceptionsJsonPath "$PSScriptRoot\mock-exceptions.json" -removalCount

            # Assert: Ensure the correct count of removed entries is shown (2)
            # Capture the Write-Host output to verify the removal count
            $result | Should -Not -Contain "1234"
            $result | Should -Not -Contain "5678"
        }
    }
}
