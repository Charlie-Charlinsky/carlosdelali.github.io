[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\ContentPipeline.ps1')
$codes = Get-ContentPipelineExitCodes
$root = Get-ContentPipelineRepositoryRoot
$failures = New-Object System.Collections.Generic.List[string]

function Assert-Foundation {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { Write-Output "PASS: $Label" } else { $script:failures.Add($Label); Write-Output "FAIL: $Label" }
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("portfolio-content-pipeline-" + [Guid]::NewGuid().ToString('N'))
try {
    $before = Get-ContentTreeFingerprint -RepositoryRoot $root

    $first = Initialize-ContentWorkspace -RepositoryRoot $root
    $second = Initialize-ContentWorkspace -RepositoryRoot $root
    Assert-Foundation ($first.ManifestSchemaVersion -eq 1) 'bootstrap creates or validates schema v1 manifest'
    Assert-Foundation ($second.Created.Count -eq 0) 'bootstrap is idempotent'

    $paths = Get-ContentPipelinePaths -RepositoryRoot $root
    $realInboxFiles = @(Get-ChildItem -LiteralPath $paths.Inbox -File)
    $scan = Get-ContentInboxScan -RepositoryRoot $root
    Assert-Foundation ($scan.TotalDocx -eq $realInboxFiles.Count -and $scan.Counts.INVALID -eq 0) 'inbox scan accounts for every current DOCX'

    New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
    $config = Get-ContentPipelineConfig -RepositoryRoot $root
    $malformedRejected = $false
    try { ConvertTo-ContentSourceIdentity -FileName 'game-ea-sports-pga-tour.docx' -Config $config | Out-Null } catch { $malformedRejected = $true }
    Assert-Foundation $malformedRejected 'malformed filename is rejected'

    $fixture = Join-Path $temporaryRoot 'hash-fixture.docx'
    Write-Utf8NoBom -Path $fixture -Content 'deterministic fixture bytes'
    $hashA = Get-ContentFileSha256 -Path $fixture
    $hashB = Get-ContentFileSha256 -Path $fixture
    Assert-Foundation ($hashA -ceq $hashB -and $hashA.Length -eq 64) 'SHA-256 helper is deterministic'

    $acceptedHash = ('a' * 64)
    $changedHash = ('b' * 64)
    $statusManifest = [pscustomobject]@{
        schemaVersion = 1
        entries = [pscustomobject]@{
            'game:runbot' = [pscustomobject]@{ sha256 = $acceptedHash }
        }
    }
    Assert-Foundation ((Get-ContentHashStatus -Manifest $statusManifest -TargetKey 'game:new-game' -Sha256 $changedHash) -ceq 'NEW') 'manifest comparison detects NEW'
    Assert-Foundation ((Get-ContentHashStatus -Manifest $statusManifest -TargetKey 'game:runbot' -Sha256 $changedHash) -ceq 'CHANGED') 'manifest comparison detects CHANGED'
    Assert-Foundation ((Get-ContentHashStatus -Manifest $statusManifest -TargetKey 'game:runbot' -Sha256 $acceptedHash) -ceq 'UNCHANGED') 'manifest comparison detects UNCHANGED'

    $targets = @(
        'about__main__ES-EN.docx',
        'cv__main__ES-EN.docx',
        'game__ea-sports-pga-tour__ES-EN.docx',
        'project__project-1__ES-EN.docx',
        'writing__ecos-de-sangre__ES-EN.docx',
        'oniric-journal__2026-08-12__ES-EN.docx'
    )
    $resolved = @($targets | ForEach-Object {
        $identity = ConvertTo-ContentSourceIdentity -FileName $_ -Config $config
        Resolve-ContentPipelineTarget -Identity $identity -RepositoryRoot $root -Config $config
    })
    Assert-Foundation ($resolved.Count -eq 6) 'fixed pages and all registry families resolve'

    $unknownRejected = $false
    try {
        $identity = ConvertTo-ContentSourceIdentity -FileName 'game__does-not-exist__ES-EN.docx' -Config $config
        Resolve-ContentPipelineTarget -Identity $identity -RepositoryRoot $root -Config $config | Out-Null
    } catch { $unknownRejected = $true }
    Assert-Foundation $unknownRejected 'unknown registry target is rejected'

    $manifest = Read-ContentPipelineManifest -Path $paths.Manifest
    $manifestKeys = @($manifest.entries.PSObject.Properties | ForEach-Object Name)
    Assert-Foundation ($manifest.schemaVersion -eq 1 -and @($manifestKeys | Select-Object -Unique).Count -eq $manifestKeys.Count) 'versioned manifest parses with unique target keys'

    $duplicates = @(
        [pscustomobject]@{ TargetKey = 'game:runbot'; Status = 'NEW'; Reason = $null },
        [pscustomobject]@{ TargetKey = 'game:runbot'; Status = 'CHANGED'; Reason = $null }
    )
    Set-DuplicateTargetFailures -Results $duplicates | Out-Null
    Assert-Foundation (@($duplicates | Where-Object Status -eq 'INVALID').Count -eq 2) 'duplicate target validator rejects the complete duplicate set'

    $after = Get-ContentTreeFingerprint -RepositoryRoot $root
    Assert-Foundation ($before -ceq $after) 'scan leaves content, data, assets, CSS, and frontend JS unchanged'
} catch {
    $failures.Add("Unexpected test error: $($_.Exception.Message)")
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force }
}

if ($failures.Count -gt 0) {
    Write-Output '------------------------------------------------------------'
    Write-Output 'FOUNDATION SELF-TEST: FAIL'
    $failures | ForEach-Object { Write-Output "- $_" }
    exit $codes.ValidationFailure
}

Write-Output '------------------------------------------------------------'
Write-Output 'FOUNDATION SELF-TEST: PASS'
exit $codes.Success
