$resourceGroupName = 'stulab'
$automationAccountName = 'stulab'
$DSCconfigurationName = 'SQLServer'

$Params = @{"domainAdminCred"="domainAdminCred";
            "storageAccount"="storageAccount";
            "sqlserviceaccount"="SQL engine service account";
            "sqlagentaccount"="SQL agent service account"}

$ConfigData = @{
    AllNodes = @(

        @{
            Nodename = "*"
            DomainName = "kewalaka.nz"
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true
            RebootIfNeeded = $true
            InstanceName    = "MSSQLSERVER"
            Features        = "SQLENGINE"
            SourcePath = "\\stulab.file.core.windows.net\media\Installers\Microsoft\SQL\2016SP1-Dev\"
            ClusterName = "S2DSQL-S2D-c" 
            ClusterIPAddress = "10.0.0.254"
            FailoverClusterNetworkName = "labsqlclus01"
            FailoverClusterIPAddress   = "10.0.0.253"
            AdminAccounts = 'TEST\sqladmins'
        },

        @{
            Nodename = "S2DSQL-S2D-0"
            Role = "PrimaryServerNode"
        },

        @{
            Nodename = "S2DSQL-S2D-1"
            Role = "ReplicaServerNode"
        }        
    )
}


if ( $AzureCred -eq $null )
{
    $username = "stuart.mace@powerco.co.nz"
    $password = read-host "Please enter password for $username" -AsSecureString
    $AzureCred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username,$password
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

New-AutomationCredentials -name "domainAdminCred" -username "TEST\stu"
New-AutomationCredentials -name "storageAccount" -username "stulab"
New-AutomationCredentials -name "SQL engine service account" -username "TEST\svc_sqlengine"
New-AutomationCredentials -name "SQL agent service account" -username "TEST\svc_sqlagent"

Start-AzureRmAutomationDscCompilationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                                                -ConfigurationName $DSCconfigurationName -ConfigurationData $ConfigData `
                                                -Parameters $Params

#Get-AzureRmAutomationDscCompilationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ConfigurationName $DSCconfigurationName
