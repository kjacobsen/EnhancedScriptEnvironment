function initialise-scriptnotif
{
[CMDLetBinding()]
Param 
(
	[String] $ConfigurationFile = 'C:\Users\JACOBSEK\Desktop\ScriptNotifier\Configuration.ini'
)



$global:hostname = hostname
$global:scriptname = $myInvocation.myCommand.name

Write-Verbose "Script is $scriptname on $hostname"

Write-Verbose "Reading INI File"

$inifile = Get-IniContent $ConfigurationFile


#
# Update System Path to include script location
#
if ($inifile.Configuration.PathUpdate -ne $null)
{
	$ENV:PATH = $ENV:PATH + ";" + $inifile.Configuration.PathUpdate
	Write-Verbose "PATH is $($ENV:PATH)"
}

#
# Load notification modules
#
$Notificationsmodules = $inifile.Notifications.getEnumerator()
foreach ($module in $Notificationsmodules)
{
	if (($module.value -ne "") -and ($module.value -ne $null))
	{
		Write-Verbose "Importing $($module.value)"
		Import-Module $module.value -Global
	}
}

#Import-Module $inifile.'Notifications'.SMSModule -Global
#Import-Module $inifile.'Notifications'.CawtoModule -Global
#Import-Module $inifile.'Notifications'.PushOverModule -Global

#
# Load component modules
#
$componentmodules = $inifile.Components.getEnumerator()
foreach ($module in $componentmodules)
{
	if (($module.value -ne "") -and ($module.value -ne $null))
	{
		Import-Module $module.value -Global
	}
}

#Import-Module $inifile.'Components'.WebFunctionsModule -Global
#Import-Module $inifile.'Components'.GPGFunctionsModule -Global
#Import-Module $inifile.'Components'.SSHFunctionsModule -Global
#Import-Module $inifile.'Components'.xcommodule -Global
#Import-Module $inifile.'Components'.PowerShellUtilitiesModule -global


#
# Load proxy server details if required
#
if ($inifile.'Configuration\web'.useproxyserver -eq 1)
{
	$webproxyurl = $inifile.'Configuration\web'.ProxyAddress
	$webproxyuser = $inifile.'Configuration\web'.Username
	$webproxypass = $inifile.'Configuration\web'.Password
	$webproxyuserdomain = $inifile.'Configuration\web'.domain
	
	Write-Verbose "Using Proxy Server $webproxyurl"
	
	$webcreds = New-Object system.net.networkcredential($webproxyuser, $webproxypass, $webproxyuserdomain)
	$global:webproxy = New-Object system.net.webproxy ($webproxyurl, $true, @(), $webcreds)
}

$global:smtpenabled = $inifile.'Notifications\SMTP'.Enabled -eq 1
if ($smtpenabled)
{
	$global:smtpserver = $inifile.'Notifications\SMTP'.server
	$global:smtpto = $inifile.'Notifications\SMTP'.to
	$global:smtpfrom = $inifile.'Notifications\SMTP'.from
	$global:smtpthreshold = $inifile.'Notifications\SMTP'.threshold
}

$global:smsemabled=$inifile.'Notifications\SMS'.Enabled -eq 1
if ($smsemabled)
{
	$global:SMSUser = $inifile.'Notifications\SMS'.SMSUser
	$global:SMSPwd = $inifile.'Notifications\SMS'.SMSPwd
	$global:SMSMobile = $inifile.'Notifications\SMS'.SMSMobile
	$global:SMSThreshold = $inifile.'Notifications\SMS'.Threshold
}

$global:PushOverEnabled = $inifile.'Notifications\PushOver'.Enabled -eq 1
if ($PushOverEnabled)
{
	$global:PushoverApi = $inifile.'Notifications\PushOver'.PushOverApiToken
	$global:PushoverUser = $inifile.'Notifications\PushOver'.PushOverUser
	$global:PushoverThreshold = $inifile.'Notifications\PushOver'.Threshold
}

$global:log4netEnabled = $inifile.'Notifications\log4net'.Enabled -eq 1
if ($log4netEnabled)
{
	$global:log4netdll = $inifile.'Notifications\log4net'.dllpath
	$global:log4netconfig = $inifile.'Notifications\log4net'.configuration
}

$global:cawtoenabled = $inifile.'Notifications\cawto'.Enabled -eq 1
if ($cawtoenabled)
{
	$global:tngnode = $inifile.'Notifications\cawto'.node
}

$global:syslogenabled = $inifile.'Notifications\syslog'.enabled -eq 1
if ($syslogenabled)
{
	$global:syslogserver = $inifile.'Notifications\syslog'.server
	$global:syslogport = $inifile.'Notifications\syslog'.port
	$global:syslogfacility=$inifile.'Notifications\syslog'.facility
	$global:syslogthreshold = $inifile.'Notifications\syslog'.threshold
}

$global:wineventenabled = $inifile.'Notifications\EventLog'.enabled -eq 1
if ($wineventenabled)
{
	$global:wineventlogname=$inifile.'Notifications\EventLog'.logname
	$global:wineventsourcename=$inifile.'Notifications\EventLog'.sourcename
}

}
