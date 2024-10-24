# TestAll.ps1
# Purpose: Initializes the test environment, loads the ExceptionManager module, runs PSScriptAnalyzer, Pester tests, and cleans up.

# Step 1: Initialize Test Environment
function Initialize-TestEnvironment {
    Write-Host "Initializing Test Environment..."

    # Create test files for config, exceptions, and dataset
    $testConfig = @{
        csaEnforced = $false
        exceptionsPath = ".\tests\testdata\exceptions.json"
        datasetDir = ".\tests\testdata"
        filenamePattern = "dataset_"
    }

    # Create directories and files if they don't exist
    $testDataDir = ".\tests\testdata"
    if (-not (Test-Path -Path $testDataDir)) {
        New-Item -ItemType Directory -Path $testDataDir -Force
    }

    # Write the config file
    $configPath = Join-Path $testDataDir "config.json"
    $testConfig | ConvertTo-Json | Set-Content -Path $configPath

    # Create the initial empty exceptions.json file
    $exceptionsPath = Join-Path $testDataDir "exceptions.json"
    "[]" | Set-Content -Path $exceptionsPath

    # Enhanced sample dataset CSV file
    $datasetContent = @"
AppEonid,AppEnv,AppName,AppObjectID,PrivRole,AzureScopeType,AzureObjectScopeID,AzureObjectName
EON123,Prod,App1,AppObject123,Owner,RG,RGObjectID1,RGName1
EON456,QA,App2,AppObject456,Contributor,MG,MGObjectID2,MGName2
EON789,Dev,App3,AppObject789,User Access Administrator,Sub,SubObjectID3,SubName3
EON012,UAT,App4,AppObject012,AppDevContributor,RG,RGObjectID4,RGName4
"@
    $datasetPath = Join-Path $testDataDir "dataset_10_15_2024.csv"
    $datasetContent | Set-Content -Path $datasetPath

    Write-Host "Test environment initialized."
}

# Step 2: Cleanup Test Environment
function Remove-TestEnvironment {
    Write-Host "Cleaning up Test Environment..."

    # Remove test files and directories
    $testDataDir = ".\tests\testdata"
    if (Test-Path -Path $testDataDir) {
        Remove-Item -Path $testDataDir -Recurse -Force
    }

    Write-Host "Test environment cleaned up."
}

# Step 3: Import the ExceptionManager module
function Import-ExceptionManagerModule {
    Write-Host "Importing ExceptionManager Module..."
    Import-Module "$PSScriptRoot\..\exceptionmanager\exceptionmanager.psm1" -Force
    Write-Host "Module imported successfully."
}

# Step 4: Run PSScriptAnalyzer
function Invoke-ScriptAnalyzerCheck {
    Write-Host "Running PSScriptAnalyzer on ExceptionManager module..."
    $analyzerResults = Invoke-ScriptAnalyzer -Path "$PSScriptRoot\..\exceptionmanager\exceptionmanager.psm1" -Recurse
    if ($analyzerResults.Count -eq 0) {
        Write-Host "PSScriptAnalyzer found no issues."
    } else {
        Write-Host "PSScriptAnalyzer found the following issues:"
        $analyzerResults | Format-Table -AutoSize
        throw "PSScriptAnalyzer found issues that need to be fixed before running tests."
    }
}

# Step 5: Run Pester tests
function Invoke-PesterTests {
    Write-Host "Running Pester Tests..."
    Invoke-Pester -Script "$PSScriptRoot\tests" -Output Detailed
}

# Step 6: Main execution flow
try {
    Initialize-TestEnvironment   # Initialize the test environment
    Import-ExceptionManagerModule  # Import the ExceptionManager module
    Invoke-ScriptAnalyzerCheck   # Run PSScriptAnalyzer to ensure clean code
    Invoke-PesterTests           # Run all the Pester tests
}
finally {
    Remove-TestEnvironment      # Always clean up the test environment after tests run
}
