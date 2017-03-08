$resourceGroupName = 'kewalaka'
$automationAccountName = 'kewalaka'
$DSCconfigurationName = 'ChocolateyServer'

$Params = @{"domainAdminCred"="domainAdminCred"}

$ConfigData = @{
    AllNodes = @(

        @{
            Nodename = "*"
            DomainName = "corp.testworld.co.nz"
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true
            RebootIfNeeded = $true
        },

        @{
            Nodename = "labpms01"
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
