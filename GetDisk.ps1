# Build a command that will be run inside the VM.
$remoteCommand =
@"
#Get first disk that is raw with the lowest disk number (because we may not know what number it will be)
# F volume
Get-Partition
dir D:
"@
# Save the command to a local file
Set-Content -Path .\DriveCommand.ps1 -Value $remoteCommand
# Invoke the command on the VM, using the local file
Invoke-AzureRmVMRunCommand -Name $vm.name -ResourceGroupName $vm.ResourceGroupName -CommandId 'RunPowerShellScript' -ScriptPath .\DriveCommand.ps1
# Clean-up the local file
Remove-Item .\DriveCommand.ps1