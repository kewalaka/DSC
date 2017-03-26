configuration ChocolateyServer
{
    param
    (
        [Parameter(Mandatory)]
        [pscredential]$domainAdminCred
    )

    Import-DSCResource -ModuleName cChoco
    Import-DSCResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName cNtfsAccessControl
    Import-DscResource -ModuleName kewalakaServerConfig

    $destination = "C:\inetpub\chocolatey"

    Node $AllNodes.Nodename
    {
        kewalakaBaseServerConfig basebuild
        {
            DomainName = $Node.DomainName
            domainAdminCred = $domainAdminCred
            DependsOn = "[cChocoInstaller]installChoco"            
        } 

        cChocoInstaller installChoco
        {
            InstallDir = "$env:PROGRAMDATA\chocolatey"
        } 

        WindowsFeature "Web-Server" { Name   = "Web-Server" }
        WindowsFeature "Web-Http-Errors" { Name   = "Web-Http-Errors" }
        WindowsFeature "Web-Static-Content" { Name   = "Web-Static-Content" }
        WindowsFeature "Web-Http-Logging" { Name   = "Web-Http-Logging" }
        WindowsFeature "Web-Stat-Compression" { Name   = "Web-Stat-Compression" }
        WindowsFeature "Web-Asp-Net45" { Name   = "Web-Asp-Net45" }
        WindowsFeature "Web-Mgmt-Tools" { Name   = "Web-Mgmt-Tools" }
        WindowsFeature "Web-Mgmt-Service" { Name   = "Web-Mgmt-Service" }

        # Remove the Default Web Site
        xWebSite RemoveDefaultWebSite 
        {
            Ensure          = "Absent"
            Name            = "Default Web Site"
            PhysicalPath    = "C:\inetpub\wwwroot"
            DependsOn       = '[WindowsFeature]Web-Server'
        } 

        # Create a new application pool for the application
        xWebAppPool ChocoAppPool
        {
            Ensure                  = 'Present'
            Name                    = 'ChocoAppPool'
            DependsOn               = '[WindowsFeature]Web-Server','[WindowsFeature]Web-Asp-Net45'
        }

        # Create a new website
        xWebsite ChocoWebSite 
        {
            Ensure          = 'Present'
            Name            = 'Chocolatey'
            State           = 'Started'
            PhysicalPath    = $destination 
            DependsOn       = '[File]WebContent'
            PreloadEnabled  = $true
            ServiceAutoStartEnabled = $true
        }

        cChocoPackageInstaller chocolateyserver
        {            
            Name                    = "chocolatey.server" 
            DependsOn               = '[WindowsFeature]Web-Server','[WindowsFeature]Web-Asp-Net45'
        }

        File WebContent
        {
            Ensure                  = 'Present'
            SourcePath              = 'C:\tools\chocolatey.server'
            DestinationPath         = $destination
            Recurse                 = $true
            Type                    = 'Directory'
            DependsOn               = '[cChocoPackageInstaller]chocolateyserver'
        }

        cNtfsPermissionEntry WebsiteACL
        {
            Ensure = 'Present'
            Path = "$destination"
            Principal = 'BUILTIN\IIS_IUSRS'
            AccessControlInformation = @(
                cNtfsAccessControlInformation
                {
                    AccessControlType = 'Allow'
                    FileSystemRights = 'ReadAndExecute'
                    Inheritance = 'ThisFolderSubfoldersAndFiles'
                    NoPropagateInherit = $false
                }
            )
            DependsOn = '[File]WebContent'
        }

        cNtfsPermissionEntry ModifyACLforPackages
        {
            Ensure = 'Present'
            Path = "$destination\App_Data\Packages"
            Principal = 'BUILTIN\IIS_IUSRS'
            AccessControlInformation = @(
                cNtfsAccessControlInformation
                {
                    AccessControlType = 'Allow'
                    FileSystemRights = 'Modify'
                    Inheritance = 'ThisFolderSubfoldersAndFiles'
                    NoPropagateInherit = $false
                }
            )
            DependsOn = '[File]WebContent'
        }
    }

}