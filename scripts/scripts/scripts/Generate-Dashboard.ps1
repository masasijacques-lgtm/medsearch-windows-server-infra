$servers = @("WS-DC01","WS-HV01","WS-HV02")
$html = "<html><body style='background:#1a1a2e;color:white'><h1>MedSearch Dashboard</h1>"
foreach($s in $servers){
$ping = Test-Connection $s -Count 1 -Quiet
$status = if($ping){"ONLINE"}else{"OFFLINE"}
$html += "<div style='background:#16213e;margin:20px;padding:20px'><h2>$s - $status</h2>"
if($ping){
$ev = Invoke-Command -ComputerName $s {Get-EventLog System -Newest 5 -EntryType Error,Warning -EA SilentlyContinue}
foreach($e in $ev){
$html += "<p>$($e.TimeGenerated) $($e.EntryType): $($e.Message.Substring(0,80))</p>"
}}
$html += "</div>"}
$html += "</body></html>"
$html | Out-File C:\Dashboard\index.html -Encoding UTF8
Write-Host "Dashboard OK" -ForegroundColor Green
