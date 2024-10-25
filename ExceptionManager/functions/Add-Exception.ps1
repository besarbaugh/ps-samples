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
        # Load configuration settings
        $configPath = ".\config.json"
        if (-not (Test-Path -Path $configPath)) {
            throw "config.json not found."
        }
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

        if (-not $exceptionsPath) {
            $exceptionsPath = $config.exceptionsPath
        }
        if (-not $datasetPath) {
            $dataset = Get-Dataset -datasetDir $config.datasetDir -filenamePattern $config.filenamePattern
        } else {
            $dataset = Import-Csv -Path $datasetPath
        }

        # Dual-mode: CSA vs spnNameLike
        $useCSA = $config.csaEnforced

        if ($useCSA) {
            # Future: CSA filtering logic
            Write-Host "CSA enforced. Using CSA attributes for filtering."
            
            $csaSpnEonid = $config.csaAttributes.spnEonid
            $csaSpnEnv = $config.csaAttributes.spnEnv
            
            # Here we validate against custom attributes instead of display names
            $spnDetails = $dataset | Where-Object {
                $_.CustomSecurityAttribute -eq $csaSpnEonid -and $_.CustomSecurityAttribute -eq $csaSpnEnv
            }

            if (-not $spnDetails) {
                throw "SPN details not found based on CSAs."
            }
        } else {
            # Current: spnNameLike logic
            Write-Host "CSA not enforced. Using spnNameLike for filtering."
            if ($PSCmdlet.ParameterSetName -eq 'spnNameLikeSet') {
                $matchedSPNs = $dataset | Where-Object { $_.AppDisplayName -icontains "$spnNameLike" }
                if ($matchedSPNs.Count -eq 0) {
                    throw "No SPN found with AppDisplayName matching the spnNameLike pattern."
                }
            }
        }

        # Initialize exception object
        $exception = @{
            spnEonid = $spnEonid
            azScopeType = $azScopeType
            role = $role
            tenant = $tenant
            date_added = (Get-Date).ToString('MM/dd/yyyy')
        }

        # Add the new exception logic (same as before)
        # ...
        
    }
    catch {
        Write-Error "An error occurred: $_"
        throw $_
    }
}
