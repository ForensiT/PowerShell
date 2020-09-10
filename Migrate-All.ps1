# Functions

function Set-XMLAttributeValue
{
    param ([Parameter(Mandatory=$true)][string]$XML, [Parameter(Mandatory=$true)][string]$Attribute, [Parameter(Mandatory=$true)][string]$Value)

    $Search = "<$Attribute>"
    $Start = $XML.IndexOf($Search)

    If($Start -eq -1){
        return $XML
    }


    $End = $XML.IndexOf("</$Attribute>")

    $Pre = $XML.Substring(0, $Start + $Search.Length) 
    $Post = $XML.Substring($End) 

    $New = $Pre + $Value + $Post

    return $New
}


function Get-XMLAttributeValue
{
    param ([Parameter(Mandatory=$true)][string]$XML, [Parameter(Mandatory=$true)][string]$Attribute)

    $Search = "<$Attribute>"
    $Start = $XML.IndexOf($Search)

    If($Start -eq -1){
        return
    }


    $End = $XML.IndexOf("</$Attribute>")

    $Value = $XML.Substring($Start + $Search.Length, $End - ($Start + $Search.Length)) 

    return $Value
}






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



# Copy the migration files locally to C:\ProgramData\ForensiT\Migrate
$TargetFolder = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData) + "\\ForensiT\\Migrate"


New-Item -Path $TargetFolder -ItemType directory -Force | Out-Null
Copy-Item ".\Profwiz.exe" "$TargetFolder\\Profwiz.exe"


$Config = [String](Get-Content -Path ".\Profwiz.config" -Raw)

# User lookup file
$Value = Get-XMLAttributeValue $Config "UserLookupFile"

If(-Not [string]::IsNullOrEmpty($Value)){

    $LookFile = Split-Path $Value -leaf
    $Config = Set-XMLAttributeValue $Config "UserLookupFile" $LookFile
    Copy-Item $Value "$TargetFolder\\$LookFile"
}


# Device Lookup File
$Value = Get-XMLAttributeValue $Config "MachineLookupFile"

If(-Not [string]::IsNullOrEmpty($Value)){

    $LookFile = Split-Path $Value -leaf
    $Config = Set-XMLAttributeValue $Config "MachineLookupFile" $LookFile
    Copy-Item $Value "$TargetFolder\\$LookFile"
}


# Follow-0n File
$Value = Get-XMLAttributeValue $Config "RunAs"

If(-Not [string]::IsNullOrEmpty($Value)){

    $LookFile = Split-Path $Value -leaf
    $Config = Set-XMLAttributeValue $Config "RunAs" $LookFile
    Copy-Item $Value "$TargetFolder\\$LookFile"
}



# Azure ID File
$Value = Get-XMLAttributeValue $Config "AzureObjectIDFile"

If(-Not [string]::IsNullOrEmpty($Value)){

    $LookFile = Split-Path $Value -leaf
    $Config = Set-XMLAttributeValue $Config "AzureObjectIDFile" $LookFile
    Copy-Item $Value "$TargetFolder\\$LookFile"
}



# Write the updated config file
Set-Content -Path "$TargetFolder\\Profwiz.config" -Value $Config -Force 



# Call Profwiz.exe and wait for it to finish
$profwiz = Start-Process -FilePath "$TargetFolder\\Profwiz.exe" -ArgumentList "/REBOOTDELAY 30" -Wait -PassThru

$profwiz.WaitForExit();

# If Profwiz.exe does not return an error, write a flag file to prevent this script being run twice
if ($profwiz.ExitCode -eq 0) {
    New-Item -Path $FlagFile -ItemType File| Out-Null
}
else{
    Write-Warning "$_ exited with status code $($profwiz.ExitCode)"

}


# Cleanup
Remove-item $TargetFolder -Recurse





















