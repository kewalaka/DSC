$resourceGroupName = 'stulab'
$automationAccountName = 'stulab'
$DSCconfigurationName = 'ADcontroller'

$Params = @{"safemodeAdminCred"="safemodeAdminCred";
            "domainAdminCred"="domainAdminCred"}

$ConfigData = @{
    AllNodes = @(

        @{
            Nodename = "*"
            DomainName = "corp.testworld.co.nz"
            DomainNetBIOSName = "test"
            RetryCount = 20
            RetryIntervalSec = 30
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true
            RebootIfNeeded = $true
        },

        @{
            Nodename = "labdc01"
            Role = "First DC"
        },

        @{
            Nodename = "labdc02"
            Role = "Additional DC"
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
