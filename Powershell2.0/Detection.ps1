$State = (Get-WindowsOptionalFeature -FeatureName MicrosoftWindowsPowerShellV2Root -Online).State

if ($State -eq 'enabled') {
    Write-Host "Powershell 2.0 Enabled"
    Exit 0
} Else {
    Write-Host "Powershell 2.0 Not Enabled"
    Exit 1}