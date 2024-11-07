function Add-Exception {
    [CmdletBinding(DefaultParameterSetName = 'spnObjectIDSet')]
    param(
        [Parameter(Mandatory = $true)][string]$spnEonid,
        [Parameter(Mandatory = $true, ParameterSetName = 'spnObjectIDSet')][string]$spnObjectID,
        [Parameter(Mandatory = $true, ParameterSetName = 'spnNameLikeSet')][string]$spnNameLike,
        [Parameter(Mandatory = $true, ParameterSetName = 'spnNameLikeSet')][ValidateSet('prodten', 'qaten', 'devten')][string]$tenant,
        [Parameter(Mandatory = $true)][ValidateSet('managementGroup', 'resourceGroup', 'subscription')][string]$azScopeType,
        [Parameter(Mandatory = $true)][ValidateSet('Owner', 'Contributor', 'User Access Administrator', 'AppDevContributor')][string]$role,
        [Parameter(Mandatory = $false)][string]$azObjectScopeID,
        [Parameter(Mandatory = $false)][string]$azObjectNameLike,
        [Parameter(Mandatory = $false)][string]$SecArch,
        [Parameter(Mandatory = $false)][string]$ActionPlan,
        [Parameter(Mandatory = $false)][datetime]$expiration_date,
        [Parameter(Mandatory = $false)][string]$exceptionsPath,
        [Parameter(Mandatory = $false)][string]$datasetPath,
        [Parameter(Mandatory = $false)][switch]$removalCount
    )

    try {
        $configPath = ".\config.json"
        if (-not (Test-Path -Path $configPath)) {
            throw "config.json not found."
        }
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

        if (-not $exceptionsPath) { $exceptionsPath = $config.exceptionsPath }
        if (-not $datasetPath) {
            $dataset = Get-Dataset -datasetDir $config.datasetDir -filenamePattern $config.filenamePattern
        } else {
            $dataset = Import-Csv -Path $datasetPath
        }

        # Determine group based on SecArch or ActionPlan
        if (-not $SecArch -and -not $ActionPlan) {
            throw "Either SecArch or ActionPlan must be provided."
        }
        if ($ActionPlan -and -not $expiration_date) {
            throw "An expiration date is required if using ActionPlan."
        }

        # Initialize the exception object
        $exception = @{
            spn_eonid = $spnEonid
            az_scope_type = $azScopeType
            role = $role
            date_added = (Get-Date).ToString('MM/dd/yyyy')
        }

        if ($spnObjectID) { $exception.spnObjectID = $spnObjectID }
        if ($spnNameLike) { $exception.spnNameLike = $spnNameLike; $exception.tenant = $tenant }
        if ($azObjectScopeID) { $exception.azObjectScopeID = $azObjectScopeID }
        if ($azObjectNameLike) { $exception.azObjectNameLike = $azObjectNameLike }
        if ($SecArch) { $exception.SecArch = $SecArch }
        if ($ActionPlan) { $exception.ActionPlan = $ActionPlan; $exception.expiration_date = $expiration_date }

        # Load the current exceptions JSON structure
        $exceptions = if (Test-Path -Path $exceptionsPath) {
            Get-Content -Raw -Path $exceptionsPath | ConvertFrom-Json
        } else {
            @{ SecArchExceptions = @(); ActionPlanExceptions = @() }
        }

        # Determine which group to add the exception to
        $group = if ($SecArch) { "SecArchExceptions" } else { "ActionPlanExceptions" }

        # Check for duplicates in the specific group
        if ($exceptions.$group -contains $exception) {
            throw "An identical exception already exists in $group."
        }

        # Add the new exception to the appropriate group
        $exceptions.$group += $exception
        $exceptions | ConvertTo-Json -Depth 10 | Set-Content -Path $exceptionsPath

        # Optional removalCount logic
        if ($removalCount) {
            $removalMatches = $dataset | Where-Object {
                $spnMatch = $exception.spnObjectID -and ($_.AppObjectID -eq $exception.spnObjectID) -or
                            $exception.spnNameLike -and ($_.AppDisplayName -ilike "*$($exception.spnNameLike)*")
                $azObjectMatch = $exception.azObjectScopeID -and ($_.AzureObjectScopeID -eq $exception.azObjectScopeID) -or
                                 $exception.azObjectNameLike -and ($_.ObjectName -ilike "*$($exception.azObjectNameLike)*")
                $spnMatch -and $azObjectMatch -and
                ($_.PrivRole -eq $exception.role) -and
                ($_.ObjectType -eq $exception.az_scope_type) -and
                ($_.Tenant -eq $exception.tenant)
            }

            Write-Host "Removal count: $($removalMatches.Count)"
        }
    }
    catch {
        Write-Error "An error occurred: $_"
        throw $_
    }
}
