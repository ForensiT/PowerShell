
# Check that AzureAD is installed
if (-Not (Get-Module -ListAvailable -Name AzureAD)) {

    $install = Read-Host 'The AzureAD PowerShell module is not installed. Do you want to install it now? (Y/n)'

    if($install -eq '' -Or $install -eq 'Y' -Or $install -eq 'Yes'){
        If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] “Administrator”))
        {
            Write-Warning “Administrator permissions are needed to install the AzureAD PowerShell module.`nPlease re-run this script as an Administrator.”
            Exit
        }

        write-host "Installing"
        Install-Module -Name AzureAD
    }
    else {
        exit
    }
}

# Create a temporary file to hold the unformatted results of our Get-AzureADUser query
$TempFile = New-TemporaryFile

#Go ahead and attempt to get the Azure AD user IDs, but catch the error if there is no existing connection to Azure AD
Try
{
    Get-AzureADUser -All:$true | Export-Csv -Path $TempFile -NoTypeInformation
}
Catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException]
{
    #Connect to Azure AD. This will show a prompt.
    Connect-AzureAD | Out-Null

    #Try again
    Get-AzureADUser -All:$true | Export-Csv -Path $TempFile -NoTypeInformation
}


# Get the tennant details
$Tenant = Get-AzureADTenantDetail

# Get the unformatted data from the temporary file
$azureADUsers = import-csv $TempFile

# Create the XML file
$xmlsettings = New-Object System.Xml.XmlWriterSettings
$xmlsettings.Indent = $true
$xmlsettings.IndentChars = "    "

$XmlWriter = [System.XML.XmlWriter]::Create("$((Get-Location).Path)\ForensiTAzureID.xml", $xmlsettings)

# Write the XML Declaration and set the XSL
$xmlWriter.WriteStartDocument()
$xmlWriter.WriteProcessingInstruction("xml-stylesheet", "type='text/xsl' href='style.xsl'")

# Start the Root Element 
$xmlWriter.WriteStartElement("ForensiTAzureID")

# Write the Azure AD domain details as attributes
$xmlWriter.WriteAttributeString("ObjectId", $($Tenant.ObjectId))
$xmlWriter.WriteAttributeString("Name", $($Tenant.VerifiedDomains.Name));
$xmlWriter.WriteAttributeString("DisplayName", $($Tenant.DisplayName));


#Parse the data
ForEach ($azureADUser in $azureADUsers){
  
    $xmlWriter.WriteStartElement("User")

        $xmlWriter.WriteElementString("UserPrincipalName",$($azureADUser.UserPrincipalName))
        $xmlWriter.WriteElementString("ObjectId",$($azureADUser.ObjectId))
        $xmlWriter.WriteElementString("DisplayName",$($azureADUser.DisplayName))

    $xmlWriter.WriteEndElement()
    }

$xmlWriter.WriteEndElement()

# Close the XML Document
$xmlWriter.WriteEndDocument()
$xmlWriter.Flush()
$xmlWriter.Close()


# Clean up
Remove-Item $TempFile
 
write-host "Azure user ID file created: $((Get-Location).Path)\ForensiTAzureID.xml”

