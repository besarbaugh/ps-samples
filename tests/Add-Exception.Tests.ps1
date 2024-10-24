
# Import the module containing the Add-Exception function
. "$PSScriptRoot\functions\Add-Exception.ps1"

Describe "Add-Exception Function Tests" {
    Context "Parameter Validation" {
        It "Should throw an error if both spnObjectID and spnNameLike are provided" {
            { Add-Exception -spnObjectID "spn1" -spnNameLike "spn*" -azScopeType "RG" -PrivRole "Owner" } | Should -Throw -ErrorId "ParameterConflict"
        }

        It "Should throw an error if both azObjectScopeID and azObjectNameLike are provided" {
            { Add-Exception -azObjectScopeID "scope1" -azObjectNameLike "scope*" -azScopeType "RG" -PrivRole "Owner" } | Should -Throw -ErrorId "ParameterConflict"
        }

        It "Should throw an error if tenant is not provided when spnNameLike is used" {
            { Add-Exception -spnNameLike "spn*" -azScopeType "RG" -PrivRole "Owner" } | Should -Throw -ErrorId "MissingTenant"
        }

        It "Should throw an error if spnEonid is not provided when spnNameLike is used" {
            { Add-Exception -spnNameLike "spn*" -tenant "1" -azScopeType "RG" -PrivRole "Owner" } | Should -Throw -ErrorId "MissingSpnEonid"
        }

        It "Should throw an error if both SecArch and ActionPlan are provided" {
            { Add-Exception -SecArch "sec1" -ActionPlan "plan1" -azScopeType "RG" -PrivRole "Owner" } | Should -Throw -ErrorId "ParameterConflict"
        }

        It "Should throw an error if ActionPlan is provided without expiration_date" {
            { Add-Exception -ActionPlan "plan1" -azScopeType "RG" -PrivRole "Owner" } | Should -Throw -ErrorId "MissingExpirationDate"
        }

        It "Should throw an error if config.json is not found" {
            { Add-Exception -spnObjectID "spn1" -azScopeType "RG" -PrivRole "Owner" -exceptionsPath "C:\invalid\exceptions.json" } | Should -Throw -ErrorId "FileNotFound"
        }

        It "Should throw an error if CSA is enforced and spnEonid is invalid" {
            $config = @{
                exceptionsPath = "C:\temp\exceptions.json"
                datasetDir = "C:\temp"
                filenamePattern = "*.csv"
                csaEnforced = $true
            }
            $config | ConvertTo-Json | Set-Content -Path ".\config.json"
            { Add-Exception -spnNameLike "spn*" -tenant "1" -spnEonid "invalidEonid" -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $config.exceptionsPath -datasetPath $config.datasetDir } | Should -Throw -ErrorId "InvalidSpnEonid"
        }
    }

    Context "Functionality Tests" {
        $exceptionsPath = "$PSScriptRoot\temp\exceptions.json"
        $datasetPath = "$PSScriptRoot\temp\dataset.csv"

        BeforeAll {
            # Create a mock config.json file
            $config = @{
                exceptionsPath = $exceptionsPath
                datasetDir = "C:\temp"
                filenamePattern = "*.csv"
                csaEnforced = $false
            }
            $config | ConvertTo-Json | Set-Content -Path ".\config.json"

            # Create a mock dataset CSV file
            @"
spnEonid,spnEnv
eon1,Prod
"@ | Set-Content -Path $datasetPath
        }

        BeforeEach {
            # Ensure the exceptions.json file is empty before each test
            "[]" | Set-Content -Path $exceptionsPath
        }

        It "Should add a new exception with spnObjectID" {
            Add-Exception -spnObjectID "spn1" -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $exceptionsPath -datasetPath $datasetPath
            $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
            $exceptions | Should -HaveCount 1
            $exceptions[0].spn_object_id | Should -Be "spn1"
        }

        It "Should add a new exception with spnNameLike" {
            Add-Exception -spnNameLike "spn*" -tenant "1" -spnEonid "eon1" -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $exceptionsPath -datasetPath $datasetPath
            $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
            $exceptions | Should -HaveCount 1
            $exceptions[0].spn_name_like | Should -Be "spn*"
            $exceptions[0].tenant | Should -Be "Prod"
        }

        It "Should add a new exception with SecArch" {
            Add-Exception -SecArch "sec1" -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $exceptionsPath -datasetPath $datasetPath
            $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
            $exceptions | Should -HaveCount 1
            $exceptions[0].SecArch | Should -Be "sec1"
        }

        It "Should add a new exception with ActionPlan and expiration_date" {
            $expirationDate = [datetime]::ParseExact("12/31/2023", "MM/dd/yyyy", $null)
            Add-Exception -ActionPlan "plan1" -expiration_date $expirationDate -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $exceptionsPath -datasetPath $datasetPath
            $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
            $exceptions | Should -HaveCount 1
            $exceptions[0].ActionPlan | Should -Be "plan1"
            $exceptions[0].expiration_date | Should -Be $expirationDate
        }

        It "Should add multiple exceptions" {
            Add-Exception -spnObjectID "spn1" -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $exceptionsPath -datasetPath $datasetPath
            Add-Exception -spnNameLike "spn*" -tenant "1" -spnEonid "eon1" -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $exceptionsPath -datasetPath $datasetPath
            $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
            $exceptions | Should -HaveCount 2
        }

        It "Should handle empty dataset gracefully" {
            $emptyDatasetPath = "C:\temp\empty_dataset.csv"
            @"" | Set-Content -Path $emptyDatasetPath
            Add-Exception -spnObjectID "spn1" -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $exceptionsPath -datasetPath $emptyDatasetPath
            $exceptions = Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
            $exceptions | Should -HaveCount 1
        }

        It "Should output the count of how many items would be removed from the dataset" {
            $datasetPath = "C:\temp\dataset.csv"
            @"
spnEonid,spnEnv
eon1,Prod
eon2,QA
"@ | Set-Content -Path $datasetPath

            $result = Add-Exception -spnNameLike "spn*" -tenant "1" -spnEonid "eon1" -azScopeType "RG" -PrivRole "Owner" -exceptionsPath $exceptionsPath -datasetPath $datasetPath -removalCount
            $result | Should -Be 1
        }
    }
}
