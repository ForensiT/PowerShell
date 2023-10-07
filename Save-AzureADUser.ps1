# Check that Microsoft.Graph is installed
if (-Not (Get-Module -ListAvailable -Name Microsoft.Graph)) {

    $install = Read-Host 'The Microsoft Graph PowerShell module is not installed. Do you want to install it now? (Y/n)'

    if ($install -eq '' -Or $install -eq 'Y' -Or $install -eq 'Yes') {
        If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Warning "Administrator permissions are needed to install the Microsoft Graph PowerShell module.`nPlease re-run this script as an Administrator."
            Exit
        }
        Write-Host "Installing"
        Install-Module -Name Microsoft.Graph
    }
    else {
        exit
    }
}
#Connect to Microsoft Graph and get all users
Connect-MgGraph -Scopes Directory.Read.All -NoWelcome
$EntraUsers = Get-MgUser -All

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

# Write the Entra ID domain details as attributes
$Context = Get-MgContext
$xmlWriter.WriteAttributeString("ObjectId", $Context.TenantId)
$xmlWriter.WriteAttributeString("Name", (get-MgDomain).id);
$TenantName = (Invoke-RestMethod -UseBasicParsing -Uri ("https://login.microsoftonline.com/GetUserRealm.srf?login=$($Context.Account)")).FederationBrandName
$xmlWriter.WriteAttributeString("DisplayName", $TenantName);

#Parse the data
ForEach ($EntraUser in $EntraUsers) {
  
    $xmlWriter.WriteStartElement("User")
    $xmlWriter.WriteElementString("UserPrincipalName", $($EntraUser.UserPrincipalName))
    $xmlWriter.WriteElementString("ObjectId", $($EntraUser.Id))
    $xmlWriter.WriteElementString("DisplayName", $($EntraUser.DisplayName))
    $xmlWriter.WriteEndElement()
}

$xmlWriter.WriteEndElement()
# Close the XML Document
$xmlWriter.WriteEndDocument()
$xmlWriter.Flush()
$xmlWriter.Close()
write-host "Entra ID user file created: $((Get-Location).Path)\ForensiTAzureID.xml"
