# Remove-Exceptions.Tests.ps1
# Purpose: Pester tests for Remove-Exceptions function in the ExceptionManager module

Describe 'Remove-Exceptions Function Tests' {

    # Test variables initialized in TestAll
    $testSpnObjectID = "TestSPN123"
    $testSpnNameLike = "*SampleApp*"
    $testAzScopeType = "RG"
    $testPrivRole = "Owner"
    $testAzObjectScopeID = "RGObjectID1"
    $testSpnEonid = "EON123"
    $testTenant = "Prod"

    Context 'Validating Remove-Exceptions Function' {

        It 'Should successfully remove an exception by SPN object ID' {
            # Add the test exception
            Add-Exception `
                -spnObjectID $testSpnObjectID `
                -azScopeType $testAzScopeType `
                -PrivRole $testPrivRole `
                -azObjectScopeID $testAzObjectScopeID

            # Call Remove-Exceptions to remove by spnObjectID
            Remove-Exceptions `
                -spnObjectId $testSpnObjectID

            # Verify the exception was removed
            $exceptions = Get-Content -Raw -Path ".\tests\testdata\exceptions.json" | ConvertFrom-Json
            $removedException = $exceptions | Where-Object { $_.spn_object_id -eq $testSpnObjectID }

            $removedException | Should -BeNullOrEmpty
        }

        It 'Should successfully remove an exception by spn_name_like' {
            # Add the test exception
            Add-Exception `
                -spnNameLike $testSpnNameLike `
                -azScopeType $testAzScopeType `
                -PrivRole $testPrivRole `
                -spnEonid $testSpnEonid `
                -tenant $testTenant

            # Call Remove-Exceptions to remove by spnNameLike
            Remove-Exceptions `
                -spnNameLike $testSpnNameLike

            # Verify the exception was removed
            $exceptions = Get-Content -Raw -Path ".\tests\testdata\exceptions.json" | ConvertFrom-Json
            $removedException = $exceptions | Where-Object { $_.spn_name_like -eq $testSpnNameLike }

            $removedException | Should -BeNullOrEmpty
        }

        It 'Should not remove an exception when no matching criteria are provided' {
            # Add the test exception
            Add-Exception `
                -spnObjectID $testSpnObjectID `
                -azScopeType $testAzScopeType `
                -PrivRole $testPrivRole `
                -azObjectScopeID $testAzObjectScopeID

            # Attempt to remove an exception with invalid criteria
            Remove-Exceptions `
                -spnObjectId "NonExistentSPN"

            # Verify no exceptions were removed
            $exceptions = Get-Content -Raw -Path ".\tests\testdata\exceptions.json" | ConvertFrom-Json
            $exceptions.Count | Should -Be 1
        }

        It 'Should display a warning if no exceptions are removed' {
            {
                Remove-Exceptions `
                    -spnObjectId "NonExistentSPN"
            } | Should -Contain "No exceptions were removed. Check the filter criteria."
        }
    }

    AfterAll {
        # The test environment will be cleaned up by TestAll
    }
}
