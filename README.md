# ExceptionManager Usage Guide

Welcome to the **ExceptionManager** module, a tool designed to manage and track over-privileged SPN exceptions. Please follow this guide carefully, especially if you need to add exceptions while Brian is out of the office.

## Pre-requisite: Unblock Remote Files

Before using this module, ensure all files are unblocked on your machine. Files from remote sources can be blocked by default, which might prevent the module from running correctly.

1. **Run this PowerShell command to unblock all files from the remote share:**

    ```powershell
    Get-ChildItem -Path "\\your-remote-share-path" -Recurse | Unblock-File
    ```

    Replace `"\\your-remote-share-path"` with the actual path to the share containing the ExceptionManager module.

---

## Loading the ExceptionManager Module

Once the files are unblocked, load the ExceptionManager module into your session.

1. **To load the module, run:**

    ```powershell
    Import-Module "\\your-remote-share-path\ExceptionManager"
    ```

2. **Verify the module is loaded by running:**

    ```powershell
    Get-Module -Name ExceptionManager
    ```

---

## Using `Get-Help` for Guidance

All functions in the **ExceptionManager** module include detailed help documentation. You are encouraged to use PowerShell's `Get-Help` to understand how each function works.

1. **To view the full help documentation for the module:**

    ```powershell
    Get-Help -Name ExceptionManager
    ```

2. **To view help for specific functions (e.g., `Add-Exception`):**

    ```powershell
    Get-Help -Name Add-Exception -Full
    ```

    You can also use `-Examples` to see specific usage examples.

    ```powershell
    Get-Help -Name Add-Exception -Examples
    ```

Using `Get-Help` is the best way to ensure proper usage of each function.

---

## Adding an Exception

### Important Rules:

- No exceptions can be added without **SecArch** or **ActionPlan**. At least one is mandatory for each exception.
- Use `SecArch` for long-term, approved exceptions and `ActionPlan` for temporary exceptions (with an expiration date).

### To Add an Exception:

- **SPN Object ID Exception Example**:

    ```powershell
    Add-Exception -spnObjectID "SPN1234" -azScopeType "resourceGroup" -role "Owner" -SecArch "SEC123"
    ```

    This adds an exception granting the SPN `"SPN1234"` the `Owner` role across all **resourceGroups**, with approval from `"SEC123"`.

- **SPN Name Like Exception Example**:

    ```powershell
    Add-Exception -spnNameLike "*exampleApp*" -azScopeType "managementGroup" -role "Contributor" -spnEonid "EON123" -tenant "prodten" -ActionPlan "AP123" -expiration_date "12/31/2024"
    ```

    This adds an exception for any SPN that matches `"*exampleApp*"`, granting it the `Contributor` role on **managementGroups**. It requires **ActionPlan** `"AP123"` and will expire on **12/31/2024**.

### Preventing Duplicate Exceptions:

The `Add-Exception` function prevents adding exact duplicate exceptions. If an identical exception already exists, it will not be added again.

---

## Daily Filtering Process (Automated)

**Note:** The `Filter-Exceptions` function is scheduled to run daily on an automated schedule. You do **not** need to manually run it. This function will automatically filter SPNs from the audit dataset based on the exceptions added.

---

## Checking for Expired Action Plans

If an exception uses **ActionPlan** and has an expiration date, be aware that the filter will **not** apply it if the expiration date has passed. Make sure to renew the **ActionPlan** if necessary.

---

## Troubleshooting

- If you encounter any issues, ensure the files are unblocked by re-running:

    ```powershell
    Get-ChildItem -Path "\\your-remote-share-path" -Recurse | Unblock-File
    ```

- Ensure you are working on the correct **exceptions.json** path for adding new exceptions.

---

## Final Notes

- Always make sure you are following approval procedures (either **SecArch** or **ActionPlan**) before adding any exception.
- The filtering function will run automatically each day; you only need to manage adding new exceptions.
- If you have questions, please reach out to Brian upon his return.

