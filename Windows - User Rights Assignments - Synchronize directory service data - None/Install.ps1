<#

    .SYNOPSIS
    Applies an LGPO policy to the Windows OS

    .DESCRIPTION
    Confirm that the variables $SecTemplateKey  & $SecTemplateValue reflect the required values


#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall')]
    [String]$DeploymentType = 'Install'
)

[String]$appName = 'Windows - User Rights Assignments - Synchronize directory service data - NONE'
$OrganisationShortCode = 'AEC'

$dirFiles = Join-Path "$($PSScriptRoot)" "Files" 
$LGPOExe = Join-Path "$($dirFiles)" LGPO.exe
$SecTemplateKey = "SeSyncAgentPrivilege"
$SecTemplateValue = ''
$AppRegistryKey = "HKLM:\Software\$OrganisationShortCode\$($appname)"

function Get-IniValue ($filePath)
{
	$ini = @{}
	switch -regex -file "$($FilePath)"
	{
    	"^\[(.+)\]" # Section
    	{
        	$section = $matches[1]
        	$ini[$section] = @{}
        	$CommentCount = 0
    	}
    	"^(;.*)$" # Comment
    	{
        	$value = $matches[1]
        	$CommentCount = $CommentCount + 1
        	$name = “Comment” + $CommentCount
        	$ini[$section][$name] = $value
    	}
    	"(.+?)\s*=(.*)" # Key
    	{
        	$name,$value = $matches[1..2]
        	$ini[$section][$name] = $value
    	}
	}
	return $ini
}


If ($deploymentType -ine 'Uninstall' ) {
    
 

    #Pre-Install
    if (!(Test-Path "$($env:TEMP)\PRE")) {
        md "$($env:TEMP)\PRE"
    }
    Start-Process -FilePath "$($LGPOExe)" -ArgumentList "/b `"$($env:TEMP)\PRE`"" -NoNewWindow -Wait -PassThru
    
    $GptTmplinf = (Get-ChildItem "$($env:TEMP)\PRE" -Filter GptTmpl.inf -Recurse | Sort-Object lastwritetime | Select-Object -Last 1).fullname
    $GptTmplinfValuePRE = Get-IniValue "$($GptTmplinf)"
    $GptTmplinfValuePRE = $GptTmplinfValuePRE.'Privilege Rights'.'SeSyncAgentPrivilege'

    #Install
    Start-Process -FilePath "$($LGPOExe)" -ArgumentList "/g `"$($dirFiles)`"" -NoNewWindow -Wait -PassThru

        #Set the tag for Intune detection
        if ( !( Get-Item $($AppRegistryKey) -ErrorAction SilentlyContinue)) {

            New-Item "$($AppRegistryKey)" -Force -ErrorAction SilentlyContinue
        }
        
        New-ItemProperty -Path "$($AppRegistryKey)" -Name 'Status' -Value $true -PropertyType "string" -Force | Out-Null

        #Set the original value in the registry for rollback
        New-ItemProperty -Path "$($AppRegistryKey)" -Name 'PrevValue' -Value "$($GptTmplinfValuePRE)" -PropertyType "string" -Force | Out-Null
    
}
ElseIf ($deploymentType -ieq 'Uninstall') {

    Remove-Item -Path "$($AppRegistryKey)" -Force | Out-Null

}