param(
    [Parameter(Mandatory=$true)]
    [string]$SiteName,
    [Parameter(Mandatory=$true)]
    [string]$IPAddress,
    [Parameter(Mandatory=$false)]
    [int]$Port = 80
)

$existing = docker ps -a --filter "name=$SiteName" --format "{{.Names}}"
if ($existing -eq $SiteName) {
    Write-Host "Un site nomme '$SiteName' existe deja." -ForegroundColor Red
    exit 1
}

Write-Host "Deploiement du site '$SiteName' sur $IPAddress`:$Port..." -ForegroundColor Cyan

docker run -d `
    --name $SiteName `
    -p "${Port}:80" `
    mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2022 `
    powershell -Command "Start-Service W3SVC; while(`$true) { Start-Sleep 3600 }"

Write-Host "Site '$SiteName' deploye avec succes !" -ForegroundColor Green
Write-Host "Accessible sur : http://${IPAddress}:${Port}" -ForegroundColor Green
