[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('PREPARE', 'SAVE-CONTENT', 'INTEGRATE-DEVELOP', 'PUBLISH-MAIN')]
    [string]$Mode,

    [switch]$Execute,
    [string[]]$ApprovedPath = @(),
    [string]$CommitMessage,
    [string]$ContentCheckpoint
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\ContentPipeline.ps1')
$codes = Get-ContentPipelineExitCodes
$root = Get-ContentPipelineRepositoryRoot

function Invoke-GitRead {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $output = @(& git -C $root @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $($output -join ' ')" }
    return ($output -join "`n").Trim()
}

function Invoke-GitWrite {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    if (-not $Execute) { throw 'Internal safety gate: Git write requested without -Execute.' }
    & git -C $root @Arguments
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed." }
}

function Assert-CleanTree {
    if (Invoke-GitRead status --porcelain) { throw 'Working tree must be clean.' }
}

function Assert-Branch {
    param([string]$Expected)
    $actual = Invoke-GitRead branch --show-current
    if ($actual -cne $Expected) { throw "Required branch is $Expected; current branch is $actual." }
}

function Get-AheadBehind {
    param([string]$Left, [string]$Right)
    $parts = (Invoke-GitRead rev-list --left-right --count "$Left...$Right") -split '\s+'
    return [pscustomobject]@{ LeftOnly = [int]$parts[0]; RightOnly = [int]$parts[1] }
}

function Assert-EqualRefs {
    param([string]$Left, [string]$Right, [string]$Label)
    $leftSha = Invoke-GitRead rev-parse $Left
    $rightSha = Invoke-GitRead rev-parse $Right
    if ($leftSha -cne $rightSha) { throw "$Label ($Left != $Right)." }
}

function Write-Plan {
    param([string[]]$Steps)
    Write-Output '============================================================'
    Write-Output "CONTENT GIT FLOW - $Mode"
    Write-Output '============================================================'
    Write-Output 'EXECUTION: PLAN ONLY'
    foreach ($step in $Steps) { Write-Output "- $step" }
    Write-Output 'No Git write executed.'
}

try {
    switch ($Mode) {
        'PREPARE' {
            Assert-Branch 'content'
            Assert-CleanTree
            Invoke-GitRead rev-parse --verify origin/content | Out-Null
            Invoke-GitRead rev-parse --verify origin/develop | Out-Null
            if (-not $Execute) {
                Write-Plan @(
                    'Require clean content branch.',
                    'Fetch origin.',
                    'Reject a behind or diverged content branch.',
                    'Merge origin/develop into content without discarding work.',
                    'Stop on conflicts.'
                )
                exit $codes.Success
            }
            Invoke-GitWrite fetch origin
            $contentState = Get-AheadBehind 'origin/content' 'content'
            if ($contentState.LeftOnly -gt 0) { throw 'content is behind or diverged from origin/content.' }
            Invoke-GitWrite merge --no-edit origin/develop
        }
        'SAVE-CONTENT' {
            Assert-Branch 'content'
            if ($ApprovedPath.Count -eq 0) { throw 'SAVE-CONTENT requires an exact -ApprovedPath list.' }
            if ([string]::IsNullOrWhiteSpace($CommitMessage)) { throw 'SAVE-CONTENT requires -CommitMessage.' }
            foreach ($path in $ApprovedPath) {
                if ([System.IO.Path]::IsPathRooted($path) -or $path -match '(^|[\\/])[.][.]([\\/]|$)') {
                    throw "Approved path must be repository-relative and cannot traverse parents: $path"
                }
            }
            if (-not $Execute) {
                Write-Plan @(
                    'Require the content branch.',
                    'Stage only the exact approved output paths.',
                    'Compare the staged path set with the approved path set.',
                    'Run staged-diff validation.',
                    'Commit and push origin/content.'
                )
                exit $codes.Success
            }
            Invoke-GitWrite add -- @ApprovedPath
            $staged = @((Invoke-GitRead diff --cached --name-only) -split "`n" | Where-Object { $_ }) | Sort-Object
            $approved = @($ApprovedPath | ForEach-Object { $_.Replace('\', '/') }) | Sort-Object
            if (($staged -join "`n") -cne ($approved -join "`n")) { throw 'Staged paths do not exactly match the approved output set.' }
            Invoke-GitRead diff --cached --check | Out-Null
            Invoke-GitWrite commit -m $CommitMessage
            Invoke-GitWrite push origin content
        }
        'INTEGRATE-DEVELOP' {
            Assert-Branch 'content'
            Assert-CleanTree
            if ([string]::IsNullOrWhiteSpace($ContentCheckpoint)) { throw 'INTEGRATE-DEVELOP requires -ContentCheckpoint.' }
            $actualCheckpoint = Invoke-GitRead rev-parse HEAD
            $requiredCheckpoint = Invoke-GitRead rev-parse $ContentCheckpoint
            if ($actualCheckpoint -cne $requiredCheckpoint) { throw 'HEAD is not the approved content checkpoint.' }
            if (-not $Execute) {
                Write-Plan @(
                    'Fetch origin and require the approved content checkpoint to be pushed.',
                    'Require local develop to equal origin/develop.',
                    'Switch safely to develop and integrate content.',
                    'Run full frontend QA.',
                    'Push origin/develop only after QA passes.'
                )
                exit $codes.Success
            }
            Invoke-GitWrite fetch origin
            Assert-EqualRefs 'content' 'origin/content' 'Approved content is not fully pushed'
            Assert-EqualRefs 'develop' 'origin/develop' 'Local develop differs from origin/develop'
            Invoke-GitWrite switch develop
            Invoke-GitWrite merge --no-edit $ContentCheckpoint
            & node (Join-Path $root 'tools\qa-frontend.mjs')
            if ($LASTEXITCODE -ne 0) { throw 'Frontend QA failed on develop; origin/develop was not pushed.' }
            Invoke-GitWrite push origin develop
        }
        'PUBLISH-MAIN' {
            Assert-CleanTree
            Assert-EqualRefs 'develop' 'origin/develop' 'Develop is not synchronized with origin/develop'
            Assert-EqualRefs 'main' 'origin/main' 'Release gate stopped: local main differs from origin/main'
            & git -C $root merge-base --is-ancestor content develop
            if ($LASTEXITCODE -ne 0) { throw 'Release gate stopped: content is not integrated into develop.' }
            if (-not $Execute) {
                Write-Plan @(
                    'Require explicit PUBLISH-MAIN invocation.',
                    'Fetch origin and repeat all release gates.',
                    'Require develop clean and equal to origin/develop.',
                    'Require main clean and equal to origin/main.',
                    'Run full QA before a fast-forward-only main integration.',
                    'Never force-push, reset, or rewrite history.'
                )
                exit $codes.Success
            }
            Invoke-GitWrite fetch origin
            Assert-EqualRefs 'develop' 'origin/develop' 'Develop changed during release preparation'
            Assert-EqualRefs 'main' 'origin/main' 'Main changed during release preparation'
            & node (Join-Path $root 'tools\qa-frontend.mjs')
            if ($LASTEXITCODE -ne 0) { throw 'Frontend QA failed on develop; main was not changed.' }
            Invoke-GitWrite switch main
            Invoke-GitWrite merge --ff-only develop
            & node (Join-Path $root 'tools\qa-frontend.mjs')
            if ($LASTEXITCODE -ne 0) { throw 'Frontend QA failed on main; origin/main was not pushed.' }
            Invoke-GitWrite push origin main
        }
    }
    Write-Output "STATUS: SUCCESS ($Mode)"
    exit $codes.Success
} catch {
    Write-Error $_.Exception.Message
    exit $codes.UserActionRequired
}
