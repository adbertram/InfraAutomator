[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TestScriptFilePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$TestScriptParameters,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TestResultsFilePath
)

Install-Module -Name Pester -Force

$params = @{
    Script       = @{ Path = $TestScriptFilePath; Parameters = $TestScriptParameters }
    OutputFormat = 'NUnitXml'
    OutputFile   = $TestResultsFilePath
    EnableExit   = $true
}
Invoke-Pester @params