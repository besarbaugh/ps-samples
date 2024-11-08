
# ExceptionManager PowerShell Module

**Author**: Brian Sarbaugh  
**Version**: 1.1.1  
**Last Updated**: November 2024

The `ExceptionManager` PowerShell module provides tools for managing Azure Service Principal (SPN) and resource role exceptions with comprehensive tracking, validation, and auditing capabilities. This module supports complex filtering, role validation, and exception management with added metadata for traceability.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Add-Exception](#add-exception)
  - [Update-Exception](#update-exception)
  - [Remove-Exception](#remove-exception)
  - [Filter-Exceptions](#filter-exceptions)
  - [Get-Dataset](#get-dataset)
- [Configuration](#configuration)
- [Testing](#testing)
- [Version History](#version-history)

---

## Features

- **Manage Exceptions**: Easily add, update, and remove exceptions with comprehensive validation.
- **Track Modifications**: Capture and store `lastModifiedBy` and `LastUpdated` fields for each exception.
- **Advanced Filtering**: Filter dataset entries based on exception rules with flexibility for output format and matching criteria.
- **Schema Validation**: Ensure input consistency and avoid duplicates with robust schema validation.
- **CSV and Object Support**: Load datasets from CSV or PowerShell object arrays, with latest-file support based on a filename pattern.

## Installation

1. **Clone the repository**:
   ```shell
   git clone https://internal.bitbucket.org/yourteam/ps-samples
   ```

2. **Import the module**:
   ```powershell
   Import-Module .\ExceptionManager\ExceptionManager.psm1
   ```

## Usage

### Add-Exception

Adds a new exception to `exceptions.json`, including details such as `lastModifiedBy` and `LastUpdated` to track edits. The function ensures no duplicate entries based on primary key fields.

**Syntax**:
```powershell
Add-Exception -spnEonid "EON123" -spnObjectID "SPN1234" -azScopeType "resourceGroup" -role "Owner" -SecArch "SA123" -lastModifiedBy "user@example.com"
```

**Example**:
```powershell
Add-Exception -spnEonid "EON789" -spnObjectID "SPN789" -azScopeType "subscription" -role "Contributor" -ActionPlan "AP123" -expiration_date "12/31/2024" -lastModifiedBy "user@example.com"
```

### Update-Exception

Updates an existing exception using a unique identifier (`uniqueID`). The function logs `LastUpdated` and `lastModifiedBy` for audit purposes.

**Syntax**:
```powershell
Update-Exception -uniqueID "guid-here" -role "Contributor" -lastModifiedBy "updater@example.com"
```

**Example**:
```powershell
Update-Exception -uniqueID "d7e11f5e-5abc-4f01-bb68-4c2f524bf9ea" -role "User Access Administrator" -lastModifiedBy "admin@example.com"
```

### Remove-Exception

Deletes an exception from `exceptions.json` using its `uniqueID`.

**Syntax**:
```powershell
Remove-Exception -uniqueID "guid-here"
```

**Example**:
```powershell
Remove-Exception -uniqueID "d7e11f5e-5abc-4f01-bb68-4c2f524bf9ea"
```

### Filter-Exceptions

Filters entries in a dataset based on exceptions in `exceptions.json`. It can output matching exceptions, including `GUID`, `LastUpdated`, and `lastModifiedBy` fields.

**Syntax**:
```powershell
Filter-Exceptions -datasetPath ".\dataset.csv" -outputAsCsv -outputCsvPath ".iltered_output.csv" -outputExceptions
```

**Example**:
```powershell
Filter-Exceptions -datasetPath ".\dataset.csv" -outputAsCsv -outputCsvPath ".\matching_exceptions.csv" -outputExceptions
```

### Get-Dataset

Loads a dataset from a CSV file based on the latest filename pattern or directly from a PowerShell object array. Supports flexible dataset handling.

**Syntax**:
```powershell
Get-Dataset -datasetDir "C:\Datasets" -filenamePattern "myDataset_"
```

**Example**:
```powershell
Get-Dataset -datasetObject $myDatasetArray
```

## Configuration

Create a `config.json` file in the module directory to specify paths for `exceptions.json` and dataset files. Example configuration:

```json
{
    "exceptionsPath": ".\exceptions.json",
    "datasetDir": ".\data\",
    "filenamePattern": "dataset_"
}
```

### Configuration Fields

- **exceptionsPath**: Path to the `exceptions.json` file where exceptions are stored.
- **datasetDir**: Directory where dataset files are located.
- **filenamePattern**: Prefix for dataset files (e.g., "dataset_") to load the most recent file based on modification date.

## Testing

The module includes Pester tests for each function, located in the `tests/` directory.

**Run all tests**:
```powershell
Invoke-Pester -Path .	ests
```

### Individual Tests

- `Add-Exception.Tests.ps1`: Tests for `Add-Exception`.
- `Update-Exception.Tests.ps1`: Tests for `Update-Exception`.
- `Remove-Exception.Tests.ps1`: Tests for `Remove-Exception`.
- `Filter-Exceptions.Tests.ps1`: Tests for `Filter-Exceptions`.

## Version History

### Version 1.1.1 - November 2024
- Added `lastModifiedBy` and `LastUpdated` tracking fields.
- Enhanced `Filter-Exceptions` to include GUID, `LastUpdated`, and `lastModifiedBy`.
- Improved `Add-Exception` to validate email format for `lastModifiedBy`.

### Version 1.0.0 - October 2024
- Initial release with `Add-Exception`, `Remove-Exception`, `Get-Dataset`, and `Filter-Exceptions` functions.

---

This README provides a structured guide for using the `ExceptionManager` module effectively. Happy exception managing!
