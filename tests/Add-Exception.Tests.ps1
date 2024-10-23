# Add-Exception.Tests.ps1
Describe "Add-Exception Function" {

    BeforeAll {
        # Load the ExceptionManager module that contains the Add-Exception function
        Import-Module "$PSScriptRoot\ExceptionManager.psm1" -ErrorAction Stop

        # Define paths for test files and mocks
        $exceptionsPath = "$PSScriptRoot\mock-exceptions.json"
        $mockDataset = @"
AppObjectID,AppDisplayName,AzureObjectScopeID,ObjectName,AppEonid,PrivRole,Tenant
1234,TestApp,RG1234,ResourceGroup1,EON1234,Owner,Prod
5678,SampleApp,MG5678,ManagementGroup1,EON5678,Contributor,QA
9101,AnotherApp,RG9101,ResourceGroup2,EON9101,Owner,Dev
"@ | ConvertFrom-Csv

        # Mock the config.json file
        $mockConfig = @{
            exceptionsPath = $exceptionsPath
            csaEnforced = $false
        } | ConvertTo-Json
        Set-Content -Path ".\config.json" -Value $mockConfig
    }

    AfterEach {
        # Reset mock exceptions.json file to default after each test
        $mockExceptions = @(
            @{ spn_object_id = "1234"; spn_name_like = $null; azObjectScopeID = $null; azObjectNameLike = $null; spn_eonid = "EON1234"; tenant = "Prod" },
            @{ spn_object_id = $null; spn_name_like = "*SampleApp*"; azObjectScopeID = $null; azObjectNameLike = $null; spn_eonid = "EON5678"; tenant = "QA" }
        ) | ConvertTo-Json
        Set-Content -Path $exceptionsPath -Value $mockExceptions
    }

    Context "Valid Input Scenarios" {

        It "should add a new exception with spnObjectID" {
            # Arrange
            $spnObjectID = "9101"
            $azScopeType = "RG"
            $PrivRole = "Owner"
            $azObjectScopeID = "RG9101"

            # Act: Call the function
            Add-Exception -spnObjectID $spnObjectID -azScopeType $azScopeType -PrivRole $PrivRole -azObjectScopeID $azObjectScopeID -exceptionsPath $exceptionsPath

            # Assert: Ensure the exception is added
            $exceptions = Get-Content -Path $exceptionsPath | ConvertFrom-Json
            $exceptions | Where-Object { $_.spn_object_id -eq "9101" } | Should -Not -BeNullOrEmpty
        }

        It "should handle spn_name_like and translate tenant correctly" {
            # Arrange
            $spnNameLike = "*AnotherApp*"
            $azScopeType = "RG"
            $PrivRole = "Owner"
            $spnEonid = "EON9101"
            $tenant = "3"  # Should be translated to Dev

            # Act: Call the function
            Add-Exception -spnNameLike $spnNameLike -azScopeType $azScopeType -PrivRole $PrivRole -spnEonid $spnEonid -tenant $tenant -exceptionsPath $exceptionsPath

            # Assert: Ensure the exception is added and tenant is translated
            $exceptions = Get-Content -Path $exceptionsPath | ConvertFrom-Json
            $exceptions | Where-Object { $_.spn_name_like -eq "*AnotherApp*" -and $_.tenant -eq "Dev" } | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error Handling Scenarios" {

        It "should throw an error when both spnObjectID and spn_name_like are provided" {
            # Arrange
            $spnObjectID = "9101"
            $spnNameLike = "*SampleApp*"

            # Act & Assert: Should throw an error
            { Add-Exception -spnObjectID $spnObjectID -spnNameLike $spnNameLike -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $exceptionsPath } | Should -Throw "Cannot use both spnObjectID and spnNameLike at the same time."
        }

        It "should throw an error when both SecArch and ActionPlan are provided" {
            # Arrange
            $spnObjectID = "9101"
            $SecArch = "ARCH1234"
            $ActionPlan = "PLAN5678"

            # Act & Assert: Should throw an error
            { Add-Exception -spnObjectID $spnObjectID -azScopeType "RG" -PrivRole "Owner" -SecArch $SecArch -ActionPlan $ActionPlan -exceptionsPath $exceptionsPath } | Should -Throw "Cannot have both SecArch and ActionPlan."
        }

        It "should throw an error when ActionPlan is provided without expiration_date" {
            # Arrange
            $spnObjectID = "9101"
            $ActionPlan = "PLAN5678"

            # Act & Assert: Should throw an error
            { Add-Exception -spnObjectID $spnObjectID -azScopeType "RG" -PrivRole "Owner" -ActionPlan $ActionPlan -exceptionsPath $exceptionsPath } | Should -Throw "ActionPlan requires an expiration date."
        }

        It "should throw an error when config.json is not found" {
            # Arrange: Delete the config.json file
            Remove-Item -Path ".\config.json" -Force

            # Act & Assert: Should throw an error
            { Add-Exception -spnObjectID "1234" -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $exceptionsPath } | Should -Throw "config.json not found."
        }
    }

    Context "CSA Enforcement Scenarios" {

        It "should enforce CSA when enabled in config.json" {
            # Arrange: Enable CSA in the config
            $mockConfig.csaEnforced = $true
            Set-Content -Path ".\config.json" -Value ($mockConfig | ConvertTo-Json)

            # Act & Assert: Ensure CSA validation works
            { Add-Exception -spnObjectID "1234" -spnEonid "EON1234" -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $exceptionsPath } | Should -Not -Throw
        }

        It "should throw an error if spnEonid is not found in the dataset when CSA is enforced" {
            # Arrange: Enable CSA in the config and provide invalid spnEonid
            $mockConfig.csaEnforced = $true
            Set-Content -Path ".\config.json" -Value ($mockConfig | ConvertTo-Json)

            # Act & Assert: Should throw an error for invalid spnEonid
            { Add-Exception -spnObjectID "1234" -spnEonid "EON9999" -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $exceptionsPath } | Should -Throw "Invalid spnEonid. The EonID does not match any CSA data in the dataset."
        }
    }
}
