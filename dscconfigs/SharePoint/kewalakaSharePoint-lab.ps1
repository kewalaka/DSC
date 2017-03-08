$resourceGroupName = 'kewalaka'
$automationAccountName = 'kewalaka'
$DSCconfigurationName = 'SharePointServer'

$Params = @{"SPfarmPassphrase"  = "SPfarmPassphrase";
            "SPfarmAdmin"       = "SPfarmAdmin";
            "SPInstallAccount"  = "SPInstallAccount";
            "domainAdminCred"="domainAdminCred"
           }

$ConfigData = @{
    AllNodes = @(

        @{
            Nodename = "*"
            CredSSPDelegates = "*.testworld.co.nz"
            SPBinaryPath     = "C:\SP\2016\SharePoint"
            ProductKey       = "NQGJR-63HC8-XCRQH-MYVCH-3J3QR"            
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true
            ConfigDatabaseServer = "labsqloz"
            Domain = "corp.testworld.co.nz"
        },

        @{
            Nodename = "labspfe01"
            FirstServer = $true
            Role = "FrontEndandQuery"
        },

        @{
            Nodename = "labspas01"
            Role = "ApplicationandSearch"
        }
    )
}


if ( $AzureCred -eq $null )
{
    $AzureCred = Get-Credential -Message "Please enter your Azure Credentials" -UserName "stuart.mace@powerco.co.nz"
}

$azureAccount = Login-AzureRmAccount -Credential $AzureCred -SubscriptionName 'Visual Studio Enterprise'

function New-AutomationCredentials
{
param (
    [string]$name,
    [string]$username
)

    if ((Get-AzureRmAutomationCredential -ResourceGroupName $resourceGroupName `
                                         -AutomationAccountName $automationAccountName `
                                         -Name $name -ErrorAction SilentlyContinue) -eq $null)
    { 
        $password = read-host "Please enter password for $username" -AsSecureString
        $creds = new-object -typename System.Management.Automation.PSCredential -argumentlist $username,$password

        New-AzureRmAutomationCredential -ResourceGroupName $resourceGroupName `
                                        -AutomationAccountName $automationAccountName `
                                        -Name $name -Value $creds
    }
    else
    {
        Write-Output "Credentials already exist for $name with username $username"
    }

}

New-AutomationCredentials -name "SPfarmPassphrase" -username '.'
New-AutomationCredentials -name "SPfarmAdmin" -username "TEST\SPfarmAdmin"
New-AutomationCredentials -name "SPInstallAccount" -username "TEST\SPInstallAccount"


Start-AzureRmAutomationDscCompilationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                                                -ConfigurationName $DSCconfigurationName -ConfigurationData $ConfigData `
                                                -Parameters $Params

#Get-AzureRmAutomationDscCompilationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ConfigurationName $DSCconfigurationName
