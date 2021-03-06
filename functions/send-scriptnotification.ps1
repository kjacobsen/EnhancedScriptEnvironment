<# 
	Enum type defining the severity levels
#>
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


function send-scriptnotification {
<#
.SYNOPSIS
send-scriptnotification sends informaiton/error notifications based upon message criticality.

.DESCRIPTION
When called from a script of shell, will send notifcations based upon the criticality of the message to different endpoints. There are plenty of different places that messages can be sent to, see the notes section for what is supported.

Ensure that initialise-enhancedscriptenvironment has been called prior to running this CMDLet, it requires a number of global variables to be setup by it.

.NOTES
NAME: send-scriptnotification
AUTHOR: Kieran Jacobsen
LASTEDIT: 2014 02 13
KEYWORDS: email, notification, sms, pushover, syslog, log4net, cawto, error, informational, eventlog, hpom

Send-ScriptNotification supports the sending of messages that are related to certrain events within script files. 

Currently messages can be sent/saved to:
	Console/session/host
	Email
	Windows Event Log
	SMS (MessageNet)
	PushOver.Net
	Syslog
	log4net
	Cawto (UniCentre)
	HPOM
	
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

When messages are displayed into the host/console/session colours will be changed depending on issue

	Code	Severity		Colour
	0		Emergency		Red
	1		Alert			Red
	2		Critical		Red
	3		Error			Red
	4		Warning			Yellow
	5		Notice			DarkGreen
	6		Informational	Green
	7		Debug			Magenta
	
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
[OPTIONAL] [Switch] Force messages to go out, no matter what throttle limits have been sent out. Script will ignore what is specified in the configuration.

.PARAMETER ThresholdOverride
[OPTIONAL] [Switch] Force a message to notify using all enabled systems, no matter what threshold has been sent. Script will ignore what is specified in the configuration.

.PARAMETER SendRawMessage
[OPTIONAL] [Switch] Force messages to CAWTO and HPOM to send the error without any special formatting. Script will ignore what is specified in the configuration.

.INPUTS
Nothing can be piped directly into this function

.OUTPUTS
None

.EXAMPLE
Send-ScriptNotification "The server is down!" Emergency
Sends a emergency level notification with message, the server is down

.EXAMPLE
Send-ScriptNotification "The server is down!" Emergency 666
Sends a emergency level notification with message, the server is down and specifies error number 666 in associated messages.

.EXAMPLE
Send-ScriptNotification "The server is up" debug -Thresholdoverride
MEssage will be sent even though its a debug message and wouldn't typically be recorded.


.LINK
https://github.com/kjacobsen/EnhancedScriptEnvironment

#>
[CMDLetBinding()]
Param (
	[Parameter(mandatory=$true)] [String] $message,
	[Parameter(mandatory=$true)] [Severity_Level] $Severity,
	[string] $Application,
	[int] $errornumber = 0,
	[switch] $thottleoveride,
	[switch] $thresholdoveride,
	[switch] $SendRawMessage
)
    # Import and init scripting environment if it hasnt already been loaded
    if (($LoadedConfigurationFile -eq "") -or ($LoadedConfigurationFile -eq $null)) {
    	Initialize-enhancedscriptenvironment
    }
    
	$hostname = $ENV:Computername

	$runningas = "$ENV:Userdomain\$ENV:Username"
	
	$now = (get-date).tostring("yyyy-MM-dd HH:mm:ss zzz")

	if ($Application) {
		$scriptname = $Application
	} else {
		#get the name of the script file that is 
		$scriptname = $myInvocation.ScriptName		
	}

	#Handle if scriptname is blank/null
	if (($scriptname -eq $null) -or ($scriptname -eq "")) {
		$scriptname = "PowerShell_Console_User"
	}
	Write-Verbose "Script name is $scriptname"
	
	#just the script file name (so if $scriptname is c:\scripts\myscript.ps1, this is just myscript.ps1)
	$shortscriptname = Split-Path $scriptname -leaf
    Write-Verbose "Script Shortname is $shortscriptname"

	#get severity as an integer (just enum value)
	$severityint = $Severity.value__
	Write-Verbose "Severity is $severityint"
	
	#
	# Build Shorter Message Format
	#
	
	#create a short form message, severity, hostname etc 
	if ($errornumber -ne 0) {
		$shortmessage = "$Severity - $hostname - $shortscriptname - $errornumber - $message"
	} else {
		$shortmessage = "$Severity - $hostname - $shortscriptname - $message"
	}
	
	#short message must be less than 120 characters
	if ($shortmessage.length -gt 120) {
		$shortmessage = $shortmessage.substring(0, 120)
	}
	
	#
	# Text Log File Friendly message
	#
	
	#make a log friendly message or errornumber and message
	if ($errornumber -ne 0)
	{
		$logmessage = "$shortscriptname - $errornumber - $message"
	}
	else
	{
		$logmessage = "$shortscriptname - $message"
	}
	
	
	#
	# For SMTP, SMS, Push and HPOM, specify the thottle limit record file, get the last time the file was written, or assume it was 01/01/1900
	#
	
	$SMTPThrottleFile = "$EnhancedTemp\SMTP-$shortscriptname-$severityint.tht"
	$LastSMTPTime = (Get-Item $SMTPThrottleFile -erroraction Ignore).LastWriteTime
	if ($LastSMTPTime -eq $null) { 
		$LastSMTPTime = get-date "01/01/1900" 
	}
	
	$SMSThrottleFile = "$EnhancedTemp\SMS-$shortscriptname-$severityint.tht"
	$LastSMSTime = (Get-Item $SMSThrottleFile -erroraction Ignore).LastWriteTime
	if ($LastSMSTime -eq $null) { 
		$LastSMSTime = get-date "01/01/1900" 
	}
	
	$PushThrottleFile = "$EnhancedTemp\PushOver-$shortscriptname-$severityint.tht"
	$LastPushTime = (Get-Item $PushThrottleFile -erroraction Ignore).LastWriteTime
	if ($LastPushTime -eq $null) { 
		$LastPushTime = get-date "01/01/1900" 
	}
	
	$HPOMThrottleFile = "$EnhancedTemp\HPOM-$shortscriptname-$severityint.tht"
	$LastHPOMTime = (Get-Item $HPOMThrottleFile -erroraction Ignore).LastWriteTime
	if ($LastHPOMTime -eq $null) { 
		$LastHPOMTime = Get-Date "01/01/1900" 
	}
	
	$CawtoThrottleFile = "$EnhancedTemp\Cawto-$shortscriptname-$severityint.tht"
	$LastCawtoTime = (Get-Item $CawtoThrottleFile -erroraction Ignore).LastWriteTime
	if ($LastCawtoTime -eq $null) { 
		$LastCawtoTime = Get-Date "01/01/1900" 
	}
	
	#
	# Override switches
	#
	
	if ($thottleoveride) {
		$LastSMTPTime = Get-Date "01/01/1900"
		$SMTPThrottleFile = $SMTPThrottleFile + ".ovd"
		$LastSMSTime = Get-Date "01/01/1900"
		$SMSThrottleFile = $SMSThrottleFile + ".ovd"
		$LastPushTime = Get-Date "01/01/1900"
		$PushThrottleFile = $PushThrottleFile + ".ovd"
		$LastCawtoTime = Get-Date "01/01/1900"
		$CawtoThrottleFile = $CawtoThrottleFile + ".ovd"
		$LastHPOMTime = Get-Date "01/01/1900"
		$HPOMThrottleFile = $HPOMThrottleFile + ".ovd"
	}
	
	if ($thresholdoveride) {
		$WriteHostThreshold = 8
		$smtpthreshold = 8
		$SMSThreshold = 8
		$PushoverThreshold = 8
		$Cawtothreshold = 8
		$syslogthreshold = 8
		$HPOMthreshold = 8
		$wineventthreshold = 8
	}
	
	if ($SendRawMessage) {
		$sendrawcawtomessage = $true
		$HPOMSendRaw = $true
	}
	
	#
	# Write to host
	#
	if ($WriteHostEnabled -and ($severityint -le $WriteHostThreshold)) {
		
		$hostcolour = "White"
		switch ($severityint) {
			0 { $hostcolour = "Red" }
			1 { $hostcolour = "Red" }
			2 { $hostcolour = "Red" }
			3 { $hostcolour = "Red" }
			4 { $hostcolour = "Yellow" }
			5 { $hostcolour = "DarkGreen" }
			6 { $hostcolour = "Green" }
			7 { $hostcolour = "Magenta" }
			default { $hostcolour = "White" }
		}
		
		Write-Host "[$Severity] [$now] $message" -BackgroundColor "Black" -ForegroundColor $hostcolour
	}
	
	#
	# Send email
	#
	
	#if we have enabled SMTP, and if the integer is less than or equal to the specified threshold, then we will send an email
	if ($smtpenabled -and ($severityint -le $smtpthreshold) -and ($LastSMTPTime -lt (get-date).AddMinutes(-$SMTPThrottle))) {
		Write-Verbose "SMTP: Severity $severityint is less than smtp threshold of $smtpthreshold"
		if ($errornumber -ne 0) {
			 $SMTPSubject = "$Severity - $hostname - $shortscriptname - $errornumber"
		} else {
			$SMTPSubject = "$Severity - $hostname - $shortscriptname"
		}

		$SMTPBody = "This email was sent from the script $scriptname running on $hostname at $now.`n"
		$SMTPBody = $SMTPBody + "The user account running the script is: $runningas .`n"
				
		if ($severityint -le 5) {
			if ($errornumber  -ne 0) {
				$SMTPBody = $SMTPBody + "The error number was: $errornumber`n"
			}
			$SMTPBody = $SMTPBody + "`nPlease Investigate the errors below.`n"
		} else {
			$SMTPBody = $SMTPBody + "`nPlease be aware of the messages below.`n"
		}
		$SMTPBody = $SMTPBody + "----------------------------------------`n"
		$SMTPBody = $SMTPBody + "$message`n"
		$SMTPBody = $SMTPBody + "----------------------------------------`n"
		$SMTPBody = $SMTPBody + "Please email any questions to $smtpcontact`n"
		$SMTPBody = $SMTPBody + "----------------------------------------`n"

		
		
        if ($PSVersionTable.PSVersion.Major -ge 3)
        {

            $SMTPParameters["Body"] = $SMTPBody
		    $SMTPParameters["Subject"] = $SMTPSubject

		    try {
			    Send-MailMessage @SmtpParameters
			    update-timestamp $SMTPThrottleFile
		    } catch {
			    Throw "Error sending mail message, $_"
		    }
        }
        else
        {

            try {
                $smtpClient.Send($smtpfrom, $smtpto, $SMTPSubject, $SMTPBody)
                update-timestamp $SMTPThrottleFile
            } catch {
                Throw "Error sending mail message using legacy method, $_"
            }
        }
	}
		
	#
	# Push Notification
	#
	
	#if pushover is enabled and less than or equal to specified threshold, send a pushover notification
	if ($PushOverEnabled -and ($severityint -le $PushoverThreshold) -and ($LastPushTime -lt (get-date).AddMinutes(-$PushOverThrottle))) {
		Write-Verbose "PUSHOVER: Severity $severityint is less than pushover threshold of $PushoverThreshold"
		
		#need to convert specified severity to pushover's priority levels. Anything that is informational or debug will be low, anything that is critical or alert will be be high, 
		# and anything emergency will be emergency level which requires the user to acknowledge the alert.
		
		$priority = "Normal"
		switch ($severityint) {
			0 { $priority = "Emergency" }
			1 { $priority = "High" }
			2 { $priority = "High" }
			3 { $priority = "Normal" }
			4 { $priority = "Normal" }
			5 { $priority = "Normal" }
			6 { $priority = "Low" }
			7 { $priority = "Low" }
			default { $priority = "Normal" }
		}
		
		try	{
			#send pushover
			Send-PushOver -APIToken $PushoverApi -User $PushoverUser -message $shortmessage -priority $priority -webproxy $webproxy
			update-timestamp $PushThrottleFile
		} catch {
			Throw "Error sending pushover message, $_"
		}
	}
	
	#
	# SMS Notification
	#
	
	#if sms is enabled and less than or equal to specified threshold, send a sms message
	if ($smsemabled -and ($severityint -le $SMSThreshold) -and ($LastSMSTime -lt (get-date).AddMinutes(-$SMSThrottle))) { 
		Write-Verbose "SMS: Severity $severityint is less than SMS threshold of $SMSThreshold"
		try {
			send-sms -username $SMSUser -password $SMSPwd -PhoneNumber $SMSMobile -message $shortmessage -webproxy $webproxy
			update-timestamp $SMSThrottleFile
		} catch {
			Throw "Error sending sms message, $_"
		}
	}
	
	#
	# Log 4 Net
	#	
	#log4net is only enabled or disabled
	if ($log4netEnabled) {
	
		try {
			switch ($severityint) {
				0 { $logger.fatal($logmessage) }
				1 { $logger.fatal($logmessage) }
				2 { $logger.fatal($logmessage) }
				3 { $logger.error($logmessage) }
				4 { $logger.warn($logmessage)  }
				5 { $logger.info($logmessage)  }
				6 { $logger.info($logmessage)  }
				7 { $logger.Debug($logmessage) }
				default {$logger.info($logmessage)}
			}
		} catch {
			throw "error writing to log4net, $_"
		}
	}

	#
	# Windows Event logs
	#
	#if windows event log is enabled, and severity is not debug
	if ($wineventenabled -and ($severityint -le $wineventthreshold))
	{
		Write-Verbose "Eventlog: Severity $severityint is less than eventlog threshold of 6"
		
		$entrytype = "Information"		
		if ($severityint -eq 4) { 
			$entrytype = "Warning" 
		}
		
		if ($severityint -le 4) { 
			$entrytype = "Error" 
		}
		
		#write to event log, specifying error number etc
		try {
			if ($logmessage.length -lt 32766) {
				Write-EventLog -LogName $wineventlogname -Source $wineventsourcename -EventId $errornumber -EntryType $entrytype -Message $logmessage
			} else {
				$shortermessage = $logmessage.substring(0, 30000) + " <!! TRUNCATED MESSAGE !!>"
				Write-EventLog -LogName $wineventlogname -Source $wineventsourcename -EventId $errornumber -EntryType $entrytype -Message $shortermessage
			}
		} catch {
			Throw "Error writing message to windows event log, $_"
		}

	}
	
	#
	# Syslog Send
	#
	#if syslog is enabled, and severity is less than or equal to specified threshold, then send the message 
	if ($syslogenabled -and ($severityint -le $syslogthreshold)) {
		Write-Verbose "SYSLOG: Severity $severityint is less than syslog threshold of $syslogthreshold"

		#cast the severity to syslog's severity
		$syslogsev =  [syslog_severity]::$Severity
		
		if ($syslogsendraw) {
			try {
				if ($syslogRFC3164) {
					send-syslogmessage -server $syslogserver -message $message -Severity $syslogsev -facility $syslogfacility -udpport $syslogport -RFC3164 -verbose
				} else {
					send-syslogmessage -server $syslogserver -message $message -Severity $syslogsev -facility $syslogfacility -udpport $syslogport -verbose
				}
			} catch {
				Throw "Error sending syslog, $_"
			}
		} else {
			if ($errornumber -eq 0) {
				$syserrnumber = "-"
			} else {
				$syserrnumber = $errornumber
			}
		
			try {
				if ($syslogRFC3164) {
					send-syslogmessage -server $syslogserver -message $logmessage -Severity $syslogsev -facility $syslogfacility -udpport $syslogport -ApplicationName $scriptname -MessageID $syserrnumber -RFC3164 -verbose
				} else {
					send-syslogmessage -server $syslogserver -message $logmessage -Severity $syslogsev -facility $syslogfacility -udpport $syslogport -ApplicationName $scriptname -MessageID $syserrnumber -verbose
				}
			} catch {
				Throw "Error sending syslog, $_"
			}
		}
	}
	
	#
	# Cawto
	#
	#If cawto and the severity is not debug, send a caw to
	if ($cawtoenabled -and ($severityint -le $Cawtothreshold) -and ($LastCawtoTime -lt (Get-date).AddMinutes($CawtoThrottle))) {
		Write-Verbose "CAWTO: Severity $severityint is less than CAWTO threshold $Cawtothreshold and throttle of $CawtoThrottle minutes"
				
		$cawSeverity = "Information"
		$Colour = "Black"
		if ($severityint -eq 4) { 
			$Colour = "Orange"
			$cawSeverity = "Warning"
		}
		
		if ($severityint -le 4) { 
			$Colour = "Red"
			$cawSeverity = "Error" 
		}
		
		try	{
			#send cawto to specified node
			if ($sendrawcawtomessage) {
				send-cawto -colour $Colour -Node $tngnode -message $message -Severity $cawSeverity
			} else {
				send-cawto -colour $Colour -Node $tngnode -message $logmessage -Severity $cawSeverity
			}
			update-timestamp $CawtoThrottleFile
		} catch {
			Throw "Error sending cawto, $_"
		}

	}
	
	#
	# HPOM
	#
	
	if ($HPOMEnabled -and ($severityint -le $HPOMthreshold) -and ($LastHPOMTime -lt (get-date).AddMinutes(-$HPOMThrottle))) {
		Write-Verbose "HPOM: Severity $severityint is less than HPOM $HPOMthreshold and throttle of $HPOMThrottle minutes"
				
		$HPOMSeverity = "Normal"
		switch ($severityint) {
			0 { $HPOMSeverity = "Critical" }
			1 { $HPOMSeverity = "Major" }
			2 { $HPOMSeverity = "Major" }
			3 {	$HPOMSeverity = "Minor" }
			4 { $HPOMSeverity = "Warning" }
			5 { $HPOMSeverity = "Normal" }
			6 { $HPOMSeverity = "Normal" }
			7 { $HPOMSeverity = "Normal" }
			default {$HPOMSeverity = "Normal"}
		}
		
		try {
			if ($HPOMSendRaw) {
				send-hpommessage -Message $message -Severity $HPOMSeverity -Application $HPOMApplication -Object $shortscriptname -messagegroup $HPOMMessageGroup -Options $HPOMOptionsCollection
			} else {
				$HPOMMessage = $logmessage
				switch ($severityint) {
					0 { $HPOMMessage = $HPOMEmergencyPrefix + " - $now - " + $HPOMMessage }
					1 { $HPOMMessage = $HPOMAlertPrefix + " - $now - " + $HPOMMessage }
					2 {	$HPOMMessage = $HPOMCriticalPrefix + " - $now - " + $HPOMMessage }
					3 { $HPOMMessage = $HPOMErrorPrefix + " - $now - " + $HPOMMessage }
					4 {	$HPOMMessage = $HPOMWarningPrefix + " - $now - " + $HPOMMessage }
					5 {	$HPOMMessage = $HPOMNoticePrefix + " - $now - " + $HPOMMessage	}
					6 {	$HPOMMessage = $HPOMInformationalPrefix + " - $now - " + $HPOMMessage }
					7 {	$HPOMMessage = $HPOMDebugPrefix + " - $now - " + $HPOMMessage }
					default { $HPOMMessage = $HPOMInformationalPrefix + " - $now - " + $HPOMMessage }
				}
				send-hpommessage -Message $HPOMMessage -Severity $HPOMSeverity -Application $HPOMApplication -Object $shortscriptname -messagegroup $HPOMMessageGroup -Options $HPOMOptionsCollection
			}
			update-timestamp $HPOMThrottleFile
		} catch {
			throw "Error sending message to HPOM, $_"
		}
	}
}
