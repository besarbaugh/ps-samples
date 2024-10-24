# Test-SchemaValidation.Tests.ps1
# Pester tests for the Test-SchemaValidation function

Describe 'Test-SchemaValidation Function Tests' {
    
    # Mock dataset (based on the initialized dataset in TestAll)
    $dataset = @(
        [pscustomobject]@{
            AppEonid = "EON123"; AppEnv = "Prod"; AppName = "App1"; AppObjectID = "AppObject123"; PrivRole = "Owner"; AzureScopeType = "RG"; AzureObjectScopeID = "RGObjectID1"; AzureObjectName = "RGName1"
        },
        [pscustomobject]@{
            AppEonid = "EON456"; AppEnv = "QA"; AppName = "App2"; AppObjectID = "AppObject456"; PrivRole = "Contributor"; AzureScopeType = "MG"; AzureObjectScopeID = "MGObjectID2"; AzureObjectName = "MGName2"
        }
    )

    Context 'When CSA is not enforced' {
        It 'Validates exception with SPN Object ID and required fields' {
            $exception = @{
                spn_object_id = "1234"
                az_scope_type = "RG"
                PrivRole = "Owner"
                SecArch = "ARCH1234"
            }

            # Call the Test-SchemaValidation function
            $result = Test-SchemaValidation -exception $exception

            # Assert the result is true
            $result | Should -BeTrue
        }

        It 'Fails validation when neither SPN Object ID nor spn_name_like is provided' {
            $exception = @{
                az_scope_type = "RG"
                PrivRole = "Owner"
            }

            { Test-SchemaValidation -exception $exception } | Should -Throw -ErrorId "Either spn_object_id or spn_name_like must be provided."
        }

        It 'Fails validation when both SPN Object ID and spn_name_like are provided' {
            $exception = @{
                spn_object_id = "1234"
                spn_name_like = "*SampleApp*"
                az_scope_type = "RG"
                PrivRole = "Owner"
            }

            { Test-SchemaValidation -exception $exception } | Should -Throw -ErrorId "Cannot use both spn_object_id and spn_name_like at the same time."
        }

        It 'Validates exception with spn_name_like and tenant' {
            $exception = @{
                spn_name_like = "*SampleApp*"
                az_scope_type = "MG"
                PrivRole = "Contributor"
                spn_eonid = "EON456"
                tenant = "2"  # QA
            }

            $result = Test-SchemaValidation -exception $exception
            $result | Should -BeTrue
        }
    }

    Context 'When CSA is enforced' {
        BeforeEach {
            # Set CSA enforcement to true in config.json
            $configPath = ".\tests\testdata\config.json"
            $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
            $config.csaEnforced = $true
            $config | ConvertTo-Json | Set-Content -Path $configPath
        }

        AfterEach {
            # Reset CSA enforcement to false after the test
            $configPath = ".\tests\testdata\config.json"
            $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
            $config.csaEnforced = $false
            $config | ConvertTo-Json | Set-Content -Path $configPath
        }

        It 'Validates spnEonid against dataset when CSA is enforced' {
            $exception = @{
                spn_name_like = "*SampleApp*"
                az_scope_type = "MG"
                PrivRole = "Contributor"
                spn_eonid = "EON456"
                tenant = "2"  # QA
            }

            $result = Test-SchemaValidation -exception $exception -dataset $dataset
            $result | Should -BeTrue
        }

        It 'Fails validation when spnEonid is not in dataset when CSA is enforced' {
            $exception = @{
                spn_name_like = "*UnknownApp*"
                az_scope_type = "RG"
                PrivRole = "Owner"
                spn_eonid = "EON999"
                tenant = "1"  # Prod
            }

            { Test-SchemaValidation -exception $exception -dataset $dataset } | Should -Throw -ErrorId "Invalid spnEonid. The EonID does not match any CSA data in the dataset."
        }
    }
}
