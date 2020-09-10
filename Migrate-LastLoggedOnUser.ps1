#Set variables in this section

#Enter the flag file name
$MachineFlagName="ForensiTMigrated"

#Set $Debug to true to see debug messages
$Debug=$true


# This script will write a flag file if it has already been run successfully. Here we check if the flag file exists.
$FlagFile = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData) + "\" + $MachineFlagName

If(Test-Path -Path $FlagFile){
    if($Debug) {
        $delete = Read-Host "The 'migrated' flag file has been set. Do you want to delete the flag file and continue? (Y/n)"

        if($delete -eq '' -Or $delete -eq 'Y' -Or $delete -eq 'Yes'){
            Remove-item $FlagFile
        }
        else{
            exit
        }
    }
    else{
        exit
    }
}


# Get the last logged on user name from the registry
$LastLoggedOnSAMUser = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI).LastLoggedOnSAMUser

# A local userame will be in the form .\Username. We need to check for this and replace with the local computer name
$_Temp = $LastLoggedOnSAMUser -split "\\"

if($_Temp[0] -eq '.'){
    $User = $_Temp[1]
    $LastLoggedOnSAMUser = "$env:computername\$User"
}

# Call Profwiz.exe and wait for it to finish
$profwiz = Start-Process -FilePath "./Profwiz.exe" -ArgumentList "/LOCALACCOUNT $LastLoggedOnSAMUser" -Wait -PassThru

$profwiz.WaitForExit();

# If Profwiz.exe does not return an error, write a flag file to prevent this script being run twice
if ($profwiz.ExitCode -eq 0) {
    New-Item -Path $FlagFile -ItemType File| Out-Null
}
else{
    Write-Warning "$_ exited with status code $($profwiz.ExitCode)"

}



