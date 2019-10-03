#!/usr/bin/env pwsh
Rename-Computer -NewName "winvm"
#Enable RDP
Set-Itemproperty `
    -Path 'HKLM:/System/CurrentControlSet/Control/Terminal Server' `
    -Name 'fDenyTSConnections' -Type 'DWord' -Value 0 -Force
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
(Get-WmiObject -class Win32_TSGeneralSetting `
    -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'" `
    ).SetUserAuthenticationRequired(0)

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

#Download and install Alpine
if (!(Test-Path "$ENV:APPDATA/Alpine/Alpine.exe")) {
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    (new-object System.Net.WebClient).DownloadFile(
        'https://github.com/yuk7/AlpineWSL/releases/download/18030400/' +
        'Alpine.zip', "$HOME/Downloads/Alpine.zip")
    Expand-Archive "$HOME/Downloads/Alpine.zip" "$ENV:APPDATA/Alpine"
    $sc = (New-Object -ComObject ("WScript.Shell")).CreateShortcut(
        "$ENV:USERPROFILE/Desktop/Alpine.lnk")
    $sc.TargetPath = "$ENV:APPDATA/Alpine/Alpine.exe"
    $sc.IconLocation = "$ENV:APPDATA/Alpine/Alpine.exe, 0"
    $sc.Save()
}

#Enable and provision WSL
$reboot = (Enable-WindowsOptionalFeature -NoRestart -Online `
    -FeatureName Microsoft-Windows-Subsystem-Linux).RestartNeeded
if ($reboot) {
    echo "Provision again to continue WSL installation"
    Restart-Computer -Force
} else {
    "`nexit`n" | & "$ENV:APPDATA/Alpine/Alpine.exe"
    wsl.exe -- sh -c "
        apk update
        apk add openssh
        yes n | ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
        yes n | ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N ''
        yes n | ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ''
        yes n | ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
        printf "PermitRootLogin yes" >>/etc/ssh/sshd_config
        printf "root\nroot\n" | passwd
        /usr/sbin/sshd -p 23
    "

    Register-ScheduledTask -Force -TaskName "WSL SSHD" `
        -Action (New-ScheduledTaskAction -Execute "wsl.exe" `
            -Argument 'wsl.exe -- sh -c "/usr/sbin/sshd -p 23"') `
        -Trigger (New-ScheduledTaskTrigger -AtStartup) `
        -Principal (New-ScheduledTaskPrincipal -UserId (whoami) `
            -LogonType S4U -RunLevel Highest)

    netsh interface portproxy add v4tov6 listenport=24 connectaddress=[::1] `
        connectport=23
    New-NetFirewallRule -DisplayName 'SSH Inbound' `
        -Profile @('Domain', 'Private', 'Public') -Direction Inbound `
        -Action Allow -Protocol TCP -LocalPort @('24')

    choco install -y git vswhere
}
