
function Write-Log {
    param (
        $FilePath = "$env:windir\ccmsetup\logs\CLT-PrintConfiguration-detect.log",
        $Message,
        [Int16]$Severity = 1,
        $Source = "Default"
        
    )

    [DateTime]$DateTimeNow = Get-Date
    $LogTime = $DateTimeNow.ToString('HH\:mm\:ss.fff')
    $LogDate = $DateTimeNow.ToString('MM-dd-yyyy')

    If ($script:MyInvocation.Value.ScriptName) {
        [String]$ScriptSource = Split-Path -Path $script:MyInvocation.Value.ScriptName -Leaf -ErrorAction 'Stop'
    }
    Else {
        [String]$ScriptSource = Split-Path -Path $script:MyInvocation.MyCommand.Definition -Leaf -ErrorAction 'Stop'
    }
    


    ##
    $("<![LOG[$Message]LOG]!>" + "<time=`"$LogTime`" " + "date=`"$LogDate`" " + "component=`"$Source`" " + "context=`"$([Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " + "type=`"$Severity`" " + "thread=`"$PID`" " + "file=`"$ScriptSource`">") | Out-File -FilePath $FilePath -Append -NoClobber -Force -Encoding 'UTF8'
    Write-Host "$Message"
}




#Import Site Data
Write-Log -Message "Importing Site Data Information" -WriteHost $true -ScriptSection Initialization

#Download csv from storage

#Download via URI using SAS
$BlobUri = [System.UriBuilder]'https://stmgmtprdasemem01.blob.core.windows.net/site-lists/Sites.csv'
$BlobSasToken = 'sp=r&st=2023-10-08T22:46:58Z&se=2024-10-01T07:46:58Z&spr=https&sv=2022-11-02&sr=b&sig=D1YKukDHyCuPtpfybP9uWLF%2FnhGcCCIWZIm651MMpb0%3D'
$BlobUri.Query = $BlobSasToken
$FullUri = "$($BlobUri.Uri)" #.AbsoluteUri
$Sitesdatafile = "$env:ProgramData\RLS\SiteList\sites.csv"

#Test if connectivity to Blob
if (
(Test-NetConnection $BlobUri.Host -Port $BlobUri.Port).TcpTestSucceeded  ) {

    Write-Log -Message "URI accessible. Checking file details" -Severity 1
    
    #Get source file modified date
    try {
        $SitesdatafilelastModified = (Invoke-WebRequest -Uri $FullUri -UseBasicParsing).Headers.'Last-Modified' | Get-Date
        Write-Log -Message "Data file last modified $($SitesdatafilelastModified | Out-String)" -Severity 1
    }
    catch {
        Write-Log -Message "$_" -Severity 3
    }
    



}
else {
    
    Write-Log -Message "Unable to connect to host: $($BlobUri.Host). Checking if file available locally" -Severity 2
    #Check if File Locally available
    if (!(Test-Path $Sitesdatafile -ErrorAction SilentlyContinue)) {
        Write-Log -Message "Unable to connect to host: $($BlobUri.Host)" -Severity 3
        Exit 69000
    }
    else {
        Write-Log -Message "Using locally cached file" -Severity 2
    }
}

#Create Target directory for the sites file
if (!(Test-Path (Split-Path $Sitesdatafile) -ErrorAction SilentlyContinue)) {
    mkdir "$(Split-Path $Sitesdatafile)"
}

#Begin Download
#(New-Object System.Net.WebClient).DownloadFile($FullUri, $Sitesdatafile)
Write-Log -Message "Connecting to $($FullUri)" -Severity 1
Invoke-WebRequest -Uri $FullUri -OutFile "$($Sitesdatafile)" -UseBasicParsing


#Import sites data to a lookuptable
$SiteData = Import-Csv "$($Sitesdatafile)" | # (Join-Path "$($envProgramData)\RLS\SiteList" Sites.csv) |
Select-Object *, @{
    'Name'       = 'NetIPAddress_obj'
    'Expression' = { [IPAddress]$_.SiteNetIPAddress }
}, @{
    'Name'       = 'NetMask_obj'
    'Expression' = { [IPAddress]$_.Sitenetmask }
}


#Get Computer's IP address
$ipaddress = Get-CimInstance  Win32_NetworkAdapterconfiguration -Filter "ipENABLED = 'True'" |
Select-Object -First 1 |
Select-Object -ExpandProperty IPAddress |
Select-Object -First 1 |
ForEach-Object {
    [IPAddress]$_
}

Write-log -Message "Computer IP address: $($ipaddress.IPAddressToString)"


#Serach for Site based on Computer IP from sites data csv 
$Source = ForEach ($datum in $SiteData  ) {
    
    If ($datum.NetIPAddress_obj.Address -eq (
            $ipaddress.Address -band $datum.NetMask_obj.Address
        )
    ) {
        $datum
        Break
    }
}

if ($Source) {
    Write-log -Message "Found Site: $($Source.sitename)"
}
else {
    Write-log -Message "NO SITE Found. Default to prompt" -Severity 2
}



$SourceCLT_Printers = ($Source.CLT_Printer -split ';')
Write-log -message "Found $($SourceCLT_Printers.count) printers"

if ($SourceCLT_Printers.count -gt 1 ) {

    #Need manual selection of printers to set as default
    Write-Log -Message "More than one forms printer has been detected. Need to confirm default printer."
    $MultiplePrinters = $true

}
elseif ($SourceCLT_Printers.count -lt 1 -or $null -eq $SourceCLT_Printers ) {

    "No Printers detected in Source. Exiting Script"
    Exit 69001
}


#Get Existing Printers Installed
#saps -FilePath "$env:windir\system32\rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /ge"
        
#Perform Printer Map
ForEach ($SourceCLT_Printer in $SourceCLT_Printers) {

    $CLTPrinterIP = ($SourceCLT_Printer -split ":") | Select-Object -Index 0
    $CLTPrinterIPPortName = "IP_$CLTPrinterIP" 
    $CLTPrinterDriver = ($SourceCLT_Printer -split ":") | Select-Object -Index 1
    $CLTPrinterName = ($SourceCLT_Printer -split ":") | Select-Object -Index 2


    #Test if Printer available
    Write-log -message "Processing $($CLTPrinterName) with IP $CLTPrinterIP"

    #Check if printer already installed


    #Install Port
    if (!(Get-PrinterPort -Name $CLTPrinterIPPortName -ErrorAction SilentlyContinue )) {
        Write-Host "$CLTPrinterName - No IP Port $CLTPrinterIP"
        Exit 1
    } 
    
    #Install Printer
    if (!(Get-Printer -Name $CLTPrinterName -ErrorAction SilentlyContinue)) {
        Write-Host "$CLTPrinterName - Not Mapped"
        Exit 1
    }
    else {
        Write-Host "[SUCCESS] $CLTPrinterName Mapped"
    }

}