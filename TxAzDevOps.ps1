Install-Module -Name SqlServer
Import-Module -Name SqlServer

foreach ($envvar in $(get-content ".env")) {
    $name, $value = $envvar.split('=')
    set-content env:\$name $value
}

$organization = $env:organization
$project = $env:project
$pat = $env:pat
$B64Pat = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("`:$pat"))

$query = @"
SELECT * FROM [Versions]
WHERE VersionNote LIKE '%#%'
ORDER BY UpdateTime
"@

$versions = Invoke-Sqlcmd -Query $query -ServerInstance "localhost" -Database "TX_Repository_20.10.31"

foreach ($version in $versions) {
    $results = $version.VersionNote | Select-String "#(?<workitemid>\d+)" -AllMatches
    # $version.Version
    # $version.VersionNote
    # $results.Matches.Value

    foreach ($workitem in $results.Matches.Value) {
        $url = "https://dev.azure.com/$organization/$project/_apis/wit/workItems/$($workitem.replace('#',''))/comments?api-version=7.0-preview"
        $body = @{text = "TimeXtender Version #$($version.Version) linked to this WorkItem: $($version.VersionNote)" }

        try {
            Invoke-RestMethod -Uri $url -Body $($body | ConvertTo-Json -Compress) -Method "POST" -Headers @{Authorization = "Basic $B64Pat" } -ContentType application/json
        }
        catch {
            Write-Error $_
            Write-Error $_.Exception.Message
        }
    }

}
