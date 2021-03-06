$win10ip="192.168.2.217"
$serverip="192.168.2.38"
New-NetFirewallRule -DisplayName "RemoteIN" -Action Allow -Direction Inbound -RemoteAddress $win10ip -LocalAddress $serverip
New-NetFirewallRule -DisplayName "hostmachineIn" -Action Allow -Direction Inbound -RemoteAddress 192.168.2.254 -LocalAddress $serverip
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
$SecurePassword  = convertto-securestring "Nincs12345" -asplaintext -force
Install-ADDSForest -DomainName "sqlcourse.local" -SafeModeAdministratorPassword $SecurePassword -force
