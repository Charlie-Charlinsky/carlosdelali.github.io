[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\ContentPipeline.ps1')
$codes = Get-ContentPipelineExitCodes

try {
    $result = Initialize-ContentWorkspace
    Write-Output '============================================================'
    Write-Output 'CONTENT PIPELINE - WORKSPACE BOOTSTRAP'
    Write-Output '============================================================'
    Write-Output "CREATED: $($result.Created.Count)"
    foreach ($path in $result.Created) { Write-Output "  $path" }
    Write-Output "MANIFEST SCHEMA: $($result.ManifestSchemaVersion)"
    Write-Output 'LOCAL-CONTENT GIT IGNORED: YES'
    Write-Output 'STATUS: SUCCESS'
    exit $codes.Success
} catch {
    Write-Error $_.Exception.Message
    exit $codes.Fatal
}
