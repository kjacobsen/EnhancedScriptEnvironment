function Get-IniContent {
<# 
.SYNOPSIS
Reads an INI file producing a more easily navigated structure.

.DESCRIPTION
Get-IniContent reads the content of an ini file and turns it into a really easily read and navigated PowerShell object.

.PARAMETER FilePath
path to ini file to be read

.INPUTS
Nothing can be piped directly into this function

.OUTPUTS
Output will be an object representing the ini file.

.EXAMPLE
$inicontent = Get-IniContent c:\myini.ini
Reads the ini file, myini.ini and stores the content in the variable specified.

.NOTES
NAME: 
AUTHOR: 
LASTEDIT: 
KEYWORDS:

.LINK http://blogs.technet.com/b/heyscriptingguy/archive/2011/08/20/use-powershell-to-work-with-any-ini-file.aspx

#>

[CMDLetBinding()]
Param (
	[String] $filePath
)

If (! (Test-Path $filePath)) {
	throw "ini file could not be found"
}

$ini = @{}
switch -regex -file $filePath {
    "^\[(.+)\]" # Section
    {
        $section = $matches[1]
        $ini[$section] = @{}
        $CommentCount = 0
    }
    
    "^(;.*)$" # Comment
    {
        $value = $matches[1]
        $CommentCount = $CommentCount + 1
        $name = "Comment" + $CommentCount
        $ini[$section][$name] = $value
    }
    
    "(.+?)\s*=(.*)" # Key
    {
        $name,$value = $matches[1..2]
        $ini[$section][$name] = $value
    }
}

return $ini

}
