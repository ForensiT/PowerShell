# Check that the needed Microsoft Graph Modules are installed and install only if needed
$Modules = "Microsoft.Graph.Authentication", "Microsoft.Graph.Identity.DirectoryManagement", "Microsoft.Graph.Users"
$CurrentModules = Get-Module -ListAvailable -Name $Modules
$ToInstall = Compare-Object -ReferenceObject @($CurrentModules | Select-Object) -DifferenceObject $Modules
if ($ToInstall) {
    $Install = Read-Host 'The Microsoft Graph PowerShell module is not installed. Do you want to install it now? (Y/n)'
    if ($Install -eq '' -Or $Install -eq 'Y' -Or $Install -eq 'Yes') {
        If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Warning "Administrator permissions are needed to install the Microsoft Graph PowerShell module.`nPlease re-run this script as an Administrator."
            Exit
        }
        Write-Host "Installing: $($ToInstall.InputObject)"
        Install-Module $ToInstall.InputObject
    }
    else {
        Exit
    }
}
#Connect to Microsoft Graph and get all users
Connect-MgGraph -Scopes Directory.Read.All -NoWelcome
$EntraUsers = Get-MgUser -All

# Create the XML file
$XMLSettings = New-Object System.Xml.XmlWriterSettings
$XMLSettings.Indent = $true
$XMLSettings.IndentChars = "    "
$XMLWriter = [System.XML.XmlWriter]::Create("$((Get-Location).Path)\ForensiTAzureID.xml", $XMLSettings)

# Write the XML Declaration and set the XSL
$XMLWriter.WriteStartDocument()
$XMLWriter.WriteProcessingInstruction("xml-stylesheet", "type='text/xsl' href='style.xsl'")

# Start the Root Element 
$XMLWriter.WriteStartElement("ForensiTAzureID")

# Write the Entra ID domain details as attributes
$Context = Get-MgContext
$XMLWriter.WriteAttributeString("ObjectId", $Context.TenantId)
$XMLWriter.WriteAttributeString("Name", (Get-MgDomain).Id);
$TenantName = (Invoke-RestMethod -UseBasicParsing -Uri ("https://login.microsoftonline.com/GetUserRealm.srf?login=$($Context.Account)")).FederationBrandName
$XMLWriter.WriteAttributeString("DisplayName", $TenantName);

#Parse the data
ForEach ($EntraUser in $EntraUsers) {
  
    $XMLWriter.WriteStartElement("User")
    $XMLWriter.WriteElementString("UserPrincipalName", $($EntraUser.UserPrincipalName))
    $XMLWriter.WriteElementString("ObjectId", $($EntraUser.Id))
    $XMLWriter.WriteElementString("DisplayName", $($EntraUser.DisplayName))
    $XMLWriter.WriteEndElement()
}

$XMLWriter.WriteEndElement()
# Close the XML Document
$XMLWriter.WriteEndDocument()
$XMLWriter.Flush()
$XMLWriter.Close()
write-host "Entra ID user file created: $((Get-Location).Path)\ForensiTAzureID.xml"
