## Parameters not implemented yet in v5
# [CmdletBinding()]
# param(
#     [Parameter(Mandatory)]
#     [string]$VmHostName
# )

describe 'IIS' {

    $testScriptPath = "$PSScriptRoot\temp.ps1"
    Set-Content -Path $testScriptPath -Value "(Get-WindowsFeature -Name 'Web-Server').Installed"
    
    it 'has the IIS web feature installed' {
        $result = Invoke-AzVMRunCommand -ResourceGroupName $global:rgName -VMName $global:VmHostName -CommandId 'RunPowerShellScript' -ScriptPath $testScriptPath
        $result | should -Be $true
    }

    Remove-Item -Path $testScriptPath -ErrorAction Ignore
}