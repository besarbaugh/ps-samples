# RunAllTests.ps1
# This script runs all the tests in the ./tests directory using Pester 5

# Discover and run all tests in the ./tests directory
Invoke-Pester -Script "./tests" -Output Detailed