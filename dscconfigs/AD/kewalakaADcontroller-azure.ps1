$resourceGroupName = 'kewalaka'
$automationAccountName = 'kewalaka'
$DSCconfigurationName = 'ADcontroller'

# get credentials from Azure Automation
$Params = @{"safemodeAdminCred"="safemodeAdminCred";
            "domainAdminCred"="domainAdminCred"}

$ConfigData = @{
    AllNodes = @(

        @{
            Nodename = "*"
            DomainName = "kewalaka.nz"
            DomainNetBIOSName = "test"
            RetryCount = 20
            RetryIntervalSec = 30
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true  # DSC resources are encrypted on Azure, so this is OK
            RebootIfNeeded = $true
        },

        @{
            Nodename = "labdc01"
            Role = "First DC"
            SiteName = "AustraliaSouthEast"
            # Networking details are set using ARM template
        },

        @{
            Nodename = "labdc02"
            Role = "Additional DC"
            SiteName = "AustraliaSouthEast"            
            # Networking details are set using ARM template
        }
    )
}


if ( $AzureCred -eq $null )
{
    $AzureCred = Get-Credential -Message "Please enter your Azure Credentials" -UserName "stuart.mace@powerco.co.nz"
}

$azureAccount = Login-AzureRmAccount -Credential $AzureCred -SubscriptionName 'Visual Studio Enterprise'

Start-AzureRmAutomationDscCompilationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                                                -ConfigurationName $DSCconfigurationName -ConfigurationData $ConfigData `
                                                -Parameters $Params

#Get-AzureRmAutomationDscCompilationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ConfigurationName $DSCconfigurationName
