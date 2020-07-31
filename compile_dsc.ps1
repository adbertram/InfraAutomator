[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzureAutomationAccountName,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$ScriptFilePath
)

$null = Import-AzAutomationDscConfiguration -AutomationAccountName $AzureAutomationAccountName -ResourceGroupName $ResourceGroup -SourcePath $ScriptFilePath -Published -Force
$null = Start-AzAutomationDscCompilationJob -AutomationAccountName $AzureAutomationAccountName -ResourceGroupName $ResourceGroup -ConfigurationName 'IIS'