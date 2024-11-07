
# ExceptionManager PowerShell Module

**Author**: Brian Sarbaugh  
**Version**: 1.1.1  
**Last Updated**: November 2024

## Overview

The `ExceptionManager` module provides a powerful, organized system for managing Azure exceptions related to Service Principal Names (SPNs), resource roles, and Custom Security Attributes (CSAs). This module supports adding, updating, removing, and filtering exceptions while tracking modifications for auditability.

## Table of Contents

- [Installation](#installation)
- [Module Setup](#module-setup)
- [Functionality](#functionality)
  - [Get-Dataset](#get-dataset)
  - [Add-Exception](#add-exception)
  - [Update-Exception](#update-exception)
  - [Remove-Exception](#remove-exception)
  - [Filter-Exceptions](#filter-exceptions)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [Testing with Pester](#testing-with-pester)
- [Version History](#version-history)

---

## Installation

1. Clone the repository:
   ```shell
   git clone https://github.com/besarbaugh/ps-samples
   ```

2. Navigate to the `ExceptionManager` directory and import the module:
   ```powershell
   Import-Module .\ExceptionManager.psm1
   ```

## Module Setup

The module relies on:
- **config.json**: Configures paths for `exceptions.json` and the dataset directory.
- **exceptions.json**: Stores categorized exception records (SecArchExceptions and ActionPlanExceptions).
  
### Folder Structure

```
ps-samples/
└── ExceptionManager/
    ├── functions/
    │   ├── Add-Exception.ps1
    │   ├── Update-Exception.ps1
    │   ├── Remove-Exception.ps1
    │   ├── Filter-Exceptions.ps1
    │   └── Get-Dataset.ps1
    ├── tests/
    ├── config.json
    └── exceptions.json
```

## Functionality

### Get-Dataset

Loads a dataset from a CSV file or directly from a PowerShell object array. If a file path is provided, it loads the latest CSV file based on a specified filename pattern in the dataset directory.

#### Syntax

```powershell
Get-Dataset -datasetObject $myDatasetArray
Get-Dataset -datasetDir "C:\Datasets\" -filenamePattern "myDataset_"
```

### Add-Exception

Adds a new exception to `exceptions.json` with support for modification tracking (`lastModifiedBy` and `LastUpdated`). Ensures no duplicate records by checking key fields.

#### Syntax

```powershell
Add-Exception -spnEonid "EON123" -spnObjectID "SPN1234" -azScopeType "resourceGroup" -role "Owner" -SecArch "SA123" -lastModifiedBy "user@example.com"
```

### Update-Exception

Updates an existing exception in `exceptions.json` using its unique identifier (`uniqueID`). Adds `LastUpdated` and `lastModifiedBy` fields for tracking.

#### Syntax

```powershell
Update-Exception -uniqueID "guid-here" -role "Contributor" -lastModifiedBy "updater@example.com"
```

### Remove-Exception

Removes an exception from `exceptions.json` using its `uniqueID`.

#### Syntax

```powershell
Remove-Exception -uniqueID "guid-here"
```

### Filter-Exceptions

Filters entries in a dataset based on exceptions defined in `exceptions.json`. It can also output matching exceptions, including the `GUID`, `LastUpdated`, and `lastModifiedBy` fields.

#### Syntax

```powershell
Filter-Exceptions -datasetPath ".\dataset.csv" -outputAsCsv -outputCsvPath ".\filtered_output.csv" -outputExceptions
```

## Configuration

### Setting Up `config.json`

The configuration file specifies the paths for `exceptions.json` and datasets:
- `exceptionsPath`: Path to `exceptions.json`.
- `datasetDir`: Directory where dataset files are stored.
- `filenamePattern`: Prefix for dataset files (e.g., "dataset_").

Example `config.json`:

```json
{
    "exceptionsPath": ".\\exceptions.json",
    "datasetDir": ".\\data\\",
    "filenamePattern": "myDataset_"
}
```

## Usage Examples

### Example 1: Adding an Exception

```powershell
Add-Exception -spnEonid "EON123" -spnObjectID "SPN456" -azScopeType "resourceGroup" -role "Owner" -SecArch "SA456" -lastModifiedBy "user@example.com"
```

### Example 2: Updating an Exception

```powershell
Update-Exception -uniqueID "guid-here" -role "Contributor" -lastModifiedBy "updater@example.com"
```

### Example 3: Removing an Exception

```powershell
Remove-Exception -uniqueID "guid-here"
```

### Example 4: Filtering Exceptions in a Dataset

```powershell
Filter-Exceptions -datasetPath ".\dataset.csv" -outputAsCsv -outputCsvPath ".\filtered_output.csv" -outputExceptions
```

## Testing with Pester

### Running Tests

The module includes Pester tests located in the `tests/` directory. Run all tests with:

```powershell
Invoke-Pester -Path .\tests
```

### Available Tests

Each function has its own test file in `tests/`:
- `Add-Exception.Tests.ps1`: Tests the `Add-Exception` function.
- `Update-Exception.Tests.ps1`: Tests the `Update-Exception` function.
- `Remove-Exception.Tests.ps1`: Tests the `Remove-Exception` function.
- `Filter-Exceptions.Tests.ps1`: Tests the `Filter-Exceptions` function.

## Version History

### Version 1.1.1 - November 2024
- Added `lastModifiedBy` and `LastUpdated` tracking fields.
- Enhanced `Filter-Exceptions` to include GUID, `LastUpdated`, and `lastModifiedBy`.
- Improved `Add-Exception` to validate email format for `lastModifiedBy`.

### Version 1.0.0 - October 2024
- Initial release with `Add-Exception`, `Remove-Exception`, `Get-Dataset`, and `Filter-Exceptions` functions.

---

This README provides a structured guide for using the `ExceptionManager` module effectively. Happy exception managing!
