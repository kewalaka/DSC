# load in the configuration document
. $env:srcroot\AzureAutomation\dscconfigs\AD\kewalakaADcontroller.ps1

# environment specific settings
$ConfigData =  @{
    AllNodes = @(

        @{
            Nodename = "*"
            DomainName = "kewalaka.nz"
            DomainNetBIOSName = "test"
            CertificateFile = "C:\Admin\Dsc\DscPublicKey.cer"
            Thumbprint = "8AD8E3731EE4B1D4C3408E491855FFE8A13CEEDB"
            RetryCount = 20
            RetryIntervalSec = 30
            PSDscAllowDomainUser = $true
            RebootIfNeeded = $true
        },

        @{
            Nodename = "labdc01"
            Role = "First DC"
            DHCPScopes = @(            
                @{ 
                    Name         = 'Lab'
                    ScopeID      = '10.66.66.0'
                    IPStartRange = '10.66.66.10'
                    IPEndRange   = '10.66.66.250'
                    SubnetMask   = '255.255.255.0'
                    Router       = '10.66.66.1'
                    DNSServer    = @('10.66.66.5')                    
                }
            )
        },

        @{
            Nodename = "labdc02"
            Role = "Additional DC"
        }
    )
}

$DSCFolder = "C:\Admin\DSC"

# Generate MOF
New-Item -ItemType Directory -Path $DSCFolder -ErrorAction SilentlyContinue

if ($Cred -eq $null)
{
    $Cred = (Get-Credential -Message "New Domain Admin Credentials" -UserName "Administrator")
}

ADcontroller -OutputPath $DSCFolder -ConfigurationData $ConfigData `
-safemodeAdministratorCred $Cred `
-domainCred $Cred `
-NewADUserCred $Cred

# set up the LCM to use the certificate
# Set-DscLocalConfigurationManager -ComputerName $env:COMPUTERNAME -Path $DSCFolder -Verbose

#$DSCFolder = "C:\Admin\DSC"
#$x = Test-DscConfiguration -ComputerName $env:COMPUTERNAME -Path $DSCFolder -Verbose
#Start-DSCConfiguration -ComputerName $env:COMPUTERNAME -Path $DSCFolder -Force -Verbose -Wait
# 