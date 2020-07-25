configuration IIS
{
    WindowsFeature IIS
    {
        Ensure               = 'Present'
        Name                 = 'Web-Server'
        IncludeAllSubFeature = $true
    }
}
IIS