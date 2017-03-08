Configuration kewalakaFailoverCluster
{
    param (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [pscredential]$domainAdminCred
    )

    Import-DscResource -ModuleName xComputerManagement, xFailovercluster, xActiveDirectory, xSOFS
    Import-DSCResource -ModuleName kewalakaServerConfig
    
    kewalakaBaseServerConfig basebuild
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

    WindowsFeature FS
    {
        Name = "FS-FileServer"
        Ensure = "Present"
    }
}

