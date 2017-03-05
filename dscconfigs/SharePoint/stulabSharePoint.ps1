Configuration SharePointServer
{
   param
    (
        [Parameter(Mandatory)]
        [pscredential]$SPfarmPassphrase,

        [Parameter(Mandatory)]
        [pscredential]$SPfarmAdmin,

        [Parameter(Mandatory)]
        [pscredential]$SPInstallAccount,

        [Parameter(Mandatory)]
        [pscredential]$domainAdminCred

    )

    Import-DscResource -ModuleName SharePointDSC
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName xCredSSP
    Import-DscResource -ModuleName xActiveDirectory

    node $AllNodes.Nodename
    {

        xCredSSP CredSSPServer { Ensure = "Present"; Role = "Server" }
        xCredSSP CredSSPClient { Ensure = "Present"; Role = "Client"; DelegateComputers = $Node.CredSSPDelegates }

        #region: Binary installation
        <# This section triggers installation of both SharePoint
        # as well as the prerequisites required #>

        $SPBinaryPath = $Node.SPBinaryPath
        $PreReqFolder = "$SPBinaryPath\prerequisiteinstallerfiles" 
        #**********************************************************
        # Binary installation
        #
        # This section triggers installation of both SharePoint
        # as well as the prerequisites required
        #**********************************************************
        SPInstallPrereqs InstallPrerequisites
        {
            InstallerPath = "$SPBinaryPath\Prerequisiteinstaller.exe"
            OnlineMode = $false
            SQLNCli = "$PreReqFolder\sqlncli.msi"
            DotNetFx = "$PreReqFolder\NDP46-KB3045557-x86-x64-AllOS-ENU.exe"
            IDFX = "$PreReqFolder\Windows6.1-KB974405-x64.msu"
            Sync = "$PreReqFolder\Synchronization.msi"
            AppFabric = "$PreReqFolder\WindowsServerAppFabricSetup_x64.exe"
            IDFX11 = "$PreReqFolder\MicrosoftIdentityExtensions-64.msi"
            MSIPCClient = "$PreReqFolder\setup_msipc_x64.exe"
            WCFDataServices = "$PreReqFolder\WcfDataServices.exe"
            KB3092423 = "$PreReqFolder\AppFabric-KB3092423-x64-ENU.exe"
            WCFDataServices56 = "$PreReqFolder\WcfDataServices56.exe"
            msvcrt11 = "$PreReqFolder\vc_redist.x64.exe"
            msvcrt14 = "$PreReqFolder\vcredist_x64.exe"
            ODBC = "$PreReqFolder\msodbcsql.msi"
            Ensure = "Present"
        }

        SPInstall InstallBinaries
        {
            BinaryDir = "$SPBinaryPath"
            ProductKey = $Node.ProductKey
            Ensure = "Present"
            DependsOn = "[SPInstallPrereqs]InstallPrerequisites"
        }
        #endregion

        #region: IIS clean up
        <# This section removes all default sites and application
           pools from IIS as they are not required #>
        xWebAppPool RemoveDotNet2Pool { Name = ".NET v2.0"; Ensure = "Absent"; DependsOn = "[SPInstallPrereqs]InstallPrerequisites" }
        xWebAppPool RemoveDotNet2ClassicPool { Name = ".NET v2.0 Classic"; Ensure = "Absent"; DependsOn = "[SPInstallPrereqs]InstallPrerequisites" }
        xWebAppPool RemoveDotNet45Pool { Name = ".NET v4.5"; Ensure = "Absent"; DependsOn = "[SPInstallPrereqs]InstallPrerequisites"; }
        xWebAppPool RemoveDotNet45ClassicPool { Name = ".NET v4.5 Classic"; Ensure = "Absent"; DependsOn = "[SPInstallPrereqs]InstallPrerequisites"; }
        xWebAppPool RemoveClassicDotNetPool { Name = "Classic .NET AppPool"; Ensure = "Absent"; DependsOn = "[SPInstallPrereqs]InstallPrerequisites" }
        xWebAppPool RemoveDefaultAppPool { Name = "DefaultAppPool"; Ensure = "Absent"; DependsOn = "[SPInstallPrereqs]InstallPrerequisites" }
        xWebSite    RemoveDefaultWebSite { Name = "Default Web Site"; Ensure = "Absent"; PhysicalPath = "C:\inetpub\wwwroot"; DependsOn = "[SPInstallPrereqs]InstallPrerequisites" }
        #endregion


    }

    #region: Create or Join farm

    Node $AllNodes.Where{$_.FirstServer}.Nodename
    {
        SPCreateFarm CreateSPFarm
        {
            DatabaseServer = $Node.ConfigDatabaseServer
            FarmConfigDatabaseName = "SP_Config"
            Passphrase = $SPfarmPassphrase
            FarmAccount = $SPfarmAdmin
            PsDscRunAsCredential = $SPInstallAccount
            AdminContentDatabaseName = "SP_AdminContent"
            DependsOn = ("[SPInstall]InstallBinaries")
            #DependsOn = ("[SPInstall]InstallBinaries","[xADUser]FarmAdminAccount","[xADUser]InstallAccount")
            ServerRole = 'WebFrontEndWithDistributedCache'
            CentralAdministrationPort = '4444'
        }
    }

    Node $AllNodes.Where{$_.FirstServer -eq $null -and $_.Role -eq "ApplicationandSearch"}.Nodename
    {
        SPJoinFarm JoinSPFarm 
        {
            FarmConfigDatabaseName = "SP_Config"
            DatabaseServer = $Node.ConfigDatabaseServer
            Passphrase = $SPfarmPassphrase
            ServerRole = 'ApplicationWithSearch'
            PsDscRunAsCredential = $SPInstallAccount
            DependsOn = ("[SPInstall]InstallBinaries")
            #DependsOn = ("[SPInstall]InstallBinaries","[xADUser]FarmAdminAccount","[xADUser]InstallAccount")
        }
    }

    #endregion
}