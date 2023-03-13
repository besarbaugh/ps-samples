# Load the Windows.winmd file
Add-Type -Path "C:\Program Files (x86)\Windows Kits\10\UnionMetadata\10.0.17763.0\Windows.winmd"

# Load the Microsoft.Windows.SDK.Contracts namespace
using namespace Windows.Foundation.Metadata
$contract = [ApiInformation]::FindAllApiContractsByPackageFamilyName("Microsoft.Windows.SDK.Contracts") | Select-Object -First 1

# Load the Microsoft.Windows.SDK.Contracts.dll
$contractFile = Join-Path $env:SystemRoot "System32\WinMetadata\$($contract.PackageName).dll"
Add-Type -Path $contractFile