function new-enhancedwindowslog
{
<#
.SYNOPSIS
Creates the required Event Log for the Enhanced Script logging to Windows Event logs

.DESCRIPTION
Creates specified Windows Eventlog Source in specied Event Log

.INPUTS
No inputs

.OUTPUTS
No Outputs

.NOTES
NAME: new-enhancedwindowslog
AUTHOR: Kieran Jacobsen
LASTEDIT: 2014 03 10
KEYWORDS: windows, eventlog, applog, logging

.LINK https://github.com/kjacobsen/EnhancedScriptEnvironment

#>

[CMDLetBinding()]
Param ()

New-EventLog -LogName $wineventlogname -Source $wineventsourcename


}
 