$Servers = @("WS-HV01", "WS-HV02")
$LogPath = "C:\Monitoring\CentralLogs.txt"
$Timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

foreach ($Server in $Servers) {
    $Events = Invoke-Command -ComputerName $Server -ScriptBlock {
        Get-EventLog -LogName System -EntryType Error,Warning -Newest 10
    }
    foreach ($Event in $Events) {
        $Line = "[$Timestamp] [$Server] $($Event.EntryType) - $($Event.Message)"
        Add-Content -Path $LogPath -Value $Line
    }
}
Write-Host "Logs centralises avec succes dans $LogPath" -ForegroundColor Green
