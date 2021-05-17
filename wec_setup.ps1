####################################
# Download WEF Palantir Templates
###################################

# download zip with all Palantir samples
if (-not ([Net.ServicePointManager]::SecurityProtocol).tostring().contains("Tls12")){ #there is no need to set Tls12 in 1809 releases, therefore for insider it does not apply
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
Invoke-WebRequest -UseBasicParsing -Uri https://github.com/palantir/windows-event-forwarding/archive/master.zip -OutFile $env:USERPROFILE\Downloads\PalantirSamples.zip

#unzip
Expand-Archive -Path $env:USERPROFILE\Downloads\PalantirSamples.zip -DestinationPath $env:USERPROFILE\Downloads


####################################
# Setup Palantir WEF Custom Channels
####################################

# setup custom event channels
$OutputFolder="C:\WEC"
$CustomComplile = $false

#Create output folder if does not exist
if(!([System.IO.File]::Exists($OutputFolder))) { 
    New-Item $OutputFolder -ItemType Directory -ErrorAction SilentlyContinue
}
$ManifestFile = "$env:USERPROFILE\Downloads\windows-event-forwarding-master\windows-event-channels\CustomEventChannels.man"
$DLLFile = "$env:USERPROFILE\Downloads\windows-event-forwarding-master\windows-event-channels\CustomEventChannels.dll"

if($CustomComplile -eq $false){
    Copy-Item -Path $ManifestFile -Destination $OutputFolder
    Copy-Item -Path $DLLFile -Destination $OutputFolder
}else{
    $ProgressPreference='SilentlyContinue' #for faster download
    
    #Download Windows 10 RS5 SDK
    Invoke-WebRequest -UseBasicParsing -Uri https://go.microsoft.com/fwlink/p/?LinkID=2033908 -OutFile "$OutputFolder\SDKRS5_Setup.exe"
    
    #Install SDK RS5
    Start-Process -Wait -FilePath "$OutputFolder\SDKRS5_Setup.exe" -ArgumentList "/features OptionId.DesktopCPPx64 /quiet"

    #Create Man file or run setup
    #Variables
    $CustomEventChannelsFileName="CustomEventChannels"
    #Compile manifest https://docs.microsoft.com/en-us/windows/desktop/WES/compiling-an-instrumentation-manifest
    $CustomEventChannelsFileName="CustomEventChannels"
    $ToolsPath="C:\Program Files (x86)\Windows Kits\10\bin\10.0.17763.0\x64"
    $dotNetPath="C:\Windows\Microsoft.NET\Framework64\v4.0.30319"

    # User Palantir Manifest File
    Copy-Item "$ManifestFile" "$OutputFolder\$CustomEventChannelsFileName.man"
    Start-Process -Wait -FilePath "$ToolsPath\mc.exe" -ArgumentList "$OutputFolder\$CustomEventChannelsFileName.man" -WorkingDirectory $OutputFolder
    Start-Process -Wait -FilePath "$ToolsPath\mc.exe" -ArgumentList "-css CustomEventChannels.DummyEvent  $OutputFolder\$CustomEventChannelsFileName.man" -WorkingDirectory $OutputFolder
    Start-Process -Wait -FilePath "$ToolsPath\rc.exe" -ArgumentList "$OutputFolder\$CustomEventChannelsFileName.rc"
    Start-Process -Wait -FilePath "$dotNetPath\csc.exe" -ArgumentList "/win32res:$OutputFolder\$CustomEventChannelsFileName.res /unsafe /target:library /out:$OutputFolder\$CustomEventChannelsFileName.dll"
}

#Some variables
$CollectorServerName="Collector"
$CustomEventChannelsFileName="CustomEventChannels"
$CustomEventsFilesLocation="$OutputFolder"

#configure Event Forwarding on collector server
WECUtil qc /q

#Create custom event forwarding logs
Stop-Service Wecsvc
#unload current event channnel (commented as there is no custom manifest)
if([System.IO.File]::Exists($CustomEventChannelsFileName.man)) {
    wevtutil um C:\windows\system32\$CustomEventChannelsFileName.man
}

#copy new man and dll
$files="$CustomEventChannelsFileName.dll","$CustomEventChannelsFileName.man"
$Path="$CustomEventsFilesLocation"
foreach ($file in $files){
    Copy-Item -Path "$path\$file" -Destination C:\Windows\system32
}

#load new event channel file and start Wecsvc service
wevtutil im "C:\windows\system32\$CustomEventChannelsFileName.man"
Start-Service Wecsvc

$OutputFolder="C:\WEC"
Remove-Item -Path $OutputFolder -Force -Recurse

###############################
# Configure WEF Subscriptions
##############################

# Enable WEF quick config
WECUtil qc /q

# Import panatir examples and default to enabled (disable custom log channels logging as well)
$XMLFiles=Get-ChildItem "$env:USERPROFILE\Downloads\windows-event-forwarding-master\wef-subscriptions" -Filter *.xml
# Process Templates, add AD group to each template and create subscription
foreach ($XMLFile in $XMLFiles){
    # Subscribe all domain controllers and computers
    $AllowedSourceDomainComputers="O:NSG:NSD:(A;;GA;;;DC)(A;;GA;;;NS)(A;;GA;;;DD)"
    $Enabled="true"
    $LogFile="ForwardedEvents"
    try{
    [xml]$XML=get-content $XMLFile.FullName
        $xml=$XML
        $xml.subscription.Enabled=$Enabled
        $xml.subscription.AllowedSourceDomainComputers=$AllowedSourceDomainComputers
        # override eventlog - required if not using custom event channels
        # $xml.subscription.LogFile=$LogFile
        $xml.Save("$env:TEMP\temp.xml")
        wecutil cs "$env:TEMP\temp.xml"
        remove-item -Path "$env:TEMP\temp.xml"
    }catch{
        write-output ("Error processing subscription {0}: {1}" -f $XMLFile.FullName, $_.Message)
    }
}
