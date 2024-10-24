# Add-Exception.Tests.ps1
# Purpose: Pester tests for Add-Exception function in the ExceptionManager module

Describe 'Add-Exception Function Tests' {

    # Test variables already initialized in TestAll
    $testSpnObjectID = "TestSPN123"
    $testAzScopeType = "RG"
    $testPrivRole = "Owner"
    $testAzObjectScopeID = "RGObjectID1"
    $testSpnNameLike = "*SampleApp*"
    $testSpnEonid = "EON123"
    $testTenant = "Prod"
    $testSecArch = "SecArch123"
    $testActionPlan = "ActionPlan123"
    $testExpirationDate = Get-Date -Format "MM/dd/yyyy"
    
    Context 'Validating Add-Exception Function' {

        It 'Should successfully add an exception with SPN object ID' {
            Add-Exception `
                -spnObjectID $testSpnObjectID `
                -azScopeType $testAzScopeType `
                -PrivRole $testPrivRole `
                -azObjectScopeID $testAzObjectScopeID

            # Load the exceptions file and verify the exception was added
            $exceptions = Get-Content -Raw -Path ".\tests\testdata\exceptions.json" | ConvertFrom-Json
            $addedException = $exceptions | Where-Object { $_.spn_object_id -eq $testSpnObjectID }

            $addedException | Should -Not -BeNullOrEmpty
            $addedException.az_scope_type | Should -BeExactly $testAzScopeType
            $addedException.PrivRole | Should -BeExactly $testPrivRole
            $addedException.azObjectScopeID | Should -BeExactly $testAzObjectScopeID
        }

        It 'Should successfully add an exception with spn_name_like' {
            Add-Exception `
                -spnNameLike $testSpnNameLike `
                -azScopeType $testAzScopeType `
                -PrivRole $testPrivRole `
                -spnEonid $testSpnEonid `
                -tenant $testTenant

            # Load the exceptions file and verify the exception was added
            $exceptions = Get-Content -Raw -Path ".\tests\testdata\exceptions.json" | ConvertFrom-Json
            $addedException = $exceptions | Where-Object { $_.spn_name_like -eq $testSpnNameLike }

            $addedException | Should -Not -BeNullOrEmpty
            $addedException.spn_eonid | Should -BeExactly $testSpnEonid
            $addedException.tenant | Should -BeExactly $testTenant
        }

        It 'Should fail to add an exception with both SecArch and ActionPlan' {
            {
                Add-Exception `
                    -spnObjectID $testSpnObjectID `
                    -azScopeType $testAzScopeType `
                    -PrivRole $testPrivRole `
                    -SecArch $testSecArch `
                    -ActionPlan $testActionPlan
            } | Should -Throw -ErrorId "*Cannot have both SecArch and ActionPlan*"
        }

        It 'Should require expiration_date for ActionPlan' {
            {
                Add-Exception `
                    -spnObjectID $testSpnObjectID `
                    -azScopeType $testAzScopeType `
                    -PrivRole $testPrivRole `
                    -ActionPlan $testActionPlan
            } | Should -Throw -ErrorId "*ActionPlan requires an expiration date*"
        }

        It 'Should successfully add an exception with ActionPlan and expiration date' {
            Add-Exception `
                -spnObjectID $testSpnObjectID `
                -azScopeType $testAzScopeType `
                -PrivRole $testPrivRole `
                -ActionPlan $testActionPlan `
                -expiration_date $testExpirationDate

            # Load the exceptions file and verify the exception was added
            $exceptions = Get-Content -Raw -Path ".\tests\testdata\exceptions.json" | ConvertFrom-Json
            $addedException = $exceptions | Where-Object { $_.ActionPlan -eq $testActionPlan }

            $addedException | Should -Not -BeNullOrEmpty
            $addedException.expiration_date | Should -BeExactly $testExpirationDate
        }
    }

    AfterAll {
        # The test environment will be cleaned up by TestAll
    }
}
