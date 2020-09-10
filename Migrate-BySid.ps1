

# Internal script variables DO NOT change
$Filter = $null
$LookupFile = $null
$Reboot = $false


######################################################################################################################
# Set your script variables here

# Uncomment the filter that you want to use
#$Filter = "LocalSids"
#$Filter = "DomainSids"
#$Filter = "AzureSids"

#If you are filtering by Domain SIDs, set the domain RID for your domain
#$DomainRID = "S-1-5-21-2010793018-3992016981"

# Set $PassByFolderName to $True to migrate using the profile folder name, or $False to migrate using the user Sid
# Note: Reserved for future use. Setting to $False is not currently supported.
$PassByFolderName = $True

# If you want to use a lookup file, specify that here
#$LookupFile = ".\Users.csv"

######################################################################################################################



# Functions

# The function requires the csv file to have a header: Oldname,NewName 
function Get-NewNameFromLookupFile
{
    param ([Parameter(Mandatory=$true)][string]$LookupFile, [Parameter(Mandatory=$true)][string]$OldName)

    $Header = 'OldName', 'NewName'
    $lookup = import-csv $lookupFile -Header $Header

    ForEach ($row in $lookup){

        if($($row.OldName) -eq $oldName)
        {
            return $($row.NewName)
            break
        }
    }
}
 
######################################################################################################################






if($Filter -eq $null){

    Write-Warning "You need to edit this script to configure your migration settings before it can be run."
    exit
}


if(($Filter -eq "DomainSids") -and ($DomainRID -eq $null)){

    Write-Warning "Domain RID has not been set."
    exit
}



# We can filter local accounts by getting the SID for the Administrator account, and finding the RID
$AdminSID = (Get-LocalUser | Where-Object {$_.SID -like 'S-1-5-*-500'}).SID
$LocalMachineRID = $AdminSID.Value.subString(0, $AdminSID.Value.Length - 4)


#Enumerate profiles in the registry
$keys = Get-ChildItem -Path 'Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'

foreach ($key in $keys) {
    $sid = $key.PSChildName
    
    # Filter out System SIDs and Administrator accounts
    if(($sid.Length -eq 8) -Or ($sid -Like 'S-1-5-80-*') -Or ($sid -Like '*-500')){
        continue
    }


    if($Filter -eq "LocalSids"){

        # Filter on local accounts
        if($sid -NotLike $LocalMachineRID +'*'){
            continue
        }
    }
    elseif($Filter -eq "DomainSids"){

        # Filter on domain RID
        if($sid -NotLike $DomainRID +'*'){
            continue
        }
    }
    elseif($Filter -eq "AzureSids"){

        # Filter on Azure SIDs
        if($sid -NotLike 'S-1-12-*'){
            continue
        }
    }


    # Get the profile folder name
    $profileImagePath = (Get-ItemProperty -Path Registry::$key).ProfileImagePath
    $profileName = Split-Path $profileImagePath -leaf

    if($PassByFolderName -eq $True){
        $SourceAccount = $profileName
    }
    else{
        $SourceAccount = $Sid
    }


    # Remove any suffix from the folder name
    $_Temp = $profileName.split(".")

    if(-Not $_Temp[0] -eq ""){
        $LookupName = $_Temp[0]
    }
    else{
        $LookupName = $profileName
    }


    # Get new user name if we are using a lookup file
    $newUserName = $null

    if($LookupFile -ne $null){
        $newUserName = Get-NewNameFromLookupFile $LookupFile $LookupName
    }  

    
    # If we don't have a new name, use the current name
    if($newUserName -eq $null){
        $newUserName = $LookupName
    }

  
    # Call Profwiz.exe...
    $profwiz = Start-Process -FilePath "./Profwiz.exe" -ArgumentList "/SOURCEPROFILE $SourceAccount /TARGETACCOUNT $newUserName /NOREBOOT" -wait -PassThru
 
    #... and wait for it to finish
    $profwiz.WaitForExit();


    # If there is an error print it
    if ($profwiz.ExitCode -ne 0) {
        Write-Warning "$_ exited with status code $($profwiz.ExitCode)"
    }
    else{
        $Reboot = $true
    }
}

#Reboot the machine
if($Reboot -eq $true){
    Restart-Computer
}