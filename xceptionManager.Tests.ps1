# Load the helper functions from the functions directory
. "$PSScriptRoot\functions\Get-Exceptions.ps1"
. "$PSScriptRoot\functions\Save-Exceptions.ps1"
. "$PSScriptRoot\functions\Test-ExceptionSchema.ps1"
. "$PSScriptRoot\functions\Add-Exception.ps1"

# Define the path to the exceptions.json file
$FilePath = Join-Path $PSScriptRoot "..\exceptions.json"

# Sample exceptions for testing
$sampleExceptionValid = @{
    spnname_patterns = @{
        patterns   = @("*sample-spn*")
        match_type = "AND"
    }
    spndeptid = "Dept001"
    containertype = @("RG")
    role = @("owner")
    environment = "Prod"
    dynamic = $true
    dynamic_scope = $false
    exception_type = "permanent"
    containerdeptid = "Dept001"
    containerid = "Container123"
}

$sampleExceptionInvalid = @{
    spnname_patterns = @{
        patterns   = @("*invalid-spn*")
        match_type = "OR"
    }
    spndeptid = "Dept002"
    containertype = @("InvalidType")  # Invalid container type to cause a failure
    role = @("owner")
    environment = "Prod"
    dynamic = $true
    dynamic_scope = $false
    exception_type = "permanent"
    containerdeptid = "Dept002"
    containerid = "Container456"
}

# Sample exception for duplicate testing
$sampleExceptionDuplicate = @{
    spnname_patterns = @{
        patterns   = @("*duplicate-spn*")
        match_type = "OR"
    }
    spndeptid = "Dept003"
    containertype = @("RG")
    role = @("owner")
    environment = "Prod"
    dynamic = $false
    dynamic_scope = $false
    exception_type = "permanent"
    containerdeptid = "Dept003"
    containerid = "Container789"
}

Describe "ExceptionManager Helper Functions" {
    
    # Test for Get-Exceptions
    It "Should load existing exceptions without error" {
        # Create a mock exceptions file
        $mockExceptions = @{
            Exceptions = @($sampleExceptionValid)
        }

        $mockJsonContent = $mockExceptions | ConvertTo-Json -Depth 10
        $mockJsonContent | Out-File -FilePath $FilePath -Force

        $loadedExceptions = Get-Exceptions

        $loadedExceptions.Exceptions | Should -Not -Be $null
        $loadedExceptions.Exceptions.Count | Should -Be 1
    }

    # Test for Save-Exceptions
    It "Should save updated exceptions without error" {
        $updatedExceptions = @{
            Exceptions = @($sampleExceptionValid, $sampleExceptionDuplicate)
        }

        { Save-Exceptions -ExceptionsList $updatedExceptions } | Should -Not -Throw

        $savedExceptions = Get-Exceptions
        $savedExceptions.Exceptions.Count | Should -Be 2
    }

    # Test for Test-ExceptionSchema with a valid exception
    It "Should pass schema validation for a valid exception" {
        Test-ExceptionSchema -Exception $sampleExceptionValid | Should -Be $true
    }

    # Test for Test-ExceptionSchema with an invalid exception
    It "Should fail schema validation for an invalid exception" {
        Test-ExceptionSchema -Exception $sampleExceptionInvalid | Should -Be $false
    }

    # Test for Add-Exception with a valid exception
    It "Should add a valid exception to the exceptions file" {
        # Reset the exceptions.json file
        $resetExceptions = @{
            Exceptions = @()
        }
        Save-Exceptions -ExceptionsList $resetExceptions

        Add-Exception -SpnNamePatterns $sampleExceptionValid.spmnname_patterns `
                      -SPNDeptID $sampleExceptionValid.spndeptid `
                      -ContainerTypes $sampleExceptionValid.containertype `
                      -Roles $sampleExceptionValid.role `
                      -Environment $sampleExceptionValid.environment `
                      -Dynamic $sampleExceptionValid.dynamic `
                      -DynamicScope $sampleExceptionValid.dynamic_scope `
                      -ExceptionType $sampleExceptionValid.exception_type `
                      -ExpirationDate $null `
                      -ContainerDeptID $sampleExceptionValid.containerdeptid `
                      -ContainerID $sampleExceptionValid.containerid

        $exceptionsAfterAdd = Get-Exceptions
        $exceptionsAfterAdd.Exceptions.Count | Should -Be 1
    }

    # Test for duplicate exception
    It "Should not add a duplicate exception" {
        # Add the initial exception
        Add-Exception -SpnNamePatterns $sampleExceptionDuplicate.spmnname_patterns `
                      -SPNDeptID $sampleExceptionDuplicate.spndeptid `
                      -ContainerTypes $sampleExceptionDuplicate.containertype `
                      -Roles $sampleExceptionDuplicate.role `
                      -Environment $sampleExceptionDuplicate.environment `
                      -Dynamic $sampleExceptionDuplicate.dynamic `
                      -DynamicScope $sampleExceptionDuplicate.dynamic_scope `
                      -ExceptionType $sampleExceptionDuplicate.exception_type `
                      -ExpirationDate $null `
                      -ContainerDeptID $sampleExceptionDuplicate.containerdeptid `
                      -ContainerID $sampleExceptionDuplicate.containerid

        # Try adding the duplicate exception
        { Add-Exception -SpnNamePatterns $sampleExceptionDuplicate.spmnname_patterns `
                         -SPNDeptID $sampleExceptionDuplicate.spndeptid `
                         -ContainerTypes $sampleExceptionDuplicate.containertype `
                         -Roles $sampleExceptionDuplicate.role `
                         -Environment $sampleExceptionDuplicate.environment `
                         -Dynamic $sampleExceptionDuplicate.dynamic `
                         -DynamicScope $sampleExceptionDuplicate.dynamic_scope `
                         -ExceptionType $sampleExceptionDuplicate.exception_type `
                         -ExpirationDate $null `
                         -ContainerDeptID $sampleExceptionDuplicate.containerdeptid `
                         -ContainerID $sampleExceptionDuplicate.containerid } | Should -Throw
    }
}
