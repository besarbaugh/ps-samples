# ExceptionManager.Tests.ps1

Describe "ExceptionManager Module" {

    BeforeAll {
        # Load the ExceptionManager module that includes all functions
        Import-Module "$PSScriptRoot\ExceptionManager.psm1" -ErrorAction Stop
    }

    Context "Module Import" {

        It "should import Get-Dataset function" {
            # Act & Assert: Ensure the Get-Dataset function is available after module import
            Get-Command -Name Get-Dataset | Should -Not -BeNullOrEmpty
        }

        It "should import Add-Exception function" {
            # Act & Assert: Ensure the Add-Exception function is available after module import
            Get-Command -Name Add-Exception | Should -Not -BeNullOrEmpty
        }

        It "should import Test-SchemaValidation function" {
            # Act & Assert: Ensure the Test-SchemaValidation function is available after module import
            Get-Command -Name Test-SchemaValidation | Should -Not -BeNullOrEmpty
        }

        It "should import Remove-Exceptions function" {
            # Act & Assert: Ensure the Remove-Exceptions function is available after module import
            Get-Command -Name Remove-Exceptions | Should -Not -BeNullOrEmpty
        }
    }

    Context "Add-Exception Function Integration Test" {
        BeforeEach {
            # Mock config.json for Add-Exception tests
            $mockConfig = @{
                exceptionsPath = "$PSScriptRoot\mock-exceptions.json"
                csaEnforced = $false
            } | ConvertTo-Json
            Set-Content -Path "$PSScriptRoot\config.json" -Value $mockConfig

            # Mock exceptions.json
            $mockExceptions = @(
                @{ spn_object_id = "1234"; spn_name_like = $null; azObjectScopeID = $null; azObjectNameLike = $null; spn_eonid = "EON1234"; tenant = "Prod" }
            ) | ConvertTo-Json
            Set-Content -Path "$PSScriptRoot\mock-exceptions.json" -Value $mockExceptions
        }

        It "should add a new exception" {
            # Arrange
            $spnObjectID = "5678"
            $azScopeType = "MG"
            $PrivRole = "Contributor"
            $azObjectScopeID = "MG5678"

            # Act: Call Add-Exception
            Add-Exception -spnObjectID $spnObjectID -azScopeType $azScopeType -PrivRole $PrivRole -azObjectScopeID $azObjectScopeID -exceptionsPath "$PSScriptRoot\mock-exceptions.json"

            # Assert: Ensure the new exception is added
            $exceptions = Get-Content -Path "$PSScriptRoot\mock-exceptions.json" | ConvertFrom-Json
            $exceptions | Where-Object { $_.spn_object_id -eq "5678" } | Should -Not -BeNullOrEmpty
        }
    }

    Context "Test-SchemaValidation Function Integration Test" {
        It "should pass validation for a valid schema" {
            # Arrange
            $exception = @{
                spn_object_id = "1234"
                az_scope_type = "RG"
                PrivRole = "Owner"
                SecArch = "ARCH1234"
            }

            # Act: Call Test-SchemaValidation
            $result = Test-SchemaValidation -exception $exception

            # Assert: Ensure the function returns true
            $result | Should -Be $true
        }
    }

    Context "Remove-Exceptions Function Integration Test" {
        BeforeEach {
            # Mock dataset and exceptions.json for Remove-Exceptions tests
            $mockDataset = @(
                [pscustomobject]@{ AppObjectID="1234"; AppDisplayName="TestApp"; ObjectName="ResourceGroup1"; AppEonid="EON1234"; PrivRole="Owner"; Tenant="Prod" },
                [pscustomobject]@{ AppObjectID="5678"; AppDisplayName="SampleApp"; ObjectName="ManagementGroup1"; AppEonid="EON5678"; PrivRole="Contributor"; Tenant="QA" }
            )
            $mockExceptions = @(
                @{ spn_object_id = "1234"; spn_name_like = $null; azObjectScopeID = $null; azObjectNameLike = $null; spn_eonid = "EON1234"; tenant = "Prod" }
            ) | ConvertTo-Json
            Set-Content -Path "$PSScriptRoot\mock-exceptions.json" -Value $mockExceptions
        }

        It "should remove matching entries based on spn_object_id" {
            # Act: Call Remove-Exceptions
            $result = Remove-Exceptions -data $mockDataset -exceptionsJsonPath "$PSScriptRoot\mock-exceptions.json"

            # Assert: Ensure the entry with spn_object_id 1234 is removed
            $result.AppObjectID | Should -Not -Contain "1234"
        }
    }
}
