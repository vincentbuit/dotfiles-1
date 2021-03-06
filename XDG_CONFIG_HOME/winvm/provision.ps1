#!/usr/bin/env pwsh
if (!($env:ComputerName -eq "$HOSTNAME")) {
    Rename-Computer -NewName "$HOSTNAME"
}
#Enable RDP
Set-Itemproperty `
    -Path 'HKLM:/System/CurrentControlSet/Control/Terminal Server' `
    -Name 'fDenyTSConnections' -Type 'DWord' -Value 0 -Force
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
(Get-WmiObject -class Win32_TSGeneralSetting `
    -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'" `
    ).SetUserAuthenticationRequired(0)

#Enable SSH
Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0"
Set-Service -Name sshd -StartupType Automatic
Start-Service -Name sshd
New-NetFirewallRule -DisplayName 'SSH Inbound' `
    -Profile @('Domain', 'Private', 'Public') -Direction Inbound `
    -Action Allow -Protocol TCP -LocalPort @('22')
New-Item -ItemType Directory -Force -Path .ssh
'$PUBKEY' | Out-File -Encoding utf8 -Append `
    $env:ProgramData/ssh/administrators_authorized_keys
icacls $env:ProgramData\ssh\administrators_authorized_keys `
    /inheritance:r /grant "SYSTEM:(F)" /grant "BUILTIN\Administrators:(F)"

#Route IIS Express
netsh interface portproxy add v4tov6 listenport=8079 connectaddress=[::1] `
    connectport=8080
New-NetFirewallRule -DisplayName 'HTTP Inbound' `
    -Profile @('Domain', 'Private', 'Public') -Direction Inbound `
    -Action Allow -Protocol TCP -LocalPort @('8079')

#Install chocolatey
if ((Get-Command "choco.exe" -ErrorAction SilentlyContinue) -eq $null) {
    iex ((New-Object System.Net.WebClient).DownloadString(`
        'https://chocolatey.org/install.ps1'))
}

#Enable and provision WSL
$reboot = (Enable-WindowsOptionalFeature -NoRestart -Online `
    -FeatureName Microsoft-Windows-Subsystem-Linux).RestartNeeded
if ($reboot) {
    echo "Reboot & Provision again to continue WSL installation"
} else {
    choco install -y --no-progress git vswhere visualstudio2019community `
        dotnetcore-sdk nodejs vscode

    echo "Installing wsl"
    #Download and install Alpine
    if (!(Test-Path "$ENV:APPDATA/Alpine/Alpine.exe")) {
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
        (new-object System.Net.WebClient).DownloadFile(
            'https://github.com/yuk7/AlpineWSL/releases/download/3.10.3-0/' +
            'Alpine.zip', "$HOME/Downloads/Alpine.zip")
        Expand-Archive "$HOME/Downloads/Alpine.zip" "$ENV:APPDATA/Alpine"
        $sc = (New-Object -ComObject ("WScript.Shell")).CreateShortcut(
            "$ENV:USERPROFILE/Desktop/Alpine.lnk")
        $sc.TargetPath = "$ENV:APPDATA/Alpine/Alpine.exe"
        $sc.IconLocation = "$ENV:APPDATA/Alpine/Alpine.exe, 0"
        $sc.Save()
    }

    "`nexit`n" | & "$ENV:APPDATA/Alpine/Alpine.exe"

    wsl.exe -- sh -c "
        apk update
        apk add openssh
        ssh-keygen -A
        printf 'root\nroot\n' | passwd
        printf '\nPermitRootLogin yes' >>/etc/ssh/sshd_config
        mkdir -p /root/.ssh; chmod 700 /root/.ssh
        echo '$ROOTPUBKEY' >/root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        pkill sshd ||:; /usr/sbin/sshd -p 23
        printf '[automount]\nenabled=true\noptions=metadata\n' >/etc/wsl.conf
        cd / && umount /mnt/c && mount -t drvfs C: /mnt/c -o metadata
        #Temporary installation method for vsvim
        cd /mnt/c/Users/vagrant
        apk add git
        [ -d choco-vsvim ] || git clone https://github.com/milhnl/choco-vsvim
        cd choco-vsvim
        choco.exe install -y vsvim.nuspec
    "

    Register-ScheduledTask -Force -TaskName "WSL SSHD" `
        -Action (New-ScheduledTaskAction -Execute "wsl.exe" `
            -Argument 'wsl.exe -- sh -c "/usr/sbin/sshd -p 23"') `
        -Trigger (New-ScheduledTaskTrigger -AtStartup) `
        -Principal (New-ScheduledTaskPrincipal -UserId (whoami) `
            -LogonType S4U -RunLevel Highest)

    #This allows interacting with the active Windows GUI session
    "wsl.exe -- sh -c ""pkill /usr/sbin/sshd; /usr/sbin/sshd -p 23""" `
        | Out-File $([Environment]::GetFolderPath("Startup") `
            + "\WSL SSHD.bat") -Encoding ascii

    netsh interface portproxy add v4tov6 listenport=24 connectaddress=[::1] `
        connectport=23
    New-NetFirewallRule -DisplayName 'WSL SSH Inbound' `
        -Profile @('Domain', 'Private', 'Public') -Direction Inbound `
        -Action Allow -Protocol TCP -LocalPort @('24')
}

