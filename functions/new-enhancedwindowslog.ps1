function new-enhancedwindowslog
{
<#
.SYNOPSIS


.DESCRIPTION

.PARAMETER FilePath

.INPUTS

.OUTPUTS

.EXAMPLE

.NOTES
NAME: 
AUTHOR: 
LASTEDIT: 
KEYWORDS:

#>

[CMDLetBinding()]
Param ()

#[Notifications\EventLog]
#Enabled=1
#LogName=Application
#SourceName=PowerShellScript

New-EventLog -LogName $wineventlogname -Source $wineventsourcename


}