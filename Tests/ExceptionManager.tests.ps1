
Describe 'Test-DateFormat Function Tests' {
    
    It 'Should accept a valid date in yyyy-MM-dd format' {
        $result = Test-DateFormat -date "2024-10-21"
        $result | Should -Be $true
    }

    It 'Should reject an invalid date that does not exist' {
        $result = Test-DateFormat -date "2024-02-30"
        $result | Should -Be $false
    }

    It 'Should reject an incorrectly formatted date' {
        $result = Test-DateFormat -date "10-21-2024"
        $result | Should -Be $false
    }

    It 'Should reject an empty date string' {
        $result = Test-DateFormat -date ""
        $result | Should -Be $false
    }

    It 'Should reject a date string with only whitespace' {
        $result = Test-DateFormat -date "    "
        $result | Should -Be $false
    }
}

Describe 'Add-Exception Function Tests' {


     # Mock the JSON file path for testing
     $testJsonFile = ".\Tests\test_exceptions.json"
     $testConfigFile = ".\Tests\test-config.json"
    # Ensure the test JSON and config files are cleaned up before and after tests
    BeforeAll {
        # Clean up any existing test files
        if (Test-Path $testJsonFile) {
            Remove-Item $testJsonFile -Force
        }
        else {
            # Create a mock JSON file if it doesn't exist
            New-Item -Path $testJsonFile -ItemType File | Out-Null
        }

        if (Test-Path $testConfigFile) {
            Remove-Item $testConfigFile -Force
        }
        else {
            # Create a mock config file if it doesn't exist
            New-Item -Path $testConfigFile -ItemType File | Out-Null
        }
    }

    # Create a mock config file for testing
    $configContent = @{
        csa_enforced = $false
        jsonFilePath = $testJsonFile
    } | ConvertTo-Json
    Set-Content -Path $testConfigFile -Value $configContent
}

It 'Should add a dynamic exception with SecArch and CSA fields' {
    # Act
    Add-Exception -spn_object_id "abc123" -roles @("Owner") -dynamic_spn $true -SecArch @{
        id         = "sec-001"
        date_added = "2024-10-21"
    } -spnEnv "Prod" -spn_eonid "eon-001" -azureObjectEnv "Prod" -AzScope_eonid "eon-002" -spnNameLike @("*admin*")

    # Assert
    $jsonContent = Get-Content -Path $testJsonFile | ConvertFrom-Json
    $jsonContent | Should -Not -BeNullOrEmpty
    $jsonContent[0].spn_object_id | Should -Be "abc123"
    $jsonContent[0].roles | Should -Contain "Owner"
    $jsonContent[0].dynamic_spn | Should -Be $true
    $jsonContent[0].SecArch.id | Should -Be "sec-001"
    $jsonContent[0].spnEnv | Should -Be "Prod"
    $jsonContent[0].spn_eonid | Should -Be "eon-001"
    $jsonContent[0].AzScope_eonid | Should -Be "eon-002"
}

It 'Should add a non-dynamic exception with ActionPlan and CSA fields' {
    # Act
    Add-Exception -spn_object_id "xyz789" -roles @("User Access Administrator") -ActionPlan @{
        id              = "plan-001"
        date_added      = "2024-09-15"
        expiration_date = "2025-09-15"
    } -spnEnv "Dev" -spn_eonid "eon-003" -azureObjectEnv "Dev" -spnNameLike @("*dev*") -azureObjectNameLike @("*network*")

    # Assert
    $jsonContent = Get-Content -Path $testJsonFile | ConvertFrom-Json
    $jsonContent | Should -Not -BeNullOrEmpty
    $jsonContent[1].spn_object_id | Should -Be "xyz789"
    $jsonContent[1].roles | Should -Contain "User Access Administrator"
    $jsonContent[1].ActionPlan.id | Should -Be "plan-001"
    $jsonContent[1].ActionPlan.date_added | Should -Be "2024-09-15"
    $jsonContent[1].spnEnv | Should -Be "Dev"
    $jsonContent[1].spn_eonid | Should -Be "eon-003"
    $jsonContent[1].azureObjectNameLike | Should -Contain "*network*"
}

It 'Should append multiple exceptions to the JSON file' {
    # Act: Add another exception
    Add-Exception -spn_object_id "def456" -roles @("Contributor") -dynamic_spn $false -ActionPlan @{
        id              = "plan-002"
        date_added      = "2024-11-15"
        expiration_date = "2025-11-15"
    } -spnEnv "QA" -spn_eonid "eon-004" -azureObjectEnv "QA" -spnNameLike @("*qa*")

    # Assert: Verify all exceptions exist in the JSON file
    $jsonContent = Get-Content -Path $testJsonFile | ConvertFrom-Json
    $jsonContent.Count | Should -Be 3

    # Check the first exception
    $jsonContent[0].spn_object_id | Should -Be "abc123"
    $jsonContent[0].SecArch.id | Should -Be "sec-001"

    # Check the second exception
    $jsonContent[1].spn_object_id | Should -Be "xyz789"
    $jsonContent[1].ActionPlan.id | Should -Be "plan-001"

    # Check the third exception
    $jsonContent[2].spn_object_id | Should -Be "def456"
    $jsonContent[2].ActionPlan.id | Should -Be "plan-002"
}

It 'Should throw an error if both SecArch and ActionPlan are provided' {
    $invalidException = @{
        spn_object_id       = "abc123"
        roles               = @("Owner")
        spnEnv              = "Prod"
        spn_eonid           = "eon-001"
        az_scope_type       = "RG"
        azureObjectEnv      = "Prod"
        AzScope_eonid       = "eon-002"
        spnNameLike         = @("*admin*")
        azureObjectNameLike = @("*prod-rg*")
        SecArch             = @{
            id         = "sec-001"
            date_added = "2024-10-21"
        }
        ActionPlan          = @{
            id              = "plan-001"
            date_added      = "2024-09-15"
            expiration_date = "2025-09-15"
        }
    }

    { 
        Add-Exception @invalidException 
    } | Should -Throw "Cannot have both SecArch and ActionPlan."

    AfterAll {
        # Clean up test files after tests
        if (Test-Path $testJsonFile) {
            Remove-Item $testJsonFile -Force
        }

        if (Test-Path $testConfigFile) {
            Remove-Item $testConfigFile -Force
        }
    }
}
#endregion
