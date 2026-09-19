param(
    [int]$Port = 8765,
    [switch]$OpenBrowser
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$prefix = "http://127.0.0.1:$Port/"
$mimeTypes = @{
    ".css" = "text/css; charset=utf-8"
    ".html" = "text/html; charset=utf-8"
    ".js" = "text/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".jpeg" = "image/jpeg"
    ".jpg" = "image/jpeg"
    ".pdf" = "application/pdf"
    ".png" = "image/png"
    ".svg" = "image/svg+xml"
    ".webm" = "video/webm"
    ".mp4" = "video/mp4"
}
$bufferSize = 64KB

function Get-SingleByteRange {
    param(
        [string]$Header,
        [long]$FileLength
    )

    if ([string]::IsNullOrWhiteSpace($Header)) {
        return [pscustomobject]@{ Requested = $false; Valid = $true; Start = [long]0; End = $FileLength - 1 }
    }
    if ($FileLength -le 0 -or $Header.Contains(",") -or $Header -notmatch '^bytes=(\d*)-(\d*)$') {
        return [pscustomobject]@{ Requested = $true; Valid = $false; Start = [long]0; End = [long]0 }
    }

    $startText = $Matches[1]
    $endText = $Matches[2]
    if (-not $startText -and -not $endText) {
        return [pscustomobject]@{ Requested = $true; Valid = $false; Start = [long]0; End = [long]0 }
    }

    [long]$start = 0
    [long]$end = $FileLength - 1
    if (-not $startText) {
        [long]$suffixLength = 0
        if (-not [long]::TryParse($endText, [ref]$suffixLength) -or $suffixLength -le 0) {
            return [pscustomobject]@{ Requested = $true; Valid = $false; Start = [long]0; End = [long]0 }
        }
        $start = [Math]::Max([long]0, $FileLength - $suffixLength)
    } else {
        if (-not [long]::TryParse($startText, [ref]$start) -or $start -lt 0 -or $start -ge $FileLength) {
            return [pscustomobject]@{ Requested = $true; Valid = $false; Start = [long]0; End = [long]0 }
        }
        if ($endText) {
            if (-not [long]::TryParse($endText, [ref]$end) -or $end -lt $start) {
                return [pscustomobject]@{ Requested = $true; Valid = $false; Start = [long]0; End = [long]0 }
            }
            $end = [Math]::Min($end, $FileLength - 1)
        }
    }

    return [pscustomobject]@{ Requested = $true; Valid = $true; Start = $start; End = $end }
}

function Write-ResponseChunk {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [byte[]]$Buffer,
        [int]$Count,
        [string]$RequestPath
    )

    try {
        $Response.OutputStream.Write($Buffer, 0, $Count)
        return $true
    } catch [System.Net.HttpListenerException], [System.IO.IOException], [System.ObjectDisposedException] {
        Write-Host "Client disconnected while receiving $RequestPath"
        return $false
    }
}

function Close-ResponseSafely {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$RequestPath
    )

    try {
        $Response.Close()
    } catch [System.Net.HttpListenerException], [System.IO.IOException], [System.ObjectDisposedException] {
        Write-Host "Client disconnected while closing $RequestPath"
    }
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host "Portfolio preview: $prefix"
Write-Host "Press Ctrl+C to stop."

if ($OpenBrowser) {
    Start-Process $prefix
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $relativePath = $null
        $fileStream = $null
        try {
            $relativePath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath).TrimStart("/")
            if ([string]::IsNullOrWhiteSpace($relativePath)) {
                $relativePath = "index.html"
            } elseif ($relativePath.EndsWith("/")) {
                $relativePath = Join-Path $relativePath "index.html"
            }

            $candidate = [System.IO.Path]::GetFullPath((Join-Path $root $relativePath))
            if (-not $candidate.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                $context.Response.StatusCode = 403
                continue
            }

            if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $context.Response.StatusCode = 404
                continue
            }

            $extension = [System.IO.Path]::GetExtension($candidate).ToLowerInvariant()
            $contentType = $mimeTypes[$extension]
            if (-not $contentType) {
                $contentType = "application/octet-stream"
            }

            $fileStream = [System.IO.FileStream]::new(
                $candidate,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::ReadWrite,
                $bufferSize,
                [System.IO.FileOptions]::SequentialScan
            )
            $fileLength = $fileStream.Length
            $range = Get-SingleByteRange -Header $context.Request.Headers["Range"] -FileLength $fileLength
            $context.Response.ContentType = $contentType
            $context.Response.Headers["Accept-Ranges"] = "bytes"

            if (-not $range.Valid) {
                $context.Response.StatusCode = 416
                $context.Response.Headers["Content-Range"] = "bytes */$fileLength"
                $context.Response.ContentLength64 = 0
                continue
            }

            $responseLength = if ($fileLength -eq 0) { [long]0 } else { $range.End - $range.Start + 1 }
            if ($range.Requested) {
                $context.Response.StatusCode = 206
                $context.Response.Headers["Content-Range"] = "bytes $($range.Start)-$($range.End)/$fileLength"
            } else {
                $context.Response.StatusCode = 200
            }
            $context.Response.ContentLength64 = $responseLength

            if ($context.Request.HttpMethod -ceq "HEAD" -or $responseLength -eq 0) {
                continue
            }

            $fileStream.Seek($range.Start, [System.IO.SeekOrigin]::Begin) | Out-Null
            $buffer = New-Object byte[] $bufferSize
            [long]$remaining = $responseLength
            while ($remaining -gt 0) {
                $readLength = [int][Math]::Min([long]$buffer.Length, $remaining)
                $read = $fileStream.Read($buffer, 0, $readLength)
                if ($read -le 0) { break }
                if (-not (Write-ResponseChunk -Response $context.Response -Buffer $buffer -Count $read -RequestPath $relativePath)) {
                    break
                }
                $remaining -= $read
            }
        } catch {
            Write-Error "Preview request failed for '$relativePath': $($_.Exception.Message)" -ErrorAction Continue
        } finally {
            if ($fileStream) { $fileStream.Dispose() }
            Close-ResponseSafely -Response $context.Response -RequestPath $relativePath
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
