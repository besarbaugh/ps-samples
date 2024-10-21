# Pester tests for the helper functions and main Is-Exception function

Describe 'Helper Functions' {
    It 'Should match object IDs correctly' {
        $result = Match-ByObjectID -ObjectID "12345" -ExceptionObjectID "12345"
        $result | Should -Be $true
    }

    It 'Should not match if object IDs are different' {
        $result = Match-ByObjectID -ObjectID "12345" -ExceptionObjectID "54321"
        $result | Should -Be $false
    }

    It 'Should match object names using wildcard patterns' {
        $result = Match-ByNameLike -ObjectName "Admin-Resource" -ExceptionNameLike "*Admin*"
        $result | Should -Be $true
    }

    It 'Should match EonIDs correctly' {
        $result = Match-ByEonID -ObjectEonID "Dept-001" -ExceptionEonID "Dept-001"
        $result | Should -Be $true
    }

    It 'Should match roles correctly' {
        $result = Match-ByRole -ObjectRole "Owner" -ExceptionRole "Owner"
        $result | Should -Be $true
    }

    It 'Should match environments correctly' {
        $result = Match-ByEnvironment -ObjectEnv "Prod" -ExceptionEnv "Prod"
        $result | Should -Be $true
    }
}

Describe 'Is-Exception Function' {
    # Mock the Get-Content to return specific JSON data for testing
    Mock -CommandName Get-Content -MockWith {
        return '[{"SPNObjectID": "12345", "SPNNameLike": "*Admin*", "AzScopeObjectID": "56789", "Role": "Owner", "Env": "Prod"}]'
    }

    It 'Should identify an exception based on object ID match' {
        $outObject = [pscustomobject]@{
            AppObjectID = "12345"
            AppDisplayName = "Admin-Resource"
            AzureObjeccScopeID = "56789"
            PrivRole = "Owner"
            Env = "Prod"
        }

        $result = Is-Exception -OutObject $outObject -ExceptionsFilePath "dummy.json"
        $result | Should -Be $true
    }

    It 'Should identify an exception based on name pattern match' {
        $outObject = [pscustomobject]@{
            AppObjectID = "54321"
            AppDisplayName = "Admin-Resource"
            AzureObjeccScopeID = "99999"
            PrivRole = "User"
            Env = "Prod"
        }

        $result = Is-Exception -OutObject $outObject -ExceptionsFilePath "dummy.json"
        $result | Should -Be $true
    }

    It 'Should not identify an exception if no matches found' {
        $outObject = [pscustomobject]@{
            AppObjectID = "54321"
            AppDisplayName = "NonAdmin-Resource"
            AzureObjeccScopeID = "99999"
            PrivRole = "User"
            Env = "Dev"
        }

        $result = Is-Exception -OutObject $outObject -ExceptionsFilePath "dummy.json"
        $result | Should -Be $false
    }
}
