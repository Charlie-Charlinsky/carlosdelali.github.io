[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\ContentPipeline.ps1')
. (Join-Path $PSScriptRoot 'lib\ImportEngine.ps1')
$codes = Get-ContentPipelineExitCodes
$root = Get-ContentPipelineRepositoryRoot
$failures = @()

function Assert-ImportEngine {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { Write-Output "PASS: $Label" } else { $script:failures += $Label; Write-Output "FAIL: $Label" }
}

try {
    $before = Get-ContentTreeFingerprint -RepositoryRoot $root
    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('portfolio-import-engine-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
    try {
        $source = Join-Path $temporaryRoot 'source.txt'
        $destination = Join-Path $temporaryRoot 'destination.txt'
        Write-Utf8NoBom -Path $source -Content 'new'
        Write-Utf8NoBom -Path $destination -Content 'old'
        Copy-ContentFileAtomically -Source $source -Destination $destination
        Assert-ImportEngine ((Get-Content -LiteralPath $destination -Raw) -ceq 'new') 'atomic replacement primitive'
    } finally {
        if (Test-Path -LiteralPath $temporaryRoot) { [IO.Directory]::Delete([IO.Path]::GetFullPath($temporaryRoot), $true) }
    }
    $plan = New-ContentImportPlan -RepositoryRoot $root -IncludeUnchanged
    $targets = @($plan.Items | ForEach-Object TargetKey)
    Assert-ImportEngine (($targets -join '|') -ceq 'about:main|cv:main|game:ea-sports-pga-tour') 'three expected targets resolve in deterministic order'
    Assert-ImportEngine ($plan.Scan.Counts.INVALID -eq 0) 'filename and target preflight'
    Assert-ImportEngine ($plan.Items.Count -eq 3) 'all real DOCX files parse'

    foreach ($item in $plan.Items) {
        foreach ($relative in $item.Outputs.Keys) {
            $html = $item.Outputs[$relative]
            try { [void][xml]$html; $valid = $true } catch { $valid = $false }
            Assert-ImportEngine $valid "$($item.TargetKey) generated HTML is well-formed"
            $currentOutput = Get-Content -LiteralPath (Join-Path $root ($relative.Replace('/', '\'))) -Raw -Encoding UTF8
            if ($item.Status -eq 'UNCHANGED') { Assert-ImportEngine ($currentOutput -ceq $html) "$($item.TargetKey) current output matches the compiler" }
        }
    }
    $about = $plan.Items | Where-Object TargetKey -eq 'about:main'
    Assert-ImportEngine ($about.Summary.esParagraphs -eq 4 -and $about.Summary.enParagraphs -eq 4) 'About ES/EN four-paragraph contract'
    $cv = $plan.Items | Where-Object TargetKey -eq 'cv:main'
    Assert-ImportEngine ($cv.Summary.ludographyGroups -eq 3 -and $cv.Summary.download -eq 'cv') 'CV registry-owned Ludography and CV-only download contract'
    $game = $plan.Items | Where-Object TargetKey -eq 'game:ea-sports-pga-tour'
    Assert-ImportEngine ($game.Summary.es.Structure -ceq $game.Summary.en.Structure) 'PGA ES/EN structural parity'
    Assert-ImportEngine ($plan.GameRegistry.Game.year -ceq '2023') 'PGA Year mapping'
    Assert-ImportEngine ($plan.GameRegistry.Game.studio -ceq 'EA Sports') 'PGA Company mapping'
    Assert-ImportEngine ($plan.GameRegistry.Game.engineId -ceq 'frostbite') 'PGA deterministic engine mapping'
    try { $parsedRegistry = $plan.GameRegistry.Json | ConvertFrom-Json; $jsonValid = $null -ne $parsedRegistry.games } catch { $jsonValid = $false }
    Assert-ImportEngine $jsonValid 'updated Game registry JSON is valid'
    if ($game.Status -eq 'UNCHANGED') {
        Assert-ImportEngine ((Get-Content (Join-Path $root 'data\games.json') -Raw -Encoding UTF8) -ceq $plan.GameRegistry.Json) 'current Game registry matches the compiler'
    }

    $after = Get-ContentTreeFingerprint -RepositoryRoot $root
    Assert-ImportEngine ($before -ceq $after) 'preflight does not mutate website files'
} catch {
    $failures += "Unexpected test error: $($_.Exception.Message) [$($_.ScriptStackTrace)]"
}

if ($failures.Count) {
    Write-Output '------------------------------------------------------------'
    Write-Output 'IMPORT ENGINE SELF-TEST: FAIL'
    $failures | ForEach-Object { Write-Output "- $_" }
    exit $codes.ValidationFailure
}
Write-Output '------------------------------------------------------------'
Write-Output 'IMPORT ENGINE SELF-TEST: PASS'
exit $codes.Success
