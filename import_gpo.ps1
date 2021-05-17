$Root = [ADSI]"LDAP://RootDSE"
$Domain = $Root.Get("rootDomainNamingContext")
    
$GPOName = 'Windows Event Forwarding Server'
Import-GPO -BackupGpoName $GPOName -Path "GPO\wef_configuration" -TargetName $GPOName -CreateIfNeeded
    
$GPOName = 'Domain Controllers Enhanced Auditing Policy'
Import-GPO -BackupGpoName $GPOName -Path "GPO\Domain_Controllers_Enhanced_Auditing_Policy" -TargetName $GPOName -CreateIfNeeded
    
$GPOName = 'Servers Enhanced Auditing Policy'
Import-GPO -BackupGpoName $GPOName -Path "GPO\Servers_Enhanced_Auditing_Policy" -TargetName $GPOName -CreateIfNeeded
    
$GPOName = 'Powershell Logging'
Import-GPO -BackupGpoName $GPOName -Path "GPO\powershell_logging" -TargetName $GPOName -CreateIfNeeded
    
$GPOName = 'Workstations Enhanced Auditing Policy'
Import-GPO -BackupGpoName $GPOName -Path "GPO\Workstations_Enhanced_Auditing_Policy" -TargetName $GPOName -CreateIfNeeded
