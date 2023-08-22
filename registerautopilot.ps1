<# 
    .SYNOPSIS
    REgisters the device to windows autopilot.
#>


<# 
    .SYNOPSIS
    Script created to auto register device to autopilot

	.DESCRIPTION
	Creates a scheduled task 
	Checks for Network connection and if internet access available, attempts to register the device to the tenant

	.NOTES
	Version:	6.0.

#>
function LogDateTime {
    ((Get-Date -Format s) + "`t").ToString()
    
}

Start-Transcript "$($env:WINDIR)\Logs\RLS-RegisterAutoPilot.log"


$dest = "$($env:ProgramFiles)\RLS\RegisterAutopilot"
$URL = 'https://logic-mgmt-prod-ae-winp-01.azurewebsites.net:443/api/windowsautopilot/triggers/autopilot_reg_request/invoke?api-version=2022-05-01&sp=%2Ftriggers%2Fautopilot_reg_request%2Frun&sv=1.0&sig=H1WSbQxakdCBwHKnYCAEB-n39c9EFxH8o3nSaojYmtE'
$STTaskName = "RegisterAutopilot"



# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
	if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
		& "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy bypass -File "$PSCommandPath"
		Exit $lastexitcode
	}
}

# Check if scheduled task created
$existingTask = Get-ScheduledTask -TaskName $STTaskName -TaskPath "\RLS\" -ErrorAction SilentlyContinue
if ($null -ne $existingTask) {
	Write-Host "$(LogDateTime)Scheduled task already exists.`r`nRunning registration"
	#Stop-Transcript
	#Begin AutoPilot
	
	$HWIDpath = "$PSScriptRoot\HWID"
	$SerialTag = (gwmi win32_bios).SerialNumber
	$HWIDFileName = "$SerialTag.csv"
	IF (! (Test-Path $HWIDpath) ) { 
		mkdir $HWIDpath 
	}
	Set-Location $PSScriptRoot -verbose
	#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted

	$SerialTag = (Get-CimInstance Win32_BIOS).SerialNumber
	$make = (Get-CimInstance Win32_BIOS).Manufacturer
	$devDetail = (Get-CimInstance -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
	$hash = $devDetail.DeviceHardwareData
	$model = (Get-CimInstance Win32_ComputerSystem).Model
	$product = Get-CimInstance -ClassName SoftwareLicensingService | Select-Object -ExpandProperty OA3xOriginalProductKey


	$c = New-Object psobject -Property @{
		"Device Serial Number" = $SerialTag
		"Windows Product ID"   = $product
		"Hardware Hash"        = $hash
		"Manufacturer name"    = $make
		"Device model"         = $model 
		"Group Tag"            = $GroupTag
	}


	#Prepare the Online components

	#Check if online. Exit if not online
	if (!((Test-NetConnection -ComputerName ztd.dds.microsoft.com -Port 80).TcpTestSucceeded)) {
		Write-Error "No connection online. Exiting."
		Exit 1
	}
	Else {


		<# # Get NuGet
		$provider = Get-PackageProvider NuGet  -ForceBootstrap -ErrorAction Ignore
		if (-not $provider) {
			Write-Host "Installing provider NuGet"
			Find-PackageProvider -Name NuGet -ForceBootstrap -IncludeDependencies
		}
		
		# Get WindowsAutopilotIntune module (and dependencies)
		$module = Import-Module WindowsAutopilotIntune -PassThru -ErrorAction Ignore
		if (-not $module) {
			Write-Host "Installing module WindowsAutopilotIntune"
			Install-Module WindowsAutopilotIntune -Force
		}
		Import-Module WindowsAutopilotIntune -Scope Global

		# Get Azure AD if needed
		if ($AddToGroup) {
			$module = Import-Module AzureAD -PassThru -ErrorAction Ignore
			if (-not $module) {
				Write-Host "Installing module AzureAD"
				Install-Module AzureAD -Force
			}
		}

		# Connect
		$graph = Connect-MSGraphApp -Tenant $TenantId -AppId $AppId -AppSecret $AppSecret
		Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
		 

		# Force the output to a file
		if ($OutputFile -eq "") {
			$OutputFile = "$($env:TEMP)\autopilot.csv"
		} 
		Add-AutopilotImportedDevice -serialNumber $serial -hardwareIdentifier $hash 

		# Wait until the devices have been imported
		$processingCount = 1
		while ($processingCount -gt 0) {
			$current = @()
			$processingCount = 0
			$imported | % {
				$device = Get-AutopilotImportedDevice -id $_.id
				if ($device.state.deviceImportStatus -eq "unknown") {
					$processingCount = $processingCount + 1
				}
				$current += $device
			}
			$deviceCount = $imported.Length
			Write-Host "Waiting for $processingCount of $deviceCount to be imported"
			if ($processingCount -gt 0) {
				Start-Sleep 30
			}
		}
		$importDuration = (Get-Date) - $importStart
		$importSeconds = [Math]::Ceiling($importDuration.TotalSeconds)
		$successCount = 0
		$current | % {
			Write-Host "$($device.serialNumber): $($device.state.deviceImportStatus) $($device.state.deviceErrorCode) $($device.state.deviceErrorName)"
			if ($device.state.deviceImportStatus -eq "complete") {
				$successCount = $successCount + 1
			}
		}
		Write-Host "$successCount devices imported successfully.  Elapsed time to complete import: $importSeconds seconds"
	
		# Wait until the devices can be found in Intune (should sync automatically)
		$syncStart = Get-Date
		$processingCount = 1
		while ($processingCount -gt 0) {
			$autopilotDevices = @()
			$processingCount = 0
			$current | % {
				if ($device.state.deviceImportStatus -eq "complete") {
					$device = Get-AutopilotDevice -id $_.state.deviceRegistrationId
					if (-not $device) {
						$processingCount = $processingCount + 1
					}
					$autopilotDevices += $device
				}	
			}
			$deviceCount = $autopilotDevices.Length
			Write-Host "Waiting for $processingCount of $deviceCount to be synced"
			if ($processingCount -gt 0) {
				Start-Sleep 30
			}
		}
		$syncDuration = (Get-Date) - $syncStart
		$syncSeconds = [Math]::Ceiling($syncDuration.TotalSeconds)
		Write-Host "All devices synced.  Elapsed time to complete sync: $syncSeconds seconds"
#>
		#Calling Logic App
		Write-Host "$(LogDateTime)Calling Logic App"
		$header = @{'Content-Type' = "application/json" }
		$InvokeRest = Invoke-RestMethod -Uri $URL -Method Post -Body $($c | ConvertTo-Json -Compress -Depth 30) -Headers $header

		if ($InvokeRest.RegistrationStatus -eq 'registered') { $SuccessfulRegistration = $true }


		if ($SuccessfulRegistration) {
			
			"$(LogDateTime)Sucessful registration"
			"$(LogDateTime)Deleting the schedule Task"
			Unregister-ScheduledTask -TaskName "$($STTaskName)" -TaskPath "\RLS\" -Confirm:$false -Verbose
			Remove-item "$($dest)\registerautopilot.ps1" -Verbose -Force
			Remove-item "C:\windows\setup\Scripts\SetupComplete.cmd" -Force


			saps "C:\windows\system32\sysprep\sysprep.exe" -args "/OOBE /REBOOT" -NoNewWindow -PassThru

		}
	}
		

	#Check for USB and if present copy
	$USBDrive = gwmi win32_diskdrive | ? { $_.interfacetype -eq "USB" } | % { gwmi -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($_.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition" } | % { gwmi -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($_.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition" } | % { $_.deviceid } | select -First 1
	
	if ($USBDrive ) {
		Write-Host "$(LogDateTime)USB Drive detected. Placing the HWID csv on the USB"
		$RootPath = Join-path $($USBDrive) HWID
		if (!(Test-Path $RootPath -ErrorAction SilentlyContinue) ) { md $RootPath }
		$HWIDFullFileName = Join-path $RootPath $HWIDFileName  

		$c | Select "Device Serial Number", "Windows Product ID", "Hardware Hash" | ConvertTo-CSV -NoTypeInformation | % { $_ -replace '"', '' } | Out-File "$($HWIDFullFileName)" -Verbose
		


	}


}
else {


	# Copy script to location if not already
	if (-not (Test-Path "$dest\registerautopilot.ps1")) {
		md "$($dest)"
		Copy-Item $PSCommandPath "$($dest)\registerautopilot.ps1"
	}

	# Create the scheduled task action
	$action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-NoProfile -ex bypass -WindowStyle Hidden -File `"$dest\registerautopilot.ps1`""

	# Create the scheduled task trigger
	$timespan = New-Timespan -minutes 5
	$triggers = @()
	#$Once = New-ScheduledTaskTrigger -Daily -At 1am
	#$Once.Repetition = (New-ScheduledTaskTrigger -Once -At 1am -RepetitionInterval (New-TimeSpan -Minutes 5)).repetition
	<# 
	$triggers += $Once
	#$triggers += New-ScheduledTaskTrigger -Daily -At 9am
	#$triggers += New-ScheduledTaskTrigger -AtLogOn -RandomDelay $($timespan)
		$StartUpTrigger = New-ScheduledTaskTrigger -AtStartup
		$StartUpTrigger.Repetition = (New-ScheduledTaskTrigger -Once -At 1am -RepetitionInterval (New-TimeSpan -Minutes 5)).repetition
	$triggers += $StartUpTrigger 
	#>
	#$triggers += New-ScheduledTaskTrigger -AtStartup -RandomDelay $timespan 
	$triggers += new-scheduledtaskTrigger -Once -At 2000-01-01T00:00:00Z -RepetitionInterval (New-TimeSpan -Minutes 5)
	$schtsksettings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -StartWhenAvailable 

	# Register the scheduled task
	Register-ScheduledTask -User SYSTEM -Action $action -Trigger $triggers -TaskName "RLS\$($STTaskName)"  -Description "Scheduled Task created to register the device to Windows Autopilot" -Force -RunLevel Highest -Settings $schtsksettings
	Write-Host "$(LogDateTime)Scheduled task created."

} 

