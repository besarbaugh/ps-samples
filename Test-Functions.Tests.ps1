# Test-Functions.Tests.ps1

# Import the functions to test
. "$PSScriptRoot\ExceptionManager.ps1"

Describe "Test-DateFormat" {
    It "Should return true for a valid date" {
        $result = Test-DateFormat -date "2024-10-21"
        $result | Should -Be $true
    }

    It "Should return false for an invalid date" {
        $result = Test-DateFormat -date "2024-02-30"
        $result | Should -Be $false
    }

    It "Should return false for incorrect format" {
        $result = Test-DateFormat -date "10-21-2024"
        $result | Should -Be $false
    }

    It "Should return false for empty date" {
        $result = Test-DateFormat -date ""
        $result | Should -Be $false
    }
}

Describe "Add-Exception" {
    BeforeAll {
        # Create a temporary JSON file for testing
        $global:jsonFilePath = ".\test_exceptions.json"
        @() | ConvertTo-Json -Depth 5 | Set-Content -Path $global:jsonFilePath
        $global:configPath = ".\test-config.json"
        @{"jsonFilePath" = $global:jsonFilePath} | ConvertTo-Json -Depth 5 | Set-Content -Path $global:configPath
    }

    AfterAll {
        # Clean up test JSON file
        Remove-Item -Path $global:jsonFilePath -Force
        Remove-Item -Path $global:configPath -Force
    }

    It "Should add an exception successfully" {
        $spnId = "abc123"
        $roles = @("Owner")
        $SecArch = @{ id = "sec-001"; date_added = "2024-10-21" }
        $spnEnv = "Prod"
        $spnEonId = "eon-001"
        $azureObjectEnv = "AzureEnv"
        $azScopeEonId = "scope-eon-001"
        $spnNameLike = @("*example*")
        $azureObjectNameLike = @("*resource*")

        # Run Add-Exception
        Add-Exception -spn_object_id $spnId -roles $roles -SecArch $SecArch -spnEnv $spnEnv -spn_eonid $spnEonId -azureObjectEnv $azureObjectEnv -AzScope_eonid $azScopeEonId -spnNameLike $spnNameLike -azureObjectNameLike $azureObjectNameLike

        # Validate the exception was added
        $existingExceptions = Get-Content -Path $global:jsonFilePath | ConvertFrom-Json
        $existingExceptions | Should -HaveCount 1
        $existingExceptions[0].spn_object_id | Should -Be $spnId
    }
}
