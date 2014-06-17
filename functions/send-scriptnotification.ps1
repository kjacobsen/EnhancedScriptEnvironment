
Add-Type -TypeDefinition @"
	public enum Severity_Level
	{
		Emergency,
		Alert,
		Critical,
		Error,
		Warning,
		Notice,
		Informational,
		Debug
	}
"@


function send-scriptnotification
{
<#
.SYNOPSIS
Send-ScriptNotification supports the sending of warning, error and other informational messages within scripts to a variety of places including email, log files, sms, and more. Notifications have an assosicated severity 
and optional error number.

.DESCRIPTION
Send-ScriptNotification supports the sending of messages that are related to certrain events within script files. 

Currently messages can be sent/saved to:
	Email
	Windows Event Log
	SMS (MessageNet)
	PushOver.Net
	Syslog
	log4net
	Cawto (UniCentre)
	
Support in the future:
	Notify My Android
	Splunk
	Syslog TCP
	Custom Database

The cmdlet will save/send/record messages depending on the configuraiton specify in the configuration.ini file that has either been specified or located by initialize-enhancedscriptenvironment.

The hostname and name of generating script will also be sent along with the message and severity level.

Each message/notification has an associated severity level, which has been modeled off the syslog severity levels. The table below lists the severity codes, and a general description.

	Code	Severity				General Description
	0		Emergency				A "panic" condition usually affecting multiple apps/servers/sites. At this level it would usually notify all tech staff on call.
	1		Alert					Should be corrected immediately, therefore notify staff who can fix the problem. An example would be the loss of a primary ISP connection.
	2		Critical				Should be corrected immediately, but indicates failure in a secondary system, an example is a loss of a backup ISP connection.
	3		Error					Non-urgent failures, these should be relayed to developers or admins; each item must be resolved within a given time.
	4		Warning					Warning messages, not an error, but indication that an error will occur if action is not taken, e.g. file system 85% full - each item must be resolved within a given time.
	5		Notice					Events that are unusual but not error conditions - might be summarized in an email to developers or admins to spot potential problems - no immediate action required.
	6		Informational			Normal operational messages - may be harvested for reporting, measuring throughput, etc. - no action required.
	7		Debug					Info useful to developers for debugging the application, not useful during operations.

Log4Net doesn't support as many levels, so some mappings are performed.

	Code	Severity		Log4Net		
	0		Emergency		FATAL		
	1		Alert			FATAL		
	2		Critical		FATAL		
	3		Error			ERROR		
	4		Warning			WARN		
	5		Notice			INFO		
	6		Informational	INFO		
	7		Debug			DEBUG		


Windows Event log doesn't support as many levels so some mappings are performed

	Code	Severity		Event Log		
	0		Emergency		Error		
	1		Alert			Error		
	2		Critical		Error		
	3		Error			Error		
	4		Warning			Error		
	5		Notice			Informational		
	6		Informational	Informational		
	7		Debug			Not Sent
	
Windows Event log "Error ID" or "Event ID" will be set to the number provided in the ErrorNumber Parameter

Pushover support will also perform some modifications to support their message priorities

	Code	Severity		PushOver		
	0		Emergency		Emergency		
	1		Alert			High		
	2		Critical		High		
	3		Error			Normal		
	4		Warning			Normal		
	5		Notice			Normal		
	6		Informational	Low		
	7		Debug			Low
	
Cawto will be marked and coloured according to below:
		
		Code	Severity		Colour		Icon		
		0		Emergency		Red			Error
		1		Alert			Red			Error
		2		Critical		Red			Error
		3		Error			Red			Error
		4		Warning			Organge		Warning
		5		Notice			Black		Informational
		6		Informational	Black		Informational
		7		Debug			Not Sent

HPOM has different critical levels, they may or maynot matter

Code	Severity		HPOM
0		Emergency		Critical
1		Alert			Major
2		Critical		Major
3		Error			Minor
4		Warning			Warning
5		Notice			Warning
6		Informational	Normal
7		Debug			Normal
		

Each notification system can be enabled and disabled. A threshold can also be set and messages with a seveity lower than or equal to the specified severity (as an integer) will be processed. 
For example, an SMS threshold of 4, all messages of Severity Warning, Error, Critical, Alert and Emergency will have an SMS sent. Where as a threshold of 2 would only trigger for Critical, Alert and Emergency.

Some notficiation systems (email, sms, pushover, hpom) have thottling mechanisms, this means that these systems will not send too many messages of the same severity from the same script. This is managed by writing a temp
file, to the folder specified in the configuration of the format TempVariable\SMTP-$shortscriptname-$severityint.tht. For example, if we specify an sms throttle of 5, this means we will only ever send one informational 
message for the script "logwatcher.ps1" every 5 minutes. If we have a informaitonal, and then a warning message in a 5 minute period, they will be sent.

Messages going to short text notification services like SMS and PushOver may have their messages truncated.

If no error number is specified, then 1 will be used.

.PARAMETER Message
The message of the error/notice/warning.

.PARAMETER Severity
The severity of the message. Must be of type Severity_Level, which can be: Emergency, Alert, Critical, Error, Warning, Notice, Informational, or Debug. This will decide which actions should be taken.

.PARAMETER ErrorNumber
[OPTIONAL] An error number related to the message. This could be recorded in a central troubleshooting booklet, guide, database or wiki to allow accelerated troubleshooting by support staff

.PARAMETER ThrottleOverride
[OPTIONAL]

.PARAMETER ThresholdOverride
[OPTIONAL]

.INPUTS
Nothing can be piped directly into this function

.OUTPUTS
Data may be output by the various subfunctions and cmdlets, for instance PushOver receipts will be returned if enabled.

.EXAMPLE
Send-ScriptNotification "The server is down!" Emergency
Sends a emergency level notification with message, the server is down

.EXAMPLE
Send-ScriptNotification "The server is down!" Emergency 666
Sends a emergency level notification with message, the server is down and specifies error number 666 in associated messages.

.NOTES
NAME: send-scriptnotification
AUTHOR: Kieran Jacobsen
LASTEDIT: 2014 01 29
KEYWORDS: email, notification, sms, pushover, syslog, log4net, cawto, error, informational, eventlog, hpom

.LINK

	#TODO: CLEANUP move the "message building" into one section

	#TODO: Write-debug if its a debug, write-warning for warnings and maybe write-error for erros (or would the latter break error handling)
	
	#TODO: Ho do we handle errors
#>
[CMDLetBinding()]
Param
(
	[Parameter(mandatory=$true)] [String] $message,
	[Parameter(mandatory=$true)] [Severity_Level] $Severity,
	[int] $errornumber = $null,
	[switch] $thottleoveride,
	[switch] $thresholdoveride
)
	$hostname = $ENV:Computername

	$runningas = "$ENV:Userdomain\$ENV:Username"
	
	$now = (get-date).tostring("yyyy-MM-dd hh:mm:ss zzz")

	#get the name of the script file that is 
	$scriptname = $myInvocation.ScriptName
	
	#Handle if scriptname is blank/null
	if (($scriptname -eq $null) -or ($scriptname -eq ""))
	{
		$scriptname = "PowerShell_Console_User"
	}
	
	#just the script file name (so if $scriptname is c:\scripts\myscript.ps1, this is just myscript.ps1)
	$shortscriptname = Split-Path $scriptname -leaf

	#get severity as an integer (just enum value)
	$severityint = $Severity.value__
	Write-Verbose "Severity is $severityint"
	
	#
	# For SMTP, SMS, Push and HPOM, specify the thottle limit record file, get the last time the file was written, or assume it was 01/01/1900
	#
	
	$SMTPThrottleFile = "$EnhancedTemp\SMTP-$shortscriptname-$severityint.tht"
	$LastSMTPTime = (Get-Item $SMTPThrottleFile -erroraction SilentlyContinue).LastWriteTime
	if ($LastSMTPTime -eq $null) { $LastSMTPTime = get-date "01/01/1900" }
	
	$SMSThrottleFile = "$EnhancedTemp\SMS-$shortscriptname-$severityint.tht"
	$LastSMSTime = (Get-Item $SMSThrottleFile -erroraction SilentlyContinue).LastWriteTime
	if ($LastSMSTime -eq $null) { $LastSMSTime = get-date "01/01/1900" }
	
	$PushThrottleFile = "$EnhancedTemp\PushOver-$shortscriptname-$severityint.tht"
	$LastPushTime = (Get-Item $PushThrottleFile -erroraction SilentlyContinue).LastWriteTime
	if ($LastPushTime -eq $null) { $LastPushTime = get-date "01/01/1900" }
	
	$HPOMThrottleFile = "$EnhancedTemp\HPOM-$shortscriptname-$severityint.tht"
	$LastHPOMTime = (Get-Item $HPOMThrottleFile -erroraction SilentlyContinue).LastWriteTime
	if ($LastHPOMTime -eq $null) { $LastHPOMTime = Get-Date "01/01/1900" }
	
	#
	# Override switches
	#
	
	if ($thottleoveride)
	{
		$LastSMTPTime = Get-Date "01/01/1900"
		$SMTPThrottleFile = $SMTPThrottleFile + ".ovd"
		$LastSMSTime = Get-Date "01/01/1900"
		$SMSThrottleFile = $SMSThrottleFile + ".ovd"
		$LastPushTime = Get-Date "01/01/1900"
		$PushThrottleFile = $PushThrottleFile + ".ovd"
		$LastHPOMTime = Get-Date "01/01/1900"
		$HPOMThrottleFile = $HPOMThrottleFile + ".ovd"
	}
	
	if ($thresholdoveride)
	{
		$smtpthreshold = 8
		$SMSThreshold = 8
		$PushoverThreshold = 8
		$syslogthreshold = 8
		$HPOMthreshold = 8
		#$wineventthreshold = 8		#TODO
		#$cawtothreshold = 8		#TODO
	}	
	
	#if we have enabled SMTP, and if the integer is less than or equal to the specified threshold, then we will send an email
	if ($smtpenabled -and ($severityint -le $smtpthreshold) -and ($LastSMTPTime -lt (get-date).AddMinutes(-$SMTPThrottle)))
	{
		Write-Verbose "SMTP: Severity $severityint is less than smtp threshold of $smtpthreshold"
		if ($errornumber)
		{
			 $SMTPSubject = "$Severity - $hostname - $shortscriptname - $errornumber"
		}
		else
		{
			$SMTPSubject = "$Severity - $hostname - $shortscriptname"
		}

		$SMTPBody = "This email was sent from the script $scriptname running on $hostname at $now.`n"
		$SMTPBody = $SMTPBody + "The user account running the script is: $runningas`n"
				
		if ($severityint -le 5)
		{
			if ($errornumber)
			{
				$SMTPBody = $SMTPBody + "The error number was: $errornumber`n"
			}
			$SMTPBody = $SMTPBody + "Please Investigate the errors below.`n"
		}
		$SMTPBody = $SMTPBody + "----------------------------------------`n"
		$SMTPBody = $SMTPBody + "$message`n"
		$SMTPBody = $SMTPBody + "----------------------------------------`n"
		$SMTPBody = $SMTPBody + "Please email any questions to $smtpcontact`n"
		$SMTPBody = $SMTPBody + "----------------------------------------`n"
		
		if ($smtptls)
		{
			Send-MailMessage -Body $SMTPBody -From $smtpfrom -Subject $SMTPSubject -To $smtpto -SmtpServer $smtpserver -UseSsl			
		}
		else
		{
			Send-MailMessage -Body $SMTPBody -From $smtpfrom -Subject $SMTPSubject -To $smtpto -SmtpServer $smtpserver
		}
		update-timestamp $SMTPThrottleFile
	}
	
	#create a short form message, severity, hostname etc 
	if ($errornumber)
	{
		$shortmessage = "$Severity - $hostname - $shortscriptname - $errornumber - $message"
	} 
	else
	{
		$shortmessage = "$Severity - $hostname - $shortscriptname - $message"
	}
	
	if ($shortmessage.length -gt 120)
	{
		$shortmessage = $shortmessage.substring(0, 120)
	}
	
	#if pushover is enabled and less than or equal to specified threshold, send a pushover notification
	if ($PushOverEnabled -and ($severityint -le $PushoverThreshold) -and ($LastPushTime -lt (get-date).AddMinutes(-$PushOverThrottle)))
	{
		Write-Verbose "PUSHOVER: Severity $severityint is less than pushover threshold of $PushoverThreshold"
		
		#need to convert specified severity to pushover's priority levels. Anything that is informational or debug will be low, anything that is critical or alert will be be high, 
		# and anything emergency will be emergency level which requires the user to acknowledge the alert.
		
		<#
		
		Code	Severity		PushOver		
		0		Emergency		Emergency		
		1		Alert			High		
		2		Critical		High		
		3		Error			Normal		
		4		Warning			Normal		
		5		Notice			Normal		
		6		Informational	Low		
		7		Debug			Low
		
		#>

		$priority = "Normal"
		if ($severityint -ge 6) {$priority = "Low"}
		if ($severityint -le 2) {$priority = "High"}
		if ($severityint -eq 0) {$priority = "Emergency"}
		
		#send pushover
		Send-PushOver -APIToken $PushoverApi -User $PushoverUser -message $shortmessage -priority $priority -webproxy $webproxy
		
		update-timestamp $PushThrottleFile
	}
	
	#if sms is enabled and less than or equal to specified threshold, send a sms message
	if ($smsemabled -and ($severityint -le $SMSThreshold) -and ($LastSMSTime -lt (get-date).AddMinutes(-$SMSThrottle)))
	{ 
		Write-Verbose "SMS: Severity $severityint is less than SMS threshold of $SMSThreshold"
		send-sms -username $SMSUser -password $SMSPwd -PhoneNumber $SMSMobile -message $shortmessage -webproxy $webproxy
		update-timestamp $SMSThrottleFile
	}
	
	
	#make a log friendly message or errornumber and message
	if ($errornumber)
	{
		$logmessage = "$shortscriptname - $errornumber - $message"
	}
	else
	{
		$logmessage = "$shortscriptname - $message"
	}
	
	#log4net is only enabled or disabled
	if ($log4netEnabled)
	{
		<#
		
		we need to translate the severity into the 5 different levels supported by log 4 net.
		
		Code	Severity		Log4Net		
		0		Emergency		FATAL		
		1		Alert			FATAL		
		2		Critical		FATAL		
		3		Error			ERROR		
		4		Warning			WARN		
		5		Notice			INFO		
		6		Informational	INFO		
		7		Debug			DEBUG		
		
		#>
				
		switch ($severityint) {
			0 {$logger.fatal($logmessage)}
			1 {$logger.fatal($logmessage)}
			2 {$logger.fatal($logmessage)}
			3 {$logger.error($logmessage)}
			4 {$logger.warn($logmessage)}
			5 {$logger.info($logmessage)}
			6 {$logger.info($logmessage)}
			7 {$logger.Debug($logmessage)}
			default {$logger.info($logmessage)}
		}
	}

	#if windows event log is enabled, and severity is not debut
	if ($wineventenabled -and ($severityint -le 6))
	{
		Write-Verbose "Eventlog: Severity $severityint is less than eventlog threshold of 6"
		
		<#
		We will need to perform some mapping of the event log error types to what gets provided
			Code	Severity		Event Log		
			0		Emergency		Error		
			1		Alert			Error		
			2		Critical		Error		
			3		Error			Error		
			4		Warning			Error		
			5		Notice			Informational		
			6		Informational	Informational		
			7		Debug			Not Sent
		#>
		
		$entrytype = "Information"		
		if ($severityint -eq 4) { $entrytype = "Warning" }
		if ($severityint -le 4) { $entrytype = "Error" }
		
		#write to event log, specifying error number etc
		
		if ($logmessage.length -lt 32766)
		{
			Write-EventLog -LogName $wineventlogname -Source $wineventsourcename -EventId $errornumber -EntryType $entrytype -Message $logmessage
		}
		else
		{
			$shortermessage = $logmessage.substring(0, 30000) + " <!! TRUNCATED MESSAGE !!>"
			Write-EventLog -LogName $wineventlogname -Source $wineventsourcename -EventId $errornumber -EntryType $entrytype -Message $shortermessage
		}
	}
	
	#if syslog is enabled, and severity is less than or equal to specified threshold, then send the message 
	if ($syslogenabled -and ($severityint -le $syslogthreshold))
	{
		Write-Verbose "SYSLOG: Severity $severityint is less than syslog threshold of $syslogthreshold"

		#cast the severity to syslog's severity
		$syslogsev =  [syslog_severity]::$Severity
		
		#send syslog
		send-syslogmessage -server $syslogserver -message $logmessage -Severity $syslogsev -facility $syslogfacility -udpport $syslogport -Verbose
	}
	
	#If cawto and the severity is not debug, send a caw to
	if ($cawtoenabled -and ($severityint -le 6))
	{
		Write-Verbose "CAWTO: Severity $severityint is less than CAWTO threshold of 7"
		
		<#
		
		We would like to make things in the UniCentre console "pretty", so we want to mark anything things as errors and warnings, and also colour them
		
		Code	Severity		Colour		Icon		
		0		Emergency		Red			Error
		1		Alert			Red			Error
		2		Critical		Red			Error
		3		Error			Red			Error
		4		Warning			Organge		Warning
		5		Notice			Black		Informational
		6		Informational	Black		Informational
		7		Debug			Not Sent
		
		#>
		
		$cawSeverity = "Information"
		$Colour = "Black"
		if ($severityint -eq 4) { $Colour = "Orange"; $cawSeverity = "Warning" }
		if ($severityint -le 4) { $Colour = "Red"; $cawSeverity = "Error" }
		
		#send cawto to specified node
		if ($sendrawcawtomessage)
		{
			send-cawto -colour $Colour -Node $tngnode -message $message -Severity $cawSeverity
		}
		else
		{
			send-cawto -colour $Colour -Node $tngnode -message $logmessage -Severity $cawSeverity
		}
	}
	
	if ($HPOMEnabled -and ($severityint -le $HPOMthreshold) -and ($LastHPOMTime -lt (get-date).AddMinutes(-$HPOMThrottle)))
	{
		Write-Verbose "HPOM: Severity $severityint is less than HPOM $HPOMthreshold and throttle of $HPOMThrottle minutes"
		
		<#
		
		HPOM has different critical levels, they may or maynot matter
		
		Code	Severity		HPOM
		0		Emergency		Critical
		1		Alert			Major
		2		Critical		Major
		3		Error			Minor
		4		Warning			Warning
		5		Notice			Warning
		6		Informational	Normal
		7		Debug			Normal
		
		#>
		
		$HPOMSeverity = "Normal"
		switch ($severityint) {
			0 { $HPOMSeverity = "Critical"}
			1 { $HPOMSeverity = "Major"}
			2 { $HPOMSeverity = "Major"}
			3 {	$HPOMSeverity = "Minor"}
			4 {$HPOMSeverity = "Warning"}
			5 {$HPOMSeverity = "Warning"}
			6 {$HPOMSeverity = "Normal"}
			7 {$HPOMSeverity = "Normal"}
			default {$HPOMSeverity = "Normal"}
		}
		
		if ($HPOMSendRaw)
		{
			send-hpommessage -Message $message -Severity $HPOMSeverity -Application $HPOMApplication -Object $shortscriptname -messagegroup $HPOMMessageGroup -Options $HPOMOptionsCollection
		}
		else
		{
			$HPOMMessage = $logmessage
			switch ($severityint) {
				0 { $HPOMMessage = $HPOMEmergencyPrefix + $HPOMMessage }
				1 { $HPOMMessage = $HPOMAlertPrefix + $HPOMMessage }
				2 {	$HPOMMessage = $HPOMCriticalPrefix + $HPOMMessage }
				3 { $HPOMMessage = $HPOMErrorPrefix + $HPOMMessage }
				4 {	$HPOMMessage = $HPOMWarningPrefix + $HPOMMessage }
				5 {	$HPOMMessage = $HPOMNoticePrefix + $HPOMMessage	}
				6 {	$HPOMMessage = $HPOMInformationalPrefix + $HPOMMessage }
				7 {	$HPOMMessage = $HPOMDebugPrefix + $HPOMMessage }
				default { $HPOMMessage = $HPOMInformationalPrefix + $HPOMMessage }
			}
			
			send-hpommessage -Message $HPOMMessage -Severity $HPOMSeverity -Application $HPOMApplication -Object $shortscriptname -messagegroup $HPOMMessageGroup -Options $HPOMOptionsCollection
		}
		
		update-timestamp $HPOMThrottleFile
	}
}
