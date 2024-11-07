# Load the function to test
. "$PSScriptRoot/../functions/Add-Exception.ps1"

Describe "Add-Exception" {
    Context "Adding a new exception" {
        It "Should add a new exception with valid parameters" {
            $result = Add-Exception -spnEonid "EON123" -spnObjectID "SPN1234" -azScopeType "resourceGroup" -role "Owner" `
                -SecArch "SA123" -lastModifiedBy "test@example.com" -exceptionsPath "$PSScriptRoot/../exceptions.json"
            $result | Should -BeNullOrEmpty
        }

        It "Should throw an error if spnObjectID and spnNameLike are both provided" {
            { Add-Exception -spnEonid "EON123" -spnObjectID "SPN1234" -spnNameLike "SampleApp*" -azScopeType "resourceGroup" `
                -role "Owner" -SecArch "SA123" -lastModifiedBy "test@example.com" } | Should -Throw
        }

        It "Should require a valid email address for lastModifiedBy" {
            { Add-Exception -spnEonid "EON123" -spnObjectID "SPN1234" -azScopeType "resourceGroup" `
                -role "Owner" -SecArch "SA123" -lastModifiedBy "invalid-email" } | Should -Throw
        }
    }
}
