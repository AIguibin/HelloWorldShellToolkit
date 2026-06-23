# /ping - 网络连通性测试
# 用法: /ping --host=google.com --count=4
param(
    [string]$Target = "baidu.com",
    [int]$Count = 4
)

$AIGUIBIN_TASK_ID = if ($env:AIGUIBIN_TASK_ID) { $env:AIGUIBIN_TASK_ID } else { "N/A" }
$AIGUIBIN_OUTPUT_DIR = if ($env:AIGUIBIN_OUTPUT_DIR) { $env:AIGUIBIN_OUTPUT_DIR } else { "." }

Write-Host "=================================================="
Write-Host "  Network Ping Test"
Write-Host "=================================================="
Write-Host ""
Write-Host "  Target: $Target"
Write-Host "  Count:  $Count"
Write-Host ""

try {
    $results = Test-Connection -ComputerName $Target -Count $Count -ErrorAction Stop
    foreach ($r in $results) {
        $ms = $r.ResponseTime
        $status = if ($ms -lt 50) { "OK" } elseif ($ms -lt 200) { "SLOW" } else { "VERY SLOW" }
        Write-Host "  Reply from $($r.Address): time=${ms}ms [$status]"
    }
    Write-Host ""
    Write-Host "  Result: All $Count packets received"
} catch {
    Write-Host "  [FAILED] Cannot reach ${Target}: $($_.Exception.Message)"
}

# 保存报告
$reportPath = Join-Path $AIGUIBIN_OUTPUT_DIR "ping_report.txt"
@"
Ping Report
Generated: $(Get-Date)
Target: $Target
Count: $Count
"@ | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "  Report saved: $reportPath"
