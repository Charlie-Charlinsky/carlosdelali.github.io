[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\ContentPipeline.ps1')
$codes = Get-ContentPipelineExitCodes

try {
    $scan = Get-ContentInboxScan
    $paths = Get-ContentPipelinePaths
    Write-ContentInboxScanReport -Scan $scan -Path (Join-Path $paths.Reports 'latest-scan.json')

    Write-Output '============================================================'
    Write-Output 'CONTENT PIPELINE - INBOX SCAN'
    Write-Output '============================================================'
    Write-Output "TOTAL DOCX: $($scan.TotalDocx)"
    foreach ($status in @('NEW', 'CHANGED', 'UNCHANGED', 'INVALID')) {
        Write-Output "${status}: $($scan.Counts.$status)"
    }
    foreach ($entry in $scan.Entries) {
        Write-Output '------------------------------------------------------------'
        Write-Output $(if ($entry.TargetKey) { $entry.TargetKey } else { 'UNRESOLVED' })
        Write-Output "STATUS: $($entry.Status)"
        Write-Output "SOURCE: $($entry.Source)"
        if ($entry.Sha256) { Write-Output "SHA256: $($entry.Sha256)" }
        if ($entry.Reason) { Write-Output "REASON: $($entry.Reason)" }
    }
    Write-Output '------------------------------------------------------------'
    Write-Output 'No website files modified.'

    if ($scan.Counts.INVALID -gt 0) { exit $codes.ValidationFailure }
    exit $codes.Success
} catch {
    Write-Error $_.Exception.Message
    exit $codes.Fatal
}
