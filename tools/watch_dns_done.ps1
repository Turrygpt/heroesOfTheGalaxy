$log = 'C:\Users\Admin\.grok\sessions\c%3A%5CProjects%5CHeroesOfTheGalaxy\01a066df-b1df-7b91-a504-95fcdc2b9a83\terminal\call-e9b40066-50e6-499b-804e-b58f7d777c17-62.log'
while ($true) {
  if (Test-Path -LiteralPath $log) {
    $t = Get-Content -LiteralPath $log -Raw -ErrorAction SilentlyContinue
    if ($null -ne $t) {
      if ($t -match 'SUCCESS') { Write-Output 'DONE'; break }
      if ($t -match 'TIMEOUT waiting for DNS') { Write-Output 'FAILED'; break }
    }
  }
  # also fail if wait process disappeared without success
  $proc = Get-CimInstance Win32_Process -Filter "name='python.exe'" | Where-Object { $_.CommandLine -match 'wait_dns_ssl' }
  if (-not $proc) {
    Start-Sleep -Seconds 5
    $t2 = Get-Content -LiteralPath $log -Raw -ErrorAction SilentlyContinue
    if ($t2 -match 'SUCCESS') { Write-Output 'DONE'; break }
    Write-Output 'FAILED'
    break
  }
  Start-Sleep -Seconds 45
}
