<#

Code	Severity		Log4Net		General Description
0		Emergency		FATAL		A "panic" condition usually affecting multiple apps/servers/sites. At this level it would usually notify all tech staff on call.
1		Alert			FATAL		Should be corrected immediately, therefore notify staff who can fix the problem. An example would be the loss of a primary ISP connection.
2		Critical		FATAL		Should be corrected immediately, but indicates failure in a secondary system, an example is a loss of a backup ISP connection.
3		Error			ERROR		Non-urgent failures, these should be relayed to developers or admins; each item must be resolved within a given time.
4		Warning			WARN		Warning messages, not an error, but indication that an error will occur if action is not taken, e.g. file system 85% full - each item must be resolved within a given time.
5		Notice			INFO		Events that are unusual but not error conditions - might be summarized in an email to developers or admins to spot potential problems - no immediate action required.
6		Informational	INFO		Normal operational messages - may be harvested for reporting, measuring throughput, etc. - no action required.
7		Debug			DEBUG		Info useful to developers for debugging the application, not useful during operations.

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


function send-scriptnotification
{
[CMDLetBinding()]
Param
(
	[Parameter(mandatory=$true)] [String] $message,
	[Parameter(mandatory=$true)] [Severity_Level] $Severity,
	[int] $errornumber = 1 
)
	$severityint = $Severity.value__
	
	Write-Verbose "Severity is $severityint"
	
	if ($smtpenabled -and ($severityint -le $smtpthreshold))
	{
		Write-Verbose "SMTP: Severity $severityint is less than smtp threshold of $smtpthreshold"
		$SMTPSubject = "$hostname - $scriptname - $Severity - $errornumber"
		
		$SMTPBody = "This email was sent from the script $scriptname running on $hostname.`n"
		$SMTPBody = $SMTPBody + "The error number was: $errornumber`n"
		$SMTPBody = $SMTPBody + "Please Investigate the errors/messages below.`n"
		$SMTPBody = $SMTPBody + "----------------------------------------`n"
		$SMTPBody = $SMTPBody + "$message`n"
		$SMTPBody = $SMTPBody + "----------------------------------------`n"
		$SMTPBody = $SMTPBody + "Please email any questions to $smtpfrom `n"
		$SMTPBody = $SMTPBody + "----------------------------------------`n"
		
		Send-MailMessage -Body $SMTPBody -From $smtpfrom -Subject $SMTPSubject -To $smtpto -SmtpServer $smtpserver
	}
	
	$shortmessage = "$Severity - $hostname - $scriptname - $errornumber - $message"
		
	if ($PushOverEnabled -and ($severityint -le $PushoverThreshold))
	{
		Write-Verbose "PUSHOVER: Severity $severityint is less than pushover threshold of $PushoverThreshold"
		$priority = "Normal"
		if ($severityint -ge 6) {$priority = "Low"}
		if ($severityint -le 2) {$priority = "High"}
		if ($severityint -eq 0) {$priority = "Emergency"}
		Send-PushOver -APIToken $PushoverApi -User $PushoverUser -message $shortmessage -priority $priority -webproxy $webproxy
	}
	
	if ($smsemabled -and ($severityint -le $SMSThreshold))
	{ 
		Write-Verbose "SMS: Severity $severityint is less than SMS threshold of $SMSThreshold"
		send-sms -username $SMSUser -password $SMSPwd -PhoneNumber $SMSMobile -message $shortmessage -webproxy $webproxy
	}
	
	$logmessage = "<$errornumber> - $message"
	
	if ($log4netEnabled)
	{
		[void][Reflection.Assembly]::LoadFile($log4netdll)
		$LogManager = [log4net.LogManager]
		$logger = $LogManager::GetLogger("Root")
		$configFile = New-Object System.IO.FileInfo($log4netconfig)
		$xmlConfigurator = [log4net.Config.XmlConfigurator]::ConfigureAndWatch($configFile)
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

	if ($cawtoenabled -and ($severityint -le 6))
	{
		Write-Verbose "CAWTO: Severity $severityint is less than CAWTO threshold of 7"
		$cawSeverity = "Information"
		$Colour = "Black"
		switch ($severityint) {
			0 {$Colour = "Red"; $cawSeverity = "Error"}
			1 {$Colour = "Red"; $cawSeverity = "Error"}
			2 {$Colour = "Red"; $cawSeverity = "Error"}
			3 {$Colour = "Red"; $cawSeverity = "Error"}
			4 {$Colour = "Orange"; $cawSeverity = "Warning"}
		}
		send-cawto -colour $Colour -Node $tngnode -message $logmessage -Severity $cawSeverity
	}
	
	if ($wineventenabled -and ($severityint -le 6))
	{
		Write-Verbose "Eventlog: Severity $severityint is less than eventlog threshold of 6"
		$entrytype = "Information"		
		if ($severityint -eq 4) { $entrytype = "Warning" }
		if ($severityint -le 4) { $entrytype = "Error" }
		Write-EventLog -LogName $wineventlogname -Source $wineventsourcename -EventId $errornumber -EntryType $entrytype -Message $message
	}
	
	if ($syslogenabled -and ($severityint -le $syslogthreshold))
	{
		Write-Verbose "SYSLOG: Severity $severityint is less than syslog threshold of $syslogthreshold"
		$syslogsev =  [syslog_severity]::$Severity
		send-syslogmessage -server $syslogserver -message $logmessage -Severity $syslogsev -facility $syslogfacility -udpport $syslogport -Verbose
	}
}

<#

Code	Severity		Log4Net		General Description
0		Emergency		FATAL		A "panic" condition usually affecting multiple apps/servers/sites. At this level it would usually notify all tech staff on call.
1		Alert			FATAL		Should be corrected immediately, therefore notify staff who can fix the problem. An example would be the loss of a primary ISP connection.
2		Critical		FATAL		Should be corrected immediately, but indicates failure in a secondary system, an example is a loss of a backup ISP connection.
3		Error			ERROR		Non-urgent failures, these should be relayed to developers or admins; each item must be resolved within a given time.
4		Warning			WARN		Warning messages, not an error, but indication that an error will occur if action is not taken, e.g. file system 85% full - each item must be resolved within a given time.
5		Notice			INFO		Events that are unusual but not error conditions - might be summarized in an email to developers or admins to spot potential problems - no immediate action required.
6		Informational	INFO		Normal operational messages - may be harvested for reporting, measuring throughput, etc. - no action required.
7		Debug			DEBUG		Info useful to developers for debugging the application, not useful during operations.

#>
