[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TestScriptFilePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TestResultsFilePath
)

Install-Module -Name Pester -Force

$params = @{
    Path         = $TestScriptFilePath
    OutputFormat = 'NUnitXml'
    OutputFile   = $TestResultsFilePath
    EnableExit   = $true
    PassThru     = $true
}
Invoke-Pester @params