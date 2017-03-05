# A configuration to Create High Availability Domain Controller
Configuration ADcontroller
{

   param
    (
        [Parameter(Mandatory)]
        [pscredential]$safemodeAdminCred,

        [Parameter(Mandatory)]
        [pscredential]$domainAdminCred
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration,xActiveDirectory,xPendingReboot,xDnsServer

    Node $AllNodes.Nodename
    {
        LocalConfigurationManager 
        { 
             CertificateId = $Node.Thumbprint 
             RebootNodeIfNeeded = $Node.RebootIfNeeded
        } 

        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
        }

        WindowsFeature ADDSToolsInstall {
            Ensure = 'Present'
            Name = 'RSAT-ADDS-Tools'
        }

        xPendingReboot AfterADDSToolsinstall
        {
            Name = 'AfterADDSinstall'
            DependsOn = "[WindowsFeature]ADDSToolsInstall"
        }        
    }

    Node $AllNodes.Where{$_.Role -eq "First DC"}.Nodename
    {  
        xADDomain FirstDS
        {
            DomainName = $Node.DomainName
            DomainNetBIOSName = $Node.DomainNetBIOSName
            DomainAdministratorCredential = $domainAdminCred
            SafemodeAdministratorPassword = $safemodeAdminCred
            DependsOn = "[xPendingReboot]AfterADDSToolsinstall"
        }

        xWaitForADDomain DscForestWait
        {
            DomainName = $Node.DomainName
            DomainUserCredential = $domainAdminCred
            RetryCount = $Node.RetryCount
            RetryIntervalSec = $Node.RetryIntervalSec
            DependsOn = "[xADDomain]FirstDS"
        }

        xPendingReboot AfterADDSinstall
        {
            Name = 'AfterADDSinstall'
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }
    }

    Node $AllNodes.Where{$_.Role -eq "Additional DC"}.Nodename
    {
        xWaitForADDomain DscForestWait
        {
            DomainName = $Node.DomainName
            DomainUserCredential = $domainAdminCred
            RetryCount = $Node.RetryCount
            RetryIntervalSec = $Node.RetryIntervalSec
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        xADDomainController SecondDC
        {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $domainAdminCred
            SafemodeAdministratorPassword = $safemodeAdminCred
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        xPendingReboot AfterADDSinstall
        {
            Name = 'AfterADDSinstall'
            DependsOn = "[xADDomainController]SecondDC"
        }
    }

    Node $AllNodes.Nodename
    {
        xDnsServerForwarder SetForwarders
        {
            IsSingleInstance = 'Yes'
            IPAddresses = '8.8.8.8','8.8.4.4'
            DependsOn = "[xPendingReboot]AfterADDSinstall"
        }
    }
}
