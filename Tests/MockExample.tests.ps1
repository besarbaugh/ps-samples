Describe the contents of the file `Tests/MockExample.tests.ps1`:

```powershell
Mock 'DependencyFunction' {
    return 'Mocked Value'
}

Describe 'MockExample' {
    Context 'When using mocking' {
        It 'should return the mocked value' {
            Mock 'DependencyFunction' {
                return 'Mocked Value'
            }

            $result = Invoke-MyFunction

            $result | Should -Be 'Mocked Value'
        }
    }
}
```

Please note that `Invoke-MyFunction` is a placeholder for the actual function that you want to test. Replace it with the name of your function.