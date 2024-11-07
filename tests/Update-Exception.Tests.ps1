# Load the function to test
. "$PSScriptRoot/../functions/Update-Exception.ps1"

Describe "Update-Exception" {
    Context "Updating an existing exception" {
        It "Should update an exception with a new role and last modified by" {
            $result = Update-Exception -uniqueID "some-unique-id" -role "Contributor" `
                -lastModifiedBy "updater@example.com" -exceptionsPath "$PSScriptRoot/../exceptions.json"
            $result | Should -BeNullOrEmpty
        }

        It "Should throw an error if uniqueID does not exist" {
            { Update-Exception -uniqueID "non-existent-id" -role "Contributor" -lastModifiedBy "updater@example.com" } | Should -Throw
        }
    }
}
