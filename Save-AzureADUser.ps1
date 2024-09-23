#--------------------------------------------------------------------------------
#
# check Microsoft.Graph is installed
#
#
$getmodule=get-module -listavailable "Microsoft.Graph"|sort version -Descending

$installedversion=($getmodule|select -first 1).version

if(-not $getmodule)
{
    $install = Read-Host 'The Microsoft.Graph PowerShell module is not installed. Do you want to install it now? (Y/n)'
    if($install -eq '' -Or $install -eq 'Y' -Or $install -eq 'Yes')
    {  
        If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
        {
            Write-Warning "Administrator permissions are needed to install the Microsoft.Graph PowerShell module.`nPlease re-run this script as an Administrator."
            Exit
        }
        install-module Microsoft.Graph -scope AllUsers
    }
    else
    {
        exit
    }
}

#--------------------------------------------------------------------------------
#
# check Microsoft.Graph version
#
#
$getmodule=get-module -listavailable "Microsoft.Graph"|sort version -Descending
$installedversion=($getmodule|select -first 1).version

$latestversion=(find-module "Microsoft.Graph").version

if($installedversion -lt $latestversion)
{
    $install = Read-Host 'The Microsoft.Graph PowerShell module latest version is not installed. Do you want to install it now? (Y/n)'
    if($install -eq '' -Or $install -eq 'Y' -Or $install -eq 'Yes')
    {  
        If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
        {
            Write-Warning "Administrator permissions are needed to update the Microsoft.Graph PowerShell module.`nPlease re-run this script as an Administrator."
            Exit
        }
        install-module Microsoft.Graph -scope AllUsers -Force
    }
    else
    {
        exit
    }
}

#--------------------------------------------------------------------------------
#
# main process
#


# check for existing connections and disconnect them
$context=get-mgcontext

if($context)
{
    disconnect-mggraph
}

# make new connection
connect-mggraph -scopes "User.Read.All,Organization.Read.All" -NoWelcome

# Get details
$users=get-mguser -all
$tenant=get-mgorganization

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
$xmlWriter.WriteAttributeString("ObjectId", $($tenant.Id))
$xmlWriter.WriteAttributeString("Name", $($tenant.VerifiedDomains.Name));
$xmlWriter.WriteAttributeString("DisplayName", $($tenant.DisplayName));


#Parse the data
ForEach ($user in $users)
{
    $xmlWriter.WriteStartElement("User")
    $xmlWriter.WriteElementString("UserPrincipalName",$($user.UserPrincipalName))
    $xmlWriter.WriteElementString("ObjectId",$($user.Id))
    $xmlWriter.WriteElementString("DisplayName",$($user.DisplayName))
    $xmlWriter.WriteEndElement()
}

$xmlWriter.WriteEndElement()

# Close the XML Document
$xmlWriter.WriteEndDocument()
$xmlWriter.Flush()
$xmlWriter.Close()

disconnect-mggraph

write-host "Azure user ID file created: $((Get-Location).Path)\ForensiTAzureID.xml" -ForegroundColor Green