[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Rebuild
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\ContentPipeline.ps1')
. (Join-Path $PSScriptRoot 'lib\ImportEngine.ps1')
$codes = Get-ContentPipelineExitCodes

try {
    $root = Get-ContentPipelineRepositoryRoot
    $paths = (Initialize-ContentWorkspace -RepositoryRoot $root).Paths
    $plan = New-ContentImportPlan -RepositoryRoot $root -IncludeUnchanged:$Rebuild
    $planText = Format-ContentImportPlan -Plan $plan
    Write-Utf8NoBom -Path (Join-Path $paths.Reports 'latest-import-plan.txt') -Content ($planText + "`n")
    Write-Output $planText

    if (-not $Apply) {
        Write-Output 'MODE: DRY RUN'
        exit $(if ($plan.Warnings.Count) { $codes.SuccessWithWarning } else { $codes.Success })
    }

    $result = Invoke-ContentImportApply -Plan $plan -RepositoryRoot $root
    if (-not $result.Applied) {
        Write-Output 'APPLY: NO CHANGED OR NEW DOCUMENTS'
        exit $codes.Success
    }
    $report = Format-ContentImportReport -Plan $plan -Result $result
    $reportName = 'import-' + ([DateTime]::Parse($result.ImportedUtc).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')) + '.txt'
    Write-Utf8NoBom -Path (Join-Path $paths.Reports $reportName) -Content ($report + "`n")
    Write-Utf8NoBom -Path (Join-Path $paths.Reports 'latest-import-report.txt') -Content ($report + "`n")
    $staleError = Join-Path $paths.Reports 'latest-import-error.txt'
    if (Test-Path -LiteralPath $staleError -PathType Leaf) { Remove-Item -LiteralPath $staleError -Force }
    Write-Output $report
    exit $(if ($plan.Warnings.Count) { $codes.SuccessWithWarning } else { $codes.Success })
} catch {
    try {
        $paths = Get-ContentPipelinePaths
        Write-Utf8NoBom -Path (Join-Path $paths.Reports 'latest-import-error.txt') -Content ("CONTENT IMPORT STOPPED`n$($_.Exception.Message)`n")
    } catch {}
    Write-Error $_.Exception.Message
    exit $codes.ValidationFailure
}
