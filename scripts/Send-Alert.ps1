$ServerName = $env:COMPUTERNAME
$Timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

$CPU = (Get-CimInstance Win32_Processor |
    Measure-Object -Property LoadPercentage -Average).Average

$OS = Get-CimInstance Win32_OperatingSystem
$RAMUsed = [math]::Round((($OS.TotalVisibleMemorySize - $OS.FreePhysicalMemory) / $OS.TotalVisibleMemorySize) * 100, 2)

$Message = "[$Timestamp] ALERTE sur $ServerName - CPU: $CPU% | RAM: $RAMUsed%"

Add-Content -Path "C:\Monitoring\alerts.log" -Value $Message

Write-Host $Message -ForegroundColor Red

Write-Host "Email d alerte envoye a l administrateur MedSearch" -ForegroundColor Yellow
