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

    Import-DscResource -ModuleName PSDesiredStateConfiguration,xActiveDirectory,xPendingReboot,xDnsServer,xDhcpServer,xNetworking

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

    Node $AllNodes.Where{$_.IPAddress}.Nodename
    {
        $AddressFamily = 'IPv4'
        $InterfaceAlias = 'Ethernet'

        xDhcpClient DisabledDhcpClient
        {
            State          = 'Disabled'
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = $AddressFamily
        }

        xIPAddress NewIPAddress
        {
            IPAddress      = $Node.IPAddress
            InterfaceAlias = $InterfaceAlias          
            PrefixLength   = $Node.PrefixLength
            AddressFamily  = $AddressFamily
        }    

        xDefaultGatewayAddress SetDefaultGateway
        {
            Address        = $Node.Gateway
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = $AddressFamily
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

    Node $AllNodes.Where{$_.DHCPScopes}.Nodename
    {

        WindowsFeature DHCP
        {
            Ensure = "Present"
            Name = "DHCP"
        }

        xDhcpServerAuthorization "LocalServerActivation"
        {
            Ensure = 'Present'
            DependsOn = @('[WindowsFeature]DHCP') 
        }

        ForEach ($DHCPScope in $Node.DHCPScopes) {

            xDhcpServerScope "$DHCPScope-Scope"
            {
                Ensure = 'Present'
                IPEndRange = $DHCPScope.IPEndRange
                IPStartRange = $DHCPScope.IPStartRange 
                Name = $DHCPScope.Name
                SubnetMask = $DHCPScope.SubnetMask
                State = 'Active'
                AddressFamily = 'IPv4'
                DependsOn = @('[WindowsFeature]DHCP') 
            }

            xDhcpServerOption "$DHCPScope-Option"
            {
                Ensure = 'Present'
                ScopeID = $DHCPScope.ScopeID
                DnsDomain = $Node.DomainName
                DnsServerIPAddress = $DHCPScope.DNSServer
                AddressFamily = 'IPv4'
                Router = $DHCPScope.Router
                DependsOn = @('[WindowsFeature]DHCP') 
            }

        }
    }
}
