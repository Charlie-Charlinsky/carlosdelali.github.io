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

function New-TestParagraph {
    param(
        [string]$Text,
        $NumberId = $null,
        $ListLevel = $null,
        $ListFormat = $null,
        [string]$Style = 'Normal',
        [int]$ParagraphIndex = 0
    )
    return [pscustomobject][ordered]@{
        Kind = 'paragraph'
        ParagraphIndex = $ParagraphIndex
        Style = $Style
        Text = $Text
        Runs = @([pscustomobject]@{ Text = $Text; Bold = $false; Italic = $false; Url = $null })
        NumberId = $NumberId
        ListLevel = $ListLevel
        ListFormat = $ListFormat
    }
}

function Invoke-ListFixture {
    param([object[]]$Paragraphs)
    $html = New-HtmlDocument -AttributeName 'data-test' -AttributeValue 'lists'
    $signature = @(Add-ParagraphSequence -Document $html.Document -Parent $html.Article -Paragraphs $Paragraphs -Target 'test:fixture' -Language 'test')
    return [pscustomobject]@{ Document = $html.Document; Html = ConvertTo-SemanticHtml $html.Document; Signature = ($signature -join '|') }
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

    $flatUl = Invoke-ListFixture @(
        (New-TestParagraph 'Alpha' '1' 0 'bullet' -ParagraphIndex 1),
        (New-TestParagraph 'Beta' '1' 0 'bullet' -ParagraphIndex 2)
    )
    Assert-ImportEngine ($flatUl.Signature -ceq 'ul[li,li]') 'flat unordered list topology'
    Assert-ImportEngine ($flatUl.Html -match '<ul>' -and $flatUl.Html -notmatch '<ol>') 'flat unordered list renders ul'

    $flatOl = Invoke-ListFixture @(
        (New-TestParagraph 'First' '2' 0 'decimal' -ParagraphIndex 3),
        (New-TestParagraph 'Second' '2' 0 'decimal' -ParagraphIndex 4)
    )
    Assert-ImportEngine ($flatOl.Signature -ceq 'ol[li,li]') 'flat ordered list topology'

    $nestedUl = Invoke-ListFixture @(
        (New-TestParagraph 'Parent' '3' 0 'bullet' -ParagraphIndex 5),
        (New-TestParagraph 'Child A' '3' 1 'bullet' -ParagraphIndex 6),
        (New-TestParagraph 'Child B' '3' 1 'bullet' -ParagraphIndex 7),
        (New-TestParagraph 'Sibling' '3' 0 'bullet' -ParagraphIndex 8)
    )
    Assert-ImportEngine ($nestedUl.Signature -ceq 'ul[li[ul[li,li]],li]') 'unordered nested 0 to 1'
    Assert-ImportEngine ($nestedUl.Document.SelectNodes('/article/ul/li/ul').Count -eq 1) 'nested list is owned by its parent li'
    Assert-ImportEngine ($nestedUl.Document.SelectNodes('//ul/ul | //ul/ol | //ol/ul | //ol/ol').Count -eq 0) 'no list is nested directly inside another list'

    $threeLevels = Invoke-ListFixture @(
        (New-TestParagraph 'Parent' '4' 0 'bullet' -ParagraphIndex 9),
        (New-TestParagraph 'Child' '4' 1 'bullet' -ParagraphIndex 10),
        (New-TestParagraph 'Grandchild' '4' 2 'bullet' -ParagraphIndex 11)
    )
    Assert-ImportEngine ($threeLevels.Signature -ceq 'ul[li[ul[li[ul[li]]]]]') 'unordered nested 0 to 1 to 2'

    $decrease = Invoke-ListFixture @(
        (New-TestParagraph 'L0 A' '5' 0 'bullet' -ParagraphIndex 12),
        (New-TestParagraph 'L1 A' '5' 1 'bullet' -ParagraphIndex 13),
        (New-TestParagraph 'L2' '5' 2 'bullet' -ParagraphIndex 14),
        (New-TestParagraph 'L1 B' '5' 1 'bullet' -ParagraphIndex 15),
        (New-TestParagraph 'L0 B' '5' 0 'bullet' -ParagraphIndex 16)
    )
    Assert-ImportEngine ($decrease.Signature -ceq 'ul[li[ul[li[ul[li]],li]],li]') 'list level decrease 2 to 1 to 0'

    $paragraphBoundary = @(
        (New-TestParagraph 'List item' '6' 0 'bullet' -ParagraphIndex 17),
        (New-TestParagraph 'Normal paragraph' -ParagraphIndex 18)
    )
    $boundaryHtml = New-HtmlDocument -AttributeName 'data-test' -AttributeValue 'paragraph-boundary'
    $paragraphResult = Add-HierarchicalListSequence -Document $boundaryHtml.Document -Parent $boundaryHtml.Article -Paragraphs $paragraphBoundary -StartIndex 0 -Target 'test:boundary' -Language 'es'
    Assert-ImportEngine ($paragraphResult.NextIndex -eq 1 -and $paragraphBoundary[$paragraphResult.NextIndex].Style -eq 'Normal') 'normal paragraph terminates list sequence'

    $headingBoundary = @(
        (New-TestParagraph 'List item' '7' 0 'bullet' -ParagraphIndex 19),
        (New-TestParagraph 'Heading' -Style 'Heading2' -ParagraphIndex 20)
    )
    $headingHtml = New-HtmlDocument -AttributeName 'data-test' -AttributeValue 'heading-boundary'
    $headingResult = Add-HierarchicalListSequence -Document $headingHtml.Document -Parent $headingHtml.Article -Paragraphs $headingBoundary -StartIndex 0 -Target 'test:boundary' -Language 'en'
    Assert-ImportEngine ($headingResult.NextIndex -eq 1 -and $headingBoundary[$headingResult.NextIndex].Style -eq 'Heading2') 'heading terminates list sequence'

    $numberBoundary = Invoke-ListFixture @(
        (New-TestParagraph 'First list' '8' 0 'bullet' -ParagraphIndex 21),
        (New-TestParagraph 'Second list' '9' 0 'bullet' -ParagraphIndex 22)
    )
    Assert-ImportEngine ($numberBoundary.Signature -ceq 'ul[li]|ul[li]' -and $numberBoundary.Document.SelectNodes('/article/ul').Count -eq 2) 'numbering ID change creates a list boundary'

    $nestedOl = Invoke-ListFixture @(
        (New-TestParagraph 'Ordered parent' '10' 0 'decimal' -ParagraphIndex 23),
        (New-TestParagraph 'Ordered child' '10' 1 'lowerLetter' -ParagraphIndex 24)
    )
    Assert-ImportEngine ($nestedOl.Signature -ceq 'ol[li[ol[li]]]') 'ordered nested list'

    $mixed = Invoke-ListFixture @(
        (New-TestParagraph 'Bullet parent' '11' 0 'bullet' -ParagraphIndex 25),
        (New-TestParagraph 'Numbered child' '12' 1 'decimal' -ParagraphIndex 26)
    )
    Assert-ImportEngine ($mixed.Signature -ceq 'ul[li[ol[li]]]') 'mixed unordered and ordered nesting'

    $invalidRejected = $false
    try {
        [void](Invoke-ListFixture @(
            (New-TestParagraph 'Parent' '13' 0 'bullet' -ParagraphIndex 27),
            (New-TestParagraph 'Skipped level' '13' 2 'bullet' -ParagraphIndex 28)
        ))
    } catch {
        $invalidRejected = $_.Exception.Message -match 'INVALID_LIST_HIERARCHY' -and $_.Exception.Message -match 'paragraph=28' -and $_.Exception.Message -match 'previousLevel=0 requestedLevel=2'
    }
    Assert-ImportEngine $invalidRejected 'invalid list jump 0 to 2 is rejected with context'

    $topologyEs = (Invoke-ListFixture @(
        (New-TestParagraph 'Padre' '14' 0 'bullet'),
        (New-TestParagraph 'Hijo' '14' 1 'bullet')
    )).Signature
    $topologyEn = (Invoke-ListFixture @(
        (New-TestParagraph 'Parent' '99' 0 'bullet'),
        (New-TestParagraph 'Child' '99' 1 'bullet')
    )).Signature
    $flatTopology = (Invoke-ListFixture @(
        (New-TestParagraph 'Parent' '100' 0 'bullet'),
        (New-TestParagraph 'Child' '100' 0 'bullet')
    )).Signature
    Assert-ImportEngine ($topologyEs -ceq $topologyEn) 'ES/EN equivalent list topology passes independently of numbering IDs'
    Assert-ImportEngine ($topologyEs -cne $flatTopology) 'ES/EN different list topology fails comparison'

    $escaped = Invoke-ListFixture @((New-TestParagraph '<authored & text>' '15' 0 'bullet'))
    Assert-ImportEngine ($escaped.Html -match '&lt;authored &amp; text&gt;' -and $escaped.Html -notmatch '<authored') 'list text is HTML-escaped'
    try { [void][xml]$threeLevels.Html; $nestedHtmlValid = $true } catch { $nestedHtmlValid = $false }
    Assert-ImportEngine $nestedHtmlValid 'nested list HTML is well-formed and balanced'

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
    Assert-ImportEngine ($cv.Status -in @('CHANGED', 'UNCHANGED')) 'current CV has a valid import scan state'
    foreach ($relative in @('content/cv/es.html', 'content/cv/en.html')) {
        $generatedCv = [xml]$cv.Outputs[$relative]
        Assert-ImportEngine ($generatedCv.SelectNodes('/article/section[@id="work-experience"]/section/ul/li/ul').Count -gt 0) "$relative contains semantic nested Professional Experience lists"
    }
    $cvDocument = Split-BilingualDocx (Read-DocxDocument -Path (Join-Path $root 'local-content\inbox\cv__main__ES-EN.docx'))
    $cvEs = Convert-CvLanguage -Paragraphs $cvDocument.es -Language 'es' -CurrentHtmlPath (Join-Path $root 'content\cv\es.html') -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.cv
    $cvEn = Convert-CvLanguage -Paragraphs $cvDocument.en -Language 'en' -CurrentHtmlPath (Join-Path $root 'content\cv\en.html') -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.cv
    Assert-ImportEngine ($cvEs.Structure -ceq $cvEn.Structure) 'current CV ES/EN list topology parity'
    Assert-ImportEngine ((@($cvEs.Ludography | ForEach-Object Games | ForEach-Object { $_ }) -join '|') -ceq (@($cvEn.Ludography | ForEach-Object Games | ForEach-Object { $_ }) -join '|')) 'CV Ludography ordering remains bilingual and unchanged'
    $cvSchema = (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.cv
    foreach ($language in @('es', 'en')) {
        $parsedSections = Split-TopSections -Paragraphs @($cvDocument.$language) -LabelMap $cvSchema.sections.$language -Language $language
        $ludographyLists = @($parsedSections | Where-Object Id -eq 'ludography' | ForEach-Object Items | Where-Object { $null -ne $_.NumberId })
        Assert-ImportEngine ($ludographyLists.Count -gt 0 -and @($ludographyLists | Where-Object { $_.ListFormat -eq 'bullet' -or $_.ListLevel -notin @($null, 0) }).Count -eq 0) "CV $language Ludography remains a flat ordered list"
    }
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
