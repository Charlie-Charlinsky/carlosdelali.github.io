Set-StrictMode -Version Latest

$script:ContentPipelineExitCodes = [ordered]@{
    Success = 0
    SuccessWithWarning = 1
    UserActionRequired = 2
    ConsultCortana = 3
    ValidationFailure = 4
    Fatal = 5
}

function Get-ContentPipelineExitCodes {
    return $script:ContentPipelineExitCodes
}

function Get-ContentPipelineRepositoryRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
}

function Get-ContentPipelineConfig {
    param([string]$RepositoryRoot = (Get-ContentPipelineRepositoryRoot))

    $path = Join-Path $RepositoryRoot "tools\content-pipeline\config\content-types.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Content Pipeline config not found: $path"
    }

    $config = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($config.schemaVersion -ne 1) {
        throw "Unsupported Content Pipeline config schema: $($config.schemaVersion)"
    }
    return $config
}

function Get-ContentPipelinePaths {
    param([string]$RepositoryRoot = (Get-ContentPipelineRepositoryRoot))

    $localRoot = Join-Path $RepositoryRoot "local-content"
    $stateRoot = Join-Path $localRoot "_content-pipeline"
    return [pscustomobject]@{
        RepositoryRoot = $RepositoryRoot
        LocalRoot = $localRoot
        Inbox = Join-Path $localRoot "inbox"
        Canonical = Join-Path $localRoot "canonical"
        Archive = Join-Path $localRoot "archive"
        State = $stateRoot
        Logs = Join-Path $stateRoot "logs"
        Reports = Join-Path $stateRoot "reports"
        Manifest = Join-Path $stateRoot "manifest.json"
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Test-LocalContentGitIgnored {
    param([string]$RepositoryRoot = (Get-ContentPipelineRepositoryRoot))

    & git -C $RepositoryRoot check-ignore --quiet -- "local-content/_content-pipeline-ignore-probe"
    return ($LASTEXITCODE -eq 0)
}

function Initialize-ContentWorkspace {
    param([string]$RepositoryRoot = (Get-ContentPipelineRepositoryRoot))

    if (-not (Test-LocalContentGitIgnored -RepositoryRoot $RepositoryRoot)) {
        throw "local-content/ is not ignored by Git. Refusing to create pipeline state."
    }

    $paths = Get-ContentPipelinePaths -RepositoryRoot $RepositoryRoot
    $created = New-Object System.Collections.Generic.List[string]
    foreach ($directory in @($paths.LocalRoot, $paths.Inbox, $paths.Canonical, $paths.Archive, $paths.State, $paths.Logs, $paths.Reports)) {
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            $created.Add($directory)
        }
    }

    if (-not (Test-Path -LiteralPath $paths.Manifest -PathType Leaf)) {
        $manifest = [ordered]@{ schemaVersion = 1; entries = [ordered]@{} }
        Write-Utf8NoBom -Path $paths.Manifest -Content (($manifest | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
        $created.Add($paths.Manifest)
    }

    $validatedManifest = Read-ContentPipelineManifest -Path $paths.Manifest
    return [pscustomobject]@{
        Paths = $paths
        Created = @($created)
        ManifestSchemaVersion = $validatedManifest.schemaVersion
    }
}

function Read-ContentPipelineManifest {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        $manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        throw "Invalid Content Pipeline manifest JSON: $Path ($($_.Exception.Message))"
    }
    if ($manifest.schemaVersion -ne 1 -or $null -eq $manifest.entries) {
        throw "Invalid Content Pipeline manifest schema: $Path"
    }
    return $manifest
}

function ConvertTo-ContentSourceIdentity {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [object]$Config = (Get-ContentPipelineConfig)
    )

    $match = [regex]::Match(
        $FileName,
        '^(?<type>[a-z0-9]+(?:-[a-z0-9]+)*)__(?<id>[a-z0-9]+(?:-[a-z0-9]+)*)__ES-EN[.]docx$',
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    if (-not $match.Success) {
        throw "Filename must match <content-type>__<content-id>__ES-EN.docx using lowercase safe slug/date characters."
    }

    $type = $match.Groups['type'].Value
    $id = $match.Groups['id'].Value
    if (@($Config.supportedTypes) -cnotcontains $type) {
        throw "Unsupported content type: $type"
    }

    return [pscustomobject]@{
        Type = $type
        Id = $id
        TargetKey = "${type}:$id"
        SourceFile = $FileName
    }
}

function Expand-ContentPipelineTemplate {
    param(
        [Parameter(Mandatory = $true)][string]$Template,
        [Parameter(Mandatory = $true)][string]$Id
    )
    return $Template.Replace('{id}', $Id).Replace('\', '/')
}

function Resolve-ContentPipelineTarget {
    param(
        [Parameter(Mandatory = $true)][object]$Identity,
        [string]$RepositoryRoot = (Get-ContentPipelineRepositoryRoot),
        [object]$Config = (Get-ContentPipelineConfig -RepositoryRoot $RepositoryRoot)
    )

    $typeProperty = $Config.contentTypes.PSObject.Properties[$Identity.Type]
    if ($null -eq $typeProperty) {
        throw "No resolver configuration exists for type: $($Identity.Type)"
    }
    $typeConfig = $typeProperty.Value

    $resolved = $false
    if (@($typeConfig.fixedIds).Count -gt 0) {
        $resolved = @($typeConfig.fixedIds) -ccontains $Identity.Id
    } elseif ($null -ne $typeConfig.registry) {
        $registryPath = Join-Path $RepositoryRoot ($typeConfig.registry.path.Replace('/', '\'))
        if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
            throw "Target registry not found: $($typeConfig.registry.path)"
        }
        $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
        $collectionProperty = $registry.PSObject.Properties[$typeConfig.registry.collection]
        if ($null -eq $collectionProperty) {
            throw "Registry collection not found: $($typeConfig.registry.collection)"
        }
        $idField = [string]$typeConfig.registry.idField
        $resolved = $null -ne @($collectionProperty.Value | Where-Object { [string]$_.$idField -ceq $Identity.Id })[0]
    }

    if (-not $resolved) {
        throw "Unknown target: $($Identity.TargetKey)"
    }

    $outputs = @($typeConfig.publicOutputs | ForEach-Object { Expand-ContentPipelineTemplate -Template $_ -Id $Identity.Id })
    return [pscustomobject]@{
        Type = $Identity.Type
        Id = $Identity.Id
        TargetKey = $Identity.TargetKey
        SourceFile = $Identity.SourceFile
        CanonicalFile = "local-content/canonical/$($Identity.Type)/$($Identity.Id)/content.docx"
        ArchiveDirectory = "local-content/archive/$($Identity.Type)/$($Identity.Id)"
        MirrorFile = Expand-ContentPipelineTemplate -Template $typeConfig.mirror -Id $Identity.Id
        Outputs = $outputs
        DocxOwnedFields = @($typeConfig.docxOwnedFields)
        ProtectedFields = @($typeConfig.protectedFields)
    }
}

function Get-ContentFileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ContentManifestEntry {
    param(
        [Parameter(Mandatory = $true)][object]$Manifest,
        [Parameter(Mandatory = $true)][string]$TargetKey
    )
    $property = $Manifest.entries.PSObject.Properties[$TargetKey]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-ContentHashStatus {
    param(
        [Parameter(Mandatory = $true)][object]$Manifest,
        [Parameter(Mandatory = $true)][string]$TargetKey,
        [Parameter(Mandatory = $true)][ValidatePattern('^[a-f0-9]{64}$')][string]$Sha256
    )

    $accepted = Get-ContentManifestEntry -Manifest $Manifest -TargetKey $TargetKey
    if ($null -eq $accepted) { return 'NEW' }
    if ([string]$accepted.sha256 -ceq $Sha256) { return 'UNCHANGED' }
    return 'CHANGED'
}

function Set-DuplicateTargetFailures {
    param([Parameter(Mandatory = $true)][object[]]$Results)

    $groups = @($Results | Where-Object { $_.Status -ne 'INVALID' -and $_.TargetKey } | Group-Object TargetKey | Where-Object Count -gt 1)
    foreach ($group in $groups) {
        foreach ($result in $group.Group) {
            $result.Status = 'INVALID'
            $result.Reason = "Duplicate inbox target: $($group.Name)"
        }
    }
    return $Results
}

function Get-ContentInboxScan {
    param([string]$RepositoryRoot = (Get-ContentPipelineRepositoryRoot))

    $workspace = Initialize-ContentWorkspace -RepositoryRoot $RepositoryRoot
    $config = Get-ContentPipelineConfig -RepositoryRoot $RepositoryRoot
    $manifest = Read-ContentPipelineManifest -Path $workspace.Paths.Manifest
    $results = New-Object System.Collections.Generic.List[object]

    $files = @(Get-ChildItem -LiteralPath $workspace.Paths.Inbox -File | Where-Object { $_.Extension -ieq '.docx' } | Sort-Object Name)
    foreach ($file in $files) {
        $result = [pscustomobject][ordered]@{
            TargetKey = $null
            Status = 'INVALID'
            Source = $file.Name
            Sha256 = $null
            CanonicalFile = $null
            Outputs = @()
            Reason = $null
        }
        try {
            $identity = ConvertTo-ContentSourceIdentity -FileName $file.Name -Config $config
            $target = Resolve-ContentPipelineTarget -Identity $identity -RepositoryRoot $RepositoryRoot -Config $config
            $hash = Get-ContentFileSha256 -Path $file.FullName
            $status = Get-ContentHashStatus -Manifest $manifest -TargetKey $target.TargetKey -Sha256 $hash

            $result.TargetKey = $target.TargetKey
            $result.Status = $status
            $result.Sha256 = $hash
            $result.CanonicalFile = $target.CanonicalFile
            $result.Outputs = @($target.Outputs)
        } catch {
            $result.Reason = $_.Exception.Message
        }
        $results.Add($result)
    }

    $finalResults = @()
    if ($results.Count -gt 0) {
        $resultArray = @($results | ForEach-Object { $_ })
        $finalResults = @(Set-DuplicateTargetFailures -Results $resultArray | Sort-Object @{ Expression = { if ($_.TargetKey) { $_.TargetKey } else { '~' + $_.Source } } }, Source)
    }
    $counts = [ordered]@{ NEW = 0; CHANGED = 0; UNCHANGED = 0; INVALID = 0 }
    foreach ($result in $finalResults) { $counts[$result.Status]++ }
    return [pscustomobject][ordered]@{
        SchemaVersion = 1
        TotalDocx = $files.Count
        Counts = [pscustomobject]$counts
        Entries = $finalResults
        WebsiteFilesModified = $false
    }
}

function Write-ContentInboxScanReport {
    param(
        [Parameter(Mandatory = $true)][object]$Scan,
        [Parameter(Mandatory = $true)][string]$Path
    )
    Write-Utf8NoBom -Path $Path -Content (($Scan | ConvertTo-Json -Depth 10) + [Environment]::NewLine)
}

function Get-ContentTreeFingerprint {
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [string[]]$RelativeDirectories = @('content', 'data', 'assets', 'css', 'js')
    )

    $lines = foreach ($relativeDirectory in $RelativeDirectories) {
        $directory = Join-Path $RepositoryRoot $relativeDirectory
        if (Test-Path -LiteralPath $directory -PathType Container) {
            Get-ChildItem -LiteralPath $directory -Recurse -File | Sort-Object FullName | ForEach-Object {
                $relative = $_.FullName.Substring($RepositoryRoot.Length).TrimStart('\').Replace('\', '/')
                "$relative|$(Get-ContentFileSha256 -Path $_.FullName)"
            }
        }
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
}
