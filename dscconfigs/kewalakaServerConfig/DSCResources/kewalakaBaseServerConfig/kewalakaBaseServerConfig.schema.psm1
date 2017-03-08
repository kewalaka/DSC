Configuration kewalakaBaseServerConfig
{
    param (
        [string[]]$DNSServers = @("10.0.0.7", "10.0.0.8"),

        [string]$DomainName = $null,

        [pscredential]$domainAdminCred
    )

    Import-DSCResource -ModuleName xPowerShellExecutionPolicy,xDSCFirewall,xNetworking,xDSCDomainjoin,xActiveDirectory,xPendingReboot
    
    xPowerShellExecutionPolicy ExecutionPolicy
    {
        ExecutionPolicy   = "RemoteSigned"
    }

    Service WindowsFirewall
    {
        Name = "MPSSvc"
        StartupType = "Automatic"
        State = "Running"
    }

    if ($DomainName)
    {
        xDSCFirewall EnabledDomain
        {
            Ensure = "Present"
            Zone = ("Domain")
            LogAllowed = "False"
            LogIgnored = "False"
            LogBlocked = "True"
            LogMaxSizeKilobytes = "4096"
            DefaultInboundAction = "Block"
            DefaultOutboundAction = "Allow"
            Dependson = "[Service]WindowsFirewall"
        }

        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        }

        xWaitForADDomain DscForestWait 
        { 
            DomainName = $DomainName
            DomainUserCredential= $domainAdminCred
            RetryCount = 20
            RetryIntervalSec = 30
            DependsOn = "[WindowsFeature]ADPS"
        }

        xDSCDomainjoin DomainJoin
        {
            Domain     = $DomainName
            Credential = $domainAdminCred
            DependsOn  = "[xWaitForADDomain]DscForestWait"
        }

        xPendingReboot RebootAfterDomainJoin
        {
            Name      = "RebootAfterDomainJoin"
            DependsOn = "[xDSCDomainjoin]DomainJoin"
        }


    }
    else {

        xDSCFirewall EnabledPrivate
        {
            Ensure = "Present"
            Zone = ("Private")
            LogAllowed = "False"
            LogIgnored = "False"
            LogBlocked = "True"
            LogMaxSizeKilobytes = "4096"
            DefaultInboundAction = "Block"
            DefaultOutboundAction = "Allow"
            Dependson = "[Service]WindowsFirewall"
        }      

    }
    xFirewall Firewall-WinRM
    {
        Name                  = "Windows Remote Management (HTTP-In)"
        Ensure                = "Present"
        Enabled               = "True"
        Profile               = ("Domain", "Private")
    }

}

