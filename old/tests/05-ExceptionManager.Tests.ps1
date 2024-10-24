# ExceptionManager.psm1.Tests.ps1
# Purpose: Pester tests for the ExceptionManager module

Describe 'ExceptionManager Module Tests' {

    It 'Should export all required functions' {
        # Check if the module exports the correct functions
        $exportedFunctions = (Get-Command -Module ExceptionManager).Name

        $exportedFunctions | Should -Contain 'Get-Dataset'
        $exportedFunctions | Should -Contain 'Add-Exception'
        $exportedFunctions | Should -Contain 'Test-SchemaValidation'
        $exportedFunctions | Should -Contain 'Remove-Exceptions'
    }

    It 'Should properly invoke core functions' {
        # Test if each function can be invoked without errors (empty or minimal required parameters)
        { Get-Dataset } | Should -Not -Throw
        { Add-Exception -azScopeType 'RG' -PrivRole 'Owner' } | Should -Throw  # Missing required parameters
        { Test-SchemaValidation -exception @{} } | Should -Throw  # Empty exception should fail validation
        { Remove-Exceptions } | Should -Throw  # Missing required parameters
    }
}
