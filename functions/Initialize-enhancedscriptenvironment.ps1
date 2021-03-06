function Initialize-enhancedscriptenvironment
{
<# 
.SYNOPSIS
Initialize-enhancedscriptenvironment reads the configuration file (either specified or found in some usual locations) 
and sets up global variables for the send-scriptnotificaiton cmdlet to use.

.DESCRIPTION
Initialize-enhancedscriptenvironment  is responsible to reading in a configuration to be used by the send-scriptnotification cmdlet. 

This cmdlet will read the configuration file, either specified or found in one of the listed locations:
	1. Environment Variable EnhancedScriptEnvironment
	2. Look for configuration.ini in current folder (where we have "cd"-ed into)
	3. Look for configuration.ini in an etc folder in current folder (where we have "cd"-ed into)
	4. Look for configuration.ini in the scripts folder
	5. Look for configuration.ini in an etc folder in the scripts folder
	6. Look for configuration.ini in windows folder

The configuration file will include other PowerSell modules to load, settings about smtp, sms and other notifications and could also include any other settings as required.

.PARAMETER ConfigurationFile

.INPUTS
Nothing can be piped directly into this function

.EXAMPLE
Initialize-enhancedscriptenvironment
Loads settings from a configuration.ini specified in one of the known locations

.EXAMPLE
Initialize-enhancedscriptenvironment c:\myconfig.ini
Loads the settings from the file myconfig.ini in the c:\ drive.

.OUTPUTS
Nothing usabel is returned by this function

.NOTES
NAME: initialize-enhancedscriptenvironment
AUTHOR: Kieran Jacobsen
LASTEDIT: 2014 03 10
KEYWORDS:

.LINK https://github.com/kjacobsen/EnhancedScriptEnvironment

#>

[CMDLetBinding()]
Param 
(
	[String] $ConfigurationFile,
	[Switch] $Force
)

if (($ConfigurationFile -eq "") -or ($ConfigurationFile -eq $null))
{
	if (($ENV:EnhancedScriptEnvironment -ne "") -and ($ENV:EnhancedScriptEnvironment -ne $null))
	{
		#use the environment variable
		if (Test-Path $ENV:EnhancedScriptEnvironment)
		{
			$ConfigurationFile = $ENV:EnhancedScriptEnvironment
		}
		else
		{
			throw "Invalid path specified in environment variable EnhancedScriptEnvironment, path was $($ENV:EnhancedScriptEnvironment)"
		}
	}
	elseif (Test-Path ".\Configuration.ini")
	{
		$ConfigurationFile = ".\Configuration.ini"
        Write-Verbose "Config file found at $ConfigurationFile"
	}
	elseif (Test-Path ".\etc\Configuration.ini")
	{
		$ConfigurationFile = ".\etc\Configuration.ini"
        Write-Verbose "Config file found at $ConfigurationFile"
	}
	elseif (Test-Path (Join-Path $ENV:systemRoot "Configuration.ini"))
	{
		$ConfigurationFile = (Join-Path $ENV:systemRoot "Configuration.ini")
        Write-Verbose "Config file found at $ConfigurationFile"
	}
	else
	{
	    $CallStack = Get-PSCallStack
	    foreach ($CallStackEntry in $CallStack)
	    {
	        if (($CallStackEntry.ScriptName -ne $null) -and ($CallStackEntry.ScriptName -ne ''))
	        {
	            $ScriptParentPath = Split-Path ($CallStackEntry.ScriptName) -parent
	            Write-Verbose "trying: $ScriptParentPath"
    	        if (Test-Path (Join-Path $ScriptParentPath '\Configuration.ini'))
            	{
            		$ConfigurationFile = (Join-Path $ScriptParentPath '\Configuration.ini')
                    Write-Verbose "Config file found at $ConfigurationFile"
                    break
            	}
            	elseif (Test-Path (Join-Path $ScriptParentPath '\etc\Configuration.ini'))
            	{
            		$ConfigurationFile = (Join-Path $ScriptParentPath '\etc\Configuration.ini')
                    Write-Verbose "Config file found at $ConfigurationFile"
                    break
            	}
	        }
	    }	    
    } 

	
	if (-not (Test-Path $ConfigurationFile))
	{
		throw "No configuration INI file specified in Initialize-enhancedscriptenvironment, no system environment variable, and I couldn't find one anywhere else!"
	}
	
}

#note down what config file we are using
Write-Verbose "Using Configuration file: $ConfigurationFile"
$global:LoadedConfigurationFile = $ConfigurationFile


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
# Update enhanced script environment temp folder
#
if ($inifile.Configuration.TempPath -ne $null)
{
	$Global:EnhancedTemp = $inifile.Configuration.TempPath
	if ((Test-Path $EnhancedTemp) -eq $false)
	{
		throw "Invalid temporary folder specified"
	}
}

#
# Load proxy server details if required as specified in web configuration section
#
if ($inifile.'Components\WebFunctions'.useproxyserver -eq 1)
{
	$webproxyurl = $inifile.'Components\WebFunctions'.ProxyAddress
	$webproxyuser = $inifile.'Components\WebFunctions'.Username
	$webproxypass = $inifile.'Components\WebFunctions'.Password
	$webproxyuserdomain = $inifile.'Components\WebFunctions'.domain
	
	Write-Verbose "Using Proxy Server $webproxyurl"
	
	$webcreds = New-Object system.net.networkcredential($webproxyuser, $webproxypass, $webproxyuserdomain)
	$global:webproxy = New-Object system.net.webproxy ($webproxyurl, $true, @(), $webcreds)
}

#
# Do we want to write to PowerShell console host
#
$global:WriteHostEnabled = $inifile.'Notifications\Host'.Enabled -eq 1
if ($WriteHostEnabled)
{
	$global:WriteHostThreshold = $inifile.'Notifications\Host'.threshold
}

#
# Read in SMTP details
#
$global:smtpenabled = $inifile.'Notifications\SMTP'.Enabled -eq 1
if ($smtpenabled)
{
	$global:smtpserver = $inifile.'Notifications\SMTP'.server
	$global:smtpto = $inifile.'Notifications\SMTP'.to.split(",")
	$global:smtpfrom = $inifile.'Notifications\SMTP'.from
	$global:smtpcontact = $inifile.'Notifications\SMTP'.contact
	$global:smtpthreshold = $inifile.'Notifications\SMTP'.threshold
	$global:smtptls = ($inifile.'Notifications\SMTP'.tls -eq "1")
	$global:smtpthrottle = $inifile.'Notifications\SMTP'.Throttle
	$global:smtpport = $inifile.'Notifications\SMTP'.port
	
	
    if ($PSVersionTable.PSVersion.Major -ge 3)
    {

	    $global:SMTPParameters = @{Body       = "New Email Body"
		                           From       = $SmtpFrom 
		                           Subject    = "New Email Subject"
		                           To         = $smtpto
		                           SmtpServer = $smtpserver
		                       }

        if ($smtptls) {
            $SMTPParameters.add('UseSSL', $true)
        }

        if (($smtpport -ne $null) -or ($smtpport -ne ""))
	    {
	        $SMTPParameters.add('Port', $smtpport)
	    }
	
	    if ($inifile.'Notifications\SMTP'.credentialsrequired -eq "1")
	    {
	        $smtpusername = $inifile.'Notifications\SMTP'.username
	        $smtppassword =$inifile.'Notifications\SMTP'.password
            $securesmtppassword = ConvertTo-SecureString $smtppassword -AsPlainText -Force
            $smtppscredentials = New-Object System.Management.Automation.PSCredential ($smtpusername, $securesmtppassword)
            $SMTPParameters.add('Credential', $smtppscredentials)
        }
    }
    else
    {
            $global:smtpClient = new-object system.net.mail.smtpClient 
            $smtpClient.Host = $smtpserver
            if (($smtpport -ne $null) -or ($smtpport -ne ""))
	        {
	            $smtpClient.Port = $smtpport
	        }
            
            $smtpClient.EnableSsl = $smtptls

            if ($inifile.'Notifications\SMTP'.credentialsrequired -eq "1")
	        {
	            $smtpusername = $inifile.'Notifications\SMTP'.username
	            $smtppassword =$inifile.'Notifications\SMTP'.password
                $smtpClient.Credentials = new-object System.Net.NetworkCredential($smtpusername, $smtppassword)
            }
    }
}

#
# Read in SMS details
#
$global:smsemabled=$inifile.'Notifications\SMS'.Enabled -eq 1
if ($smsemabled)
{
	$global:SMSUser = $inifile.'Notifications\SMS'.SMSUser
	$global:SMSPwd = $inifile.'Notifications\SMS'.SMSPwd
	$global:SMSMobile = $inifile.'Notifications\SMS'.SMSMobile
	$global:SMSThreshold = $inifile.'Notifications\SMS'.Threshold
	$global:SMSthrottle = $inifile.'Notifications\SMS'.Throttle
}

#
# Read in Push over details
#
$global:PushOverEnabled = $inifile.'Notifications\PushOver'.Enabled -eq 1
if ($PushOverEnabled)
{
	$global:PushoverApi = $inifile.'Notifications\PushOver'.PushOverApiToken
	$global:PushoverUser = $inifile.'Notifications\PushOver'.PushOverUser
	$global:PushoverThreshold = $inifile.'Notifications\PushOver'.Threshold
	$global:PushOverthrottle = $inifile.'Notifications\PushOver'.Throttle
}

#
# Read in log4net settings and configure the logger object
#
$global:log4netEnabled = $inifile.'Notifications\log4net'.Enabled -eq 1
if ($log4netEnabled)
{
	$log4netdll = $inifile.'Notifications\log4net'.dllpath
	$log4netconfig = $inifile.'Notifications\log4net'.configuration

	Write-Verbose $log4netdll
	Write-Verbose $log4netconfig

	if ((Test-Path $log4netdll) -eq $false)
	{
		Throw "Could not find log4net DLL at $log4netdll"
	}
	
	if ((Test-Path $log4netconfig) -eq $false)
	{
		throw "Could not find log4net config xml at $log4netconfig"
	}

	#load the log4net dll
	[void][Reflection.Assembly]::LoadFile($log4netdll)
	
	#create log4net logmanager, and get the root logger object
	$global:LogManager = [log4net.LogManager]
	$global:logger = $LogManager::GetLogger("Root")
	
	#ready the xml configuration file
	$global:configFile = New-Object System.IO.FileInfo($log4netconfig)
	
	# configure the logger and watch the config file for changes
	$global:xmlConfigurator = [log4net.Config.XmlConfigurator]::ConfigureAndWatch($global:configFile)
	
}

#
# Read in cawto settings
#
$global:cawtoenabled = $inifile.'Notifications\cawto'.enabled -eq 1
if ($cawtoenabled)
{
	$global:tngnode = $inifile.'Notifications\cawto'.node
	$global:sendrawcawtomessage = $inifile.'Notifications\cawto'.sendrawmessage -eq 1
	$global:Cawtothreshold = $inifile.'Notifications\cawto'.threshold
	$global:Cawtothrottle = $inifile.'Notifications\cawto'.throttle
}

#
# Syslog settings
#
$global:syslogenabled = $inifile.'Notifications\syslog'.enabled -eq 1
if ($syslogenabled)
{
	$global:syslogserver = $inifile.'Notifications\syslog'.server
	$global:syslogport = $inifile.'Notifications\syslog'.port
	$global:syslogfacility=$inifile.'Notifications\syslog'.facility
	$global:syslogthreshold = $inifile.'Notifications\syslog'.threshold
	$global:syslogsendraw = $inifile.'Notifications\syslog'.sendrawmessage -eq 1
	$global:syslogRFC3164 = $inifile.'Notifications\syslog'.UseRFC3164 -eq 1
}

#
# Windows event log settings
# 
$global:wineventenabled = $inifile.'Notifications\EventLog'.enabled -eq 1
if ($wineventenabled)
{
	$global:wineventlogname=$inifile.'Notifications\EventLog'.logname
	$global:wineventsourcename=$inifile.'Notifications\EventLog'.sourcename
	$global:wineventthreshold=$inifile.'Notifications\EventLog'.threshold
}

#
# HPOM Settings
#
$global:HPOMenabled = $inifile.'Notifications\HPOM'.enabled -eq 1
if ($hpomenabled)
{
	$global:HPOMApplication=$inifile.'Notifications\HPOM'.Application
	$global:HPOMMessageGroup=$inifile.'Notifications\HPOM'.MessageGroup
	$HPOMOptionsString=$inifile.'Notifications\HPOM'.Options.split(",")
	$global:HPOMOptionsCollection = New-Object System.Collections.Specialized.NameValueCollection
	foreach ($OptionString in $HPOMOptionsString) {
		$OptionStringParts = $OptionString.split("=")
		$HPOMOptionsCollection.add($OptionStringParts[0].trim(), $OptionStringParts[1].trim())
	}
	$global:HPOMEmergencyPrefix=$inifile.'Notifications\HPOM'.EmergencyPrefix
	$global:HPOMAlertPrefix=$inifile.'Notifications\HPOM'.AlertPrefix
	$global:HPOMCriticalPrefix=$inifile.'Notifications\HPOM'.CriticalPrefix
	$global:HPOMErrorPrefix=$inifile.'Notifications\HPOM'.ErrorPrefix
	$global:HPOMWarningPrefix=$inifile.'Notifications\HPOM'.WarningPrefix
	$global:HPOMNoticePrefix=$inifile.'Notifications\HPOM'.NoticePrefix
	$global:HPOMInfomationalPrefix=$inifile.'Notifications\HPOM'.InformationalPrefix
	$global:HPOMDebugPrefix=$inifile.'Notifications\HPOM'.DebugPrefix
	$global:HPOMSendRaw=$inifile.'Notifications\HPOM'.SendRawMessage -eq 1
	$global:HPOMThreshold=$inifile.'Notifications\HPOM'.Threshold
	$global:HPOMThrottle=$inifile.'Notifications\HPOM'.Throttle
}

}
