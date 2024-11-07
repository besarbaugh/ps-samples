# Load the function to test
. "$PSScriptRoot/../functions/Remove-Exception.ps1"

Describe "Remove-Exception" {
    Context "Removing an exception" {
        It "Should remove an exception with a valid uniqueID" {
            $result = Remove-Exception -uniqueID "some-unique-id" -exceptionsPath "$PSScriptRoot/../exceptions.json"
            $result | Should -BeNullOrEmpty
        }

        It "Should throw an error if uniqueID does not exist" {
            { Remove-Exception -uniqueID "non-existent-id" } | Should -Throw
        }
    }
}
