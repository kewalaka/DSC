Configuration SQLServer
{
    param
    (
        [Parameter(Mandatory)]
        [pscredential]$domainAdminCred,

        [Parameter(Mandatory)]
        [pscredential]$storageAccount,

        [Parameter(Mandatory)]
        [pscredential]$sqlserviceaccount,

        [Parameter(Mandatory)]
        [pscredential]$sqlagentaccount        
    )

    Import-DscResource -ModuleName xComputerManagement, xFailovercluster, xActiveDirectory, xSOFS, xSQLServer
    Import-DSCResource -ModuleName stulabServerConfig

    Node $AllNodes.Nodename
    {

        stulabBaseServerConfig basebuild
        {
            DomainName = $Node.DomainName
            domainAdminCred = $domainAdminCred
        } 

        WindowsFeature FC
        {
            Name = "Failover-Clustering"
            Ensure = "Present"
        }

        WindowsFeature FailoverClusterTools 
        { 
            Ensure = "Present" 
            Name = "RSAT-Clustering-Mgmt"
            DependsOn = "[WindowsFeature]FC"
        } 

        WindowsFeature FCPS
        {
            Name = "RSAT-Clustering-PowerShell"
            Ensure = "Present"
        }

       WindowsFeature RSATClusteringCmdInterface
       {
           Ensure = "Present"
           Name   = "RSAT-Clustering-CmdInterface"
       }

        xSQLServerSetup "PrepareMSSQLSERVER"
        {
            DependsOn = @(
                "[WindowsFeature]NET-Framework-Core",
                "[WindowsFeature]Failover-Clustering"
            )
            Action = "PrepareFailoverCluster"
            SourcePath = $Node.SourcePath
            SourceCredential = $storageAccount
            SetupCredential = $domainAdminCred
            Features = $Node.Features
            InstanceName = $Node.InstanceName
            FailoverClusterNetworkName = $Node.FailoverClusterNetworkName
            FailoverClusterIPAddress = $Node.FailoverClusterIPAddress
            SQLSvcAccount  = $sqlserviceaccount
            AgtSvcAccount = $sqlagentaccount
        }

        xSqlServerFirewall "FirewallMSSQLSERVER"
        {
            DependsOn = "[xSQLServerFailoverClusterSetup]PrepareMSSQLSERVER"
            SourcePath = $Node.SourcePath
            InstanceName = $Node.InstanceName
            Features = $Node.Features
        }

        If ($node.Role -eq "PrimaryServerNode")
        {
            xCluster FailoverCluster
            {
                DependsOn = @(
                    "[WindowsFeature]RSATClusteringMgmt",
                    "[WindowsFeature]RSATClusteringPowerShell"
                )
                Name = $Node.ClusterName
                StaticIPAddress = $Node.ClusterIPAddress
                DomainAdministratorCredential = $Node.InstallerServiceAccount
            }

            Script CloudWitness
            {
                SetScript = "Set-ClusterQuorum -CloudWitness -AccountName $($storageAccount.GetNetworkCredential().UserName) -AccessKey $($storageAccount.GetNetworkCredential().Password)"
                TestScript = "(Get-ClusterQuorum).QuorumResource.Name -eq 'Cloud Witness'"
                GetScript = "@{Ensure = if ((Get-ClusterQuorum).QuorumResource.Name -eq 'Cloud Witness') {'Present'} else {'Absent'}}"
                DependsOn = "[xCluster]FailoverCluster"
            }

            Script IncreaseClusterTimeouts
            {
                SetScript = "(Get-Cluster).SameSubnetDelay = 2000; (Get-Cluster).SameSubnetThreshold = 15; (Get-Cluster).CrossSubnetDelay = 3000; (Get-Cluster).CrossSubnetThreshold = 15"
                TestScript = "(Get-Cluster).SameSubnetDelay -eq 2000 -and (Get-Cluster).SameSubnetThreshold -eq 15 -and (Get-Cluster).CrossSubnetDelay -eq 3000 -and (Get-Cluster).CrossSubnetThreshold -eq 15"
                GetScript = "@{Ensure = if ((Get-Cluster).SameSubnetDelay -eq 2000 -and (Get-Cluster).SameSubnetThreshold -eq 15 -and (Get-Cluster).CrossSubnetDelay -eq 3000 -and (Get-Cluster).CrossSubnetThreshold -eq 15) {'Present'} else {'Absent'}}"
                DependsOn = "[Script]CloudWitness"
            }

<#
            Script EnableS2D
            {
                SetScript = "Enable-ClusterS2D -Confirm:0; New-Volume -StoragePoolFriendlyName S2D* -FriendlyName VDisk01 -FileSystem CSVFS_REFS -UseMaximumSize"
                TestScript = "(Get-ClusterSharedVolume).State -eq 'Online'"
                GetScript = "@{Ensure = if ((Get-ClusterSharedVolume).State -eq 'Online') {'Present'} Else {'Absent'}}"
                DependsOn = "[Script]IncreaseClusterTimeouts"
            }

            xSOFS EnableSOFS
            {
                SOFSName = $SOFSName
                DomainAdministratorCredential = $DomainCreds
                DependsOn = "[Script]EnableS2D"
            }
#>            
        }
        If ($node.Role -eq "ReplicaServerNode" )
        {
            xWaitForCluster waitForCluster 
            { 
                Name = $Node.ClusterName 
                RetryIntervalSec = 10 
                RetryCount = 20
            } 
       
            xCluster joinCluster 
            { 
                Name = $Node.ClusterName 
                StaticIPAddress = $Node.ClusterIPAddress 
                DomainAdministratorCredential = $Node.InstallerServiceAccount
            
                DependsOn = "[xWaitForCluster]waitForCluster" 
            }
        }        

        If ($node.Role -eq "PrimaryServerNode")
        {
           
            WaitForAll "SqlPrep"
            {                
                NodeName = @($computers)
                ResourceName = "[xSQLServerFailoverClusterSetup]PrepareMSSQLSERVER"
                PsDscRunAsCredential = $Node.InstallerServiceAccount
                RetryIntervalSec = 5
                RetryCount = 720
            }

            xSQLServerSetup "CompleteMSSQLSERVER"
            {
                Action = "CompleteFailoverCluster"
                SourcePath = $Node.SourcePath
                SourceCredential = $storageAccount
                SetupCredential = $domainAdminCred
                Features = $Node.Features
                InstanceName = $Node.InstanceName
                FailoverClusterNetworkName = $Node.FailoverClusterNetworkName
                FailoverClusterIPAddress = $Node.FailoverClusterIPAddress
                SQLSvcAccount = $sqlserviceaccount
                AgtSvcAccount = $sqlagentaccount
                InstallSQLDataDir = "D:\"
                SQLSysAdminAccounts = $Node.AdminAccounts   
                DependsOn = @(
                    "[WaitForAll]SqlPrep"
                )                     
            }            
        } 
    <#
        Script CloudWitness
        {
            SetScript = "Set-ClusterQuorum -CloudWitness -AccountName ${witnessStorageName} -AccessKey $($witnessStorageKey.GetNetworkCredential().Password)"
            TestScript = "(Get-ClusterQuorum).QuorumResource.Name -eq 'Cloud Witness'"
            GetScript = "@{Ensure = if ((Get-ClusterQuorum).QuorumResource.Name -eq 'Cloud Witness') {'Present'} else {'Absent'}}"
            DependsOn = "[xCluster]FailoverCluster"
        }

        xFirewall Firewall-SQL-tcp1433
        {
            Name                  = ""
            Ensure                = "Present"
            Enabled               = "True"
            Profile               = ("Domain")
        }

        xFirewall Firewall-LoadBalancer-tcp59999
        {
            Name                  = ""
            Ensure                = "Present"
            Enabled               = "True"
            Profile               = ("Domain")
        }
    #>

    }       
}
