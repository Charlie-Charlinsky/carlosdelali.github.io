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
        [int]$ParagraphIndex = 0,
        [string]$Url = $null
    )
    return [pscustomobject][ordered]@{
        Kind = 'paragraph'
        ParagraphIndex = $ParagraphIndex
        Style = $Style
        Text = $Text
        Runs = @([pscustomobject]@{ Text = $Text; Bold = $false; Italic = $false; Url = $Url })
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

function Invoke-GameFixture {
    param([object[]]$EditorialParagraphs, [string]$Language = 'en', [string]$GameId = 'fixture-game')
    $paragraphs = @((New-TestParagraph 'Fixture Game' -Style 'Heading1')) + @($EditorialParagraphs)
    $schema = (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
    return Convert-GameLanguage -Paragraphs $paragraphs -Language $Language -GameId $GameId -Schema $schema
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

    $flatGame = Invoke-GameFixture @(
        (New-TestParagraph 'Overview fixture' -Style 'Heading2'),
        (New-TestParagraph 'Overview body'),
        (New-TestParagraph 'Contribution fixture' -Style 'Heading2'),
        (New-TestParagraph 'Contribution body')
    )
    $flatGameXml = [xml]$flatGame.Html
    Assert-ImportEngine ($flatGame.Title -ceq 'Fixture Game') 'valid Game Heading 1 fixture resolves its title'
    Assert-ImportEngine ($flatGameXml.SelectNodes('/article/section/h2').Count -eq 2 -and $flatGameXml.SelectNodes('//h3').Count -eq 0) 'A. Heading 2 main sections compile as h2'

    $missingTitleRejected = $false
    try {
        [void](Convert-GameLanguage -Paragraphs @(
            (New-TestParagraph 'Overview fixture' -Style 'Heading2'),
            (New-TestParagraph 'Overview body')
        ) -Language 'es' -GameId 'missing-title' -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game)
    } catch {
        $missingTitleRejected = $_.Exception.Message -ceq 'Game es title is missing.'
    }
    Assert-ImportEngine $missingTitleRejected 'missing Game Heading 1 title remains rejected'

    $localizedStylesXml = [xml]'<?xml version="1.0"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:styleId="Ttulo1"><w:name w:val="heading 1" /></w:style><w:style w:type="paragraph" w:styleId="LocalizedChild"><w:name w:val="Localized Child" /><w:basedOn w:val="Ttulo1" /></w:style></w:styles>'
    $localizedStyleMap = Get-WordParagraphStyleMap -StylesXml $localizedStylesXml
    Assert-ImportEngine ($localizedStyleMap['Ttulo1'] -ceq 'Heading1' -and $localizedStyleMap['LocalizedChild'] -ceq 'Heading1') 'Open XML style declarations resolve localized and based-on Heading 1 styles'
    $localizedGameDocument = Split-BilingualDocx (Read-DocxDocument -Path (Join-Path $root 'local-content\inbox\game__a-night-with-cleo__ES-EN.docx'))
    Assert-ImportEngine ($localizedGameDocument.es[0].Style -ceq 'Heading1' -and $localizedGameDocument.en[0].Style -ceq 'Heading1') 'real localized Game title styles normalize to Heading 1'

    $singleSubsectionGame = Invoke-GameFixture @(
        (New-TestParagraph 'Overview fixture' -Style 'Heading2'),
        (New-TestParagraph 'Overview body'),
        (New-TestParagraph 'Contribution fixture' -Style 'Heading2'),
        (New-TestParagraph 'Child fixture' -Style 'Heading3'),
        (New-TestParagraph 'Child body')
    )
    $singleSubsectionXml = [xml]$singleSubsectionGame.Html
    Assert-ImportEngine ($singleSubsectionXml.SelectNodes('/article/section/section/h3').Count -eq 1 -and $singleSubsectionGame.HeadingTopology -ceq 'h2[]|h2[h3]') 'B. Heading 2 to Heading 3 topology is preserved'

    $schemaSubsectionGame = Invoke-GameFixture @(
        (New-TestParagraph 'Overview fixture' -Style 'Heading2'),
        (New-TestParagraph 'Overview body'),
        (New-TestParagraph 'Main Features'),
        (New-TestParagraph 'Feature summary')
    )
    $schemaSubsectionXml = [xml]$schemaSubsectionGame.Html
    Assert-ImportEngine ($schemaSubsectionXml.SelectNodes('/article/section[@id="overview"]/section[@id="main-features"]/h3[text()="Main Features"]').Count -eq 1) 'C. schema Main Features Normal paragraph compiles as h3'
    Assert-ImportEngine ($schemaSubsectionXml.SelectNodes('/article/section[@id="overview"]/section[@id="main-features"]/p[text()="Feature summary"]').Count -eq 1) 'D. content after schema Main Features remains normal semantic content'
    Assert-ImportEngine ((@($schemaSubsectionXml.SelectNodes('/article/section[@id="overview"]/*') | ForEach-Object Name) -join '|') -ceq 'h2|p|section') 'E. schema Main Features remains beneath the preceding h2 section'

    $contributionSubsections = Invoke-GameFixture @(
        (New-TestParagraph 'Overview fixture' -Style 'Heading2'),
        (New-TestParagraph 'Overview body'),
        (New-TestParagraph 'Contribution fixture' -Style 'Heading2'),
        (New-TestParagraph 'The Shop'),
        (New-TestParagraph 'Shop body'),
        (New-TestParagraph 'The Races'),
        (New-TestParagraph 'Races body')
    )
    $contributionSubsectionsXml = [xml]$contributionSubsections.Html
    Assert-ImportEngine ($contributionSubsections.HeadingTopology -ceq 'h2[]|h2[h3,h3]' -and $contributionSubsectionsXml.SelectNodes('/article/section[@id="contribution"]/section/h3').Count -eq 2) 'schema Contribution Normal paragraphs compile as sibling h3 subsections'
    Assert-ImportEngine ($contributionSubsectionsXml.SelectNodes('/article/section[@id="contribution"]/section[@id="shop"]/p[text()="Shop body"]').Count -eq 1 -and $contributionSubsectionsXml.SelectNodes('/article/section[@id="contribution"]/section[@id="races"]/p[text()="Races body"]').Count -eq 1) 'schema Contribution subsections own their following prose'

    $contributionSpanish = Invoke-GameFixture @(
        (New-TestParagraph 'Seccion principal' -Style 'Heading2'),
        (New-TestParagraph 'Texto'),
        (New-TestParagraph 'Contribucion' -Style 'Heading2'),
        (New-TestParagraph 'La tienda'),
        (New-TestParagraph 'Texto de tienda'),
        (New-TestParagraph 'Las carreras'),
        (New-TestParagraph 'Texto de carreras')
    ) -Language 'es'
    Assert-GameParity -Spanish $contributionSpanish -English $contributionSubsections
    Assert-ImportEngine ($contributionSpanish.HeadingTopology -ceq $contributionSubsections.HeadingTopology) 'ES/EN schema Contribution topology parity passes independently of wording'

    $schemaSpanish = Invoke-GameFixture @(
        (New-TestParagraph 'Seccion principal' -Style 'Heading2'),
        (New-TestParagraph 'Texto'),
        (New-TestParagraph 'Main Features'),
        (New-TestParagraph 'Resumen')
    ) -Language 'es'
    Assert-GameParity -Spanish $schemaSpanish -English $schemaSubsectionGame
    Assert-ImportEngine ($schemaSpanish.HeadingTopology -ceq 'h2[h3]' -and $schemaSpanish.HeadingTopology -ceq $schemaSubsectionGame.HeadingTopology) 'F. schema Main Features ES/EN h2 to h3 topology matches'
    $contributionMismatchRejected = $false
    try { Assert-GameParity -Spanish $schemaSpanish -English $contributionSubsections } catch { $contributionMismatchRejected = $_.Exception.Message -match 'semantic structures are not equivalent' }
    Assert-ImportEngine $contributionMismatchRejected 'ES/EN mismatched schema Contribution h3 count fails parity'

    $coexistingSubsections = Invoke-GameFixture @(
        (New-TestParagraph 'Overview fixture' -Style 'Heading2'),
        (New-TestParagraph 'Authored child' -Style 'Heading3'),
        (New-TestParagraph 'Authored child body'),
        (New-TestParagraph 'Main Features'),
        (New-TestParagraph 'Feature summary')
    )
    Assert-ImportEngine ($coexistingSubsections.HeadingTopology -ceq 'h2[h3,h3]') 'real Heading 3 and schema Main Features coexist'

    $arbitraryNormal = Invoke-GameFixture @(
        (New-TestParagraph 'Overview fixture' -Style 'Heading2'),
        (New-TestParagraph 'Short Label'),
        (New-TestParagraph 'Contribution fixture' -Style 'Heading2'),
        (New-TestParagraph 'Contribution body')
    )
    Assert-ImportEngine (([xml]$arbitraryNormal.Html).SelectNodes('//h3').Count -eq 0) 'H. arbitrary Normal paragraphs are not promoted to h3'
    $boldNormalParagraph = New-TestParagraph 'Bold Normal prose'
    $boldNormalParagraph.Runs[0].Bold = $true
    $boldNormal = Invoke-GameFixture @(
        (New-TestParagraph 'Overview fixture' -Style 'Heading2'),
        $boldNormalParagraph
    )
    Assert-ImportEngine (([xml]$boldNormal.Html).SelectNodes('//h3').Count -eq 0) 'bold Normal prose is not promoted to h3'
    $importEngineSource = Get-Content -LiteralPath (Join-Path $root 'tools\content-pipeline\lib\ImportEngine.ps1') -Raw -Encoding UTF8
    Assert-ImportEngine ($importEngineSource -notmatch 'w:sz|font-size|FontSize') 'I. heading levels do not use Word font or size inspection'

    $multipleSubsectionGame = Invoke-GameFixture @(
        (New-TestParagraph 'Overview fixture' -Style 'Heading2'),
        (New-TestParagraph 'Overview body'),
        (New-TestParagraph 'Contribution fixture' -Style 'Heading2'),
        (New-TestParagraph 'First child' -Style 'Heading3'),
        (New-TestParagraph 'First body'),
        (New-TestParagraph 'Second child' -Style 'Heading3'),
        (New-TestParagraph 'Second body')
    )
    $multipleSubsectionXml = [xml]$multipleSubsectionGame.Html
    Assert-ImportEngine ($multipleSubsectionXml.SelectNodes('/article/section/section/h3').Count -eq 2 -and $multipleSubsectionGame.HeadingTopology -ceq 'h2[]|h2[h3,h3]') 'C. multiple Heading 3 siblings remain siblings'

    $subsectionListGame = Invoke-GameFixture @(
        (New-TestParagraph 'Overview fixture' -Style 'Heading2'),
        (New-TestParagraph 'Overview body'),
        (New-TestParagraph 'Contribution fixture' -Style 'Heading2'),
        (New-TestParagraph 'Child with list' -Style 'Heading3'),
        (New-TestParagraph 'Lead paragraph'),
        (New-TestParagraph 'List parent' '201' 0 'bullet'),
        (New-TestParagraph 'Nested item' '201' 1 'bullet')
    )
    $subsectionListXml = [xml]$subsectionListGame.Html
    Assert-ImportEngine ($subsectionListXml.SelectNodes('/article/section/section[h3]/p').Count -eq 1 -and $subsectionListXml.SelectNodes('/article/section/section[h3]/ul/li/ul/li').Count -eq 1) 'D. Heading 3 owns following paragraphs and nested lists'

    $equivalentSpanish = Invoke-GameFixture @(
        (New-TestParagraph 'Seccion principal' -Style 'Heading2'),
        (New-TestParagraph 'Texto'),
        (New-TestParagraph 'Contribucion' -Style 'Heading2'),
        (New-TestParagraph 'Hijo traducido' -Style 'Heading3'),
        (New-TestParagraph 'Texto')
    ) -Language 'es'
    Assert-GameParity -Spanish $equivalentSpanish -English $singleSubsectionGame
    Assert-ImportEngine ($equivalentSpanish.HeadingTopology -ceq $singleSubsectionGame.HeadingTopology) 'E. ES/EN equivalent heading topology passes without comparing wording'

    $differentTopologyRejected = $false
    try { Assert-GameParity -Spanish $equivalentSpanish -English $multipleSubsectionGame } catch { $differentTopologyRejected = $_.Exception.Message -match 'semantic structures are not equivalent' }
    Assert-ImportEngine $differentTopologyRejected 'F. ES/EN different heading topology fails'

    $accessTarget = 'https://example.com/authored-game'
    $accessSpanish = Invoke-GameFixture @(
        (New-TestParagraph 'Acceso' -Style 'Heading2'),
        (New-TestParagraph $accessTarget),
        (New-TestParagraph 'El Juego' -Style 'Heading2'),
        (New-TestParagraph 'Texto')
    ) -Language 'es'
    $accessEnglish = Invoke-GameFixture @(
        (New-TestParagraph 'Access' -Style 'Heading2'),
        (New-TestParagraph $accessTarget -Url $accessTarget),
        (New-TestParagraph 'The Game' -Style 'Heading2'),
        (New-TestParagraph 'Text')
    )
    Assert-GameParity -Spanish $accessSpanish -English $accessEnglish
    Assert-ImportEngine ((Get-GameAccessTarget $accessSpanish.Metadata.access) -ceq $accessTarget -and (Get-GameAccessTarget $accessEnglish.Metadata.access) -ceq $accessTarget) 'Access parity resolves an authored relationship or identical safe visible URL'
    $differentAccessEnglish = Invoke-GameFixture @(
        (New-TestParagraph 'Access' -Style 'Heading2'),
        (New-TestParagraph $accessTarget -Url 'https://example.com/different-target'),
        (New-TestParagraph 'The Game' -Style 'Heading2'),
        (New-TestParagraph 'Text')
    )
    $differentAccessRejected = $false
    try { Assert-GameParity -Spanish $accessSpanish -English $differentAccessEnglish } catch { $differentAccessRejected = $_.Exception.Message -match 'metadata URLs differ for access' }
    Assert-ImportEngine $differentAccessRejected 'different authored Access hyperlink targets fail parity'

    $splitLinkParagraph = New-TestParagraph 'Download CV'
    $splitLinkParagraph.Runs = @(
        [pscustomobject]@{ Text = 'Download'; Bold = $true; Italic = $false; Url = 'https://example.com/cv.pdf' },
        [pscustomobject]@{ Text = ' CV'; Bold = $true; Italic = $false; Url = 'https://example.com/cv.pdf' }
    )
    $splitLink = Get-OnlyDocxLink -Paragraphs @($splitLinkParagraph) -Context 'CV Downloads fixture'
    Assert-ImportEngine ($splitLink.Text -ceq 'Download CV' -and $splitLink.Url -ceq 'https://example.com/cv.pdf') 'one DOCX hyperlink split across runs remains one semantic link'
    $differentTargetParagraph = New-TestParagraph 'Download CV'
    $differentTargetParagraph.Runs = @(
        [pscustomobject]@{ Text = 'Download'; Bold = $true; Italic = $false; Url = 'https://example.com/cv.pdf' },
        [pscustomobject]@{ Text = ' CV'; Bold = $true; Italic = $false; Url = 'https://example.com/other.pdf' }
    )
    $multipleLinkTargetsRejected = $false
    try { [void](Get-OnlyDocxLink -Paragraphs @($differentTargetParagraph) -Context 'CV Downloads fixture') } catch { $multipleLinkTargetsRejected = $_.Exception.Message -match 'exactly one hyperlink target' }
    Assert-ImportEngine $multipleLinkTargetsRejected 'multiple DOCX hyperlink targets remain rejected'

    $flatGameRepeat = Invoke-GameFixture @(
        (New-TestParagraph 'Overview fixture' -Style 'Heading2'),
        (New-TestParagraph 'Overview body'),
        (New-TestParagraph 'Contribution fixture' -Style 'Heading2'),
        (New-TestParagraph 'Contribution body')
    )
    Assert-ImportEngine ($flatGame.Html -ceq $flatGameRepeat.Html -and $flatGame.Structure -ceq $flatGameRepeat.Structure) 'G. existing flat Game documents continue compiling identically'

    $generaExpected = [ordered]@{
        'the-little-prince' = [pscustomobject]@{ es = @('Level Design'); en = @('Level Design') }
        'runbot' = [pscustomobject]@{ es = @('Gameplay Upgrade & Implementation'); en = @('Gameplay Upgrade & Implementation') }
        'xtreme-racing-2' = [pscustomobject]@{ es = @('La tienda', 'Las carreras'); en = @('The Shop', 'The Races') }
        'skull-towers' = [pscustomobject]@{ es = @('Recompensas y sistema de progresion', 'Balanceo & FX'); en = @('Rewards & Progression System', 'Balancing & FX') }
    }
    $generaExpected['skull-towers'].es[0] = "Recompensas y sistema de progresi$([char]0x00f3)n"
    foreach ($generaId in $generaExpected.Keys) {
        $generaDocument = Split-BilingualDocx (Read-DocxDocument -Path (Join-Path $root "local-content\inbox\game__${generaId}__ES-EN.docx"))
        $generaEs = Convert-GameLanguage -Paragraphs $generaDocument.es -Language 'es' -GameId $generaId -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
        $generaEn = Convert-GameLanguage -Paragraphs $generaDocument.en -Language 'en' -GameId $generaId -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
        Assert-GameParity -Spanish $generaEs -English $generaEn
        $expectedEs = @($generaExpected[$generaId].es)
        $expectedEn = @($generaExpected[$generaId].en)
        Assert-ImportEngine (($generaEs.Subsections -join '|') -ceq ($expectedEs -join '|') -and ($generaEn.Subsections -join '|') -ceq ($expectedEn -join '|')) "game:$generaId schema Contribution labels compile as h3"
        Assert-ImportEngine ($generaEs.HeadingTopology -ceq $generaEn.HeadingTopology -and @($generaEs.Subsections).Count -eq $expectedEs.Count) "game:$generaId ES/EN Contribution topology parity"
        $generaEsXml = [xml]$generaEs.Html
        $generaEnXml = [xml]$generaEn.Html
        Assert-ImportEngine ($generaEsXml.SelectNodes('/article/section[@id="contribution"]/section/h3').Count -eq $expectedEs.Count -and $generaEnXml.SelectNodes('/article/section[@id="contribution"]/section/h3').Count -eq $expectedEn.Count) "game:$generaId Contribution subsections render as h3"
    }

    $expectedTargetKeys = @('about:main', 'cv:main', 'game:ea-sports-pga-tour', 'game:madden-nfl-25', 'game:madden-nfl-26', 'game:madden-nfl-27')
    $plan = New-ContentImportPlan -RepositoryRoot $root -IncludeUnchanged -TargetKeys $expectedTargetKeys
    $targets = @($plan.Items | ForEach-Object TargetKey)
    $expectedTargets = $expectedTargetKeys -join '|'
    Assert-ImportEngine (($targets -join '|') -ceq $expectedTargets) 'all expected targets resolve in deterministic order'
    Assert-ImportEngine ($plan.Scan.Counts.INVALID -eq 0) 'filename and target preflight'
    Assert-ImportEngine ($plan.Items.Count -eq 6) 'stable About, CV, and EA DOCX fixtures parse'

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
    $twsIds = @('777-deluxe', 'andar-bahar', 'a-night-with-cleo', 'cricket-legends', 'cyberpunk-city', 'gods-of-luxor', 'gold-rush-gus', 'mystic-elements', 'teen-patti', 'wheel-of-fortune', 'zombie-soccer')
    $twsGameItems = @()
    foreach ($twsId in $twsIds) {
        $canonicalPath = Join-Path $root "local-content\canonical\game\$twsId\content.docx"
        $twsDocument = Split-BilingualDocx (Read-DocxDocument -Path $canonicalPath)
        $twsEsModel = Convert-GameLanguage -Paragraphs $twsDocument.es -Language 'es' -GameId $twsId -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
        $twsEnModel = Convert-GameLanguage -Paragraphs $twsDocument.en -Language 'en' -GameId $twsId -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
        Assert-GameParity -Spanish $twsEsModel -English $twsEnModel
        $twsGameItems += [pscustomobject]@{
            TargetKey = "game:$twsId"
            Type = 'game'
            Id = $twsId
            Status = 'UNCHANGED'
            Outputs = [ordered]@{
                "content/games/$twsId/es.html" = $twsEsModel.Html
                "content/games/$twsId/en.html" = $twsEnModel.Html
            }
            Summary = [pscustomobject]@{ es = $twsEsModel; en = $twsEnModel }
        }
    }
    Assert-ImportEngine ($twsGameItems.Count -eq 11) 'all accepted real TWS DOCX files parse'
    $gameItems = @($plan.Items | Where-Object Type -eq 'game') + $twsGameItems
    foreach ($game in $gameItems) {
        $esGameHtml = [xml]$game.Outputs["content/games/$($game.Id)/es.html"]
        $enGameHtml = [xml]$game.Outputs["content/games/$($game.Id)/en.html"]
        $expectedSubsections = @($game.Summary.en.Subsections).Count
        Assert-ImportEngine ($game.Summary.es.Structure -ceq $game.Summary.en.Structure) "$($game.TargetKey) ES/EN structural parity"
        Assert-ImportEngine (($game.Summary.es.MetadataOrder -join '|') -ceq ($game.Summary.en.MetadataOrder -join '|')) "$($game.TargetKey) ES/EN metadata order parity"
        Assert-ImportEngine ($game.Summary.es.HeadingTopology -ceq $game.Summary.en.HeadingTopology) "$($game.TargetKey) ES/EN heading topology parity"
        $expectedSections = @($game.Summary.en.Sections).Count
        Assert-ImportEngine ($esGameHtml.SelectNodes('/article/section/h2').Count -eq $expectedSections -and $enGameHtml.SelectNodes('/article/section/h2').Count -eq $expectedSections) "$($game.TargetKey) main sections remain h2"
        Assert-ImportEngine ($esGameHtml.SelectNodes('/article/section/section/h3').Count -eq $expectedSubsections -and $enGameHtml.SelectNodes('/article/section/section/h3').Count -eq $expectedSubsections) "$($game.TargetKey) authored subsections remain h3"
        Assert-ImportEngine ($esGameHtml.SelectNodes('/article/section/section/h2').Count -eq 0 -and $enGameHtml.SelectNodes('/article/section/section/h2').Count -eq 0) "$($game.TargetKey) no subsection is promoted to h2"
    }
    $compiledGameRegistry = New-UpdatedGameRegistry -RepositoryRoot $root -GameItems $gameItems -Config (Get-ContentPipelineConfig -RepositoryRoot $root)
    $updatedPga = $compiledGameRegistry.Games.PSObject.Properties['ea-sports-pga-tour'].Value
    Assert-ImportEngine ($updatedPga.year -ceq '2023') 'PGA Year mapping'
    Assert-ImportEngine ($updatedPga.studio -ceq 'EA Sports') 'PGA Company mapping'
    Assert-ImportEngine ($updatedPga.engineName -ceq 'Frostbite') 'PGA textual Engine metadata mapping'
    foreach ($gameItem in $gameItems) {
        $updatedGame = $compiledGameRegistry.Games.PSObject.Properties[$gameItem.Id].Value
        $expectedEngine = if ($gameItem.Summary.en.Metadata.engine.Value -ceq '?') { $null } else { [string]$gameItem.Summary.en.Metadata.engine.Value }
        Assert-ImportEngine ([string]$updatedGame.engineName -ceq [string]$expectedEngine) "$($gameItem.TargetKey) textual Engine metadata mapping"
    }
    foreach ($twsId in $twsIds) {
        $twsGame = $gameItems | Where-Object Id -CEQ $twsId
        $twsEs = [xml]$twsGame.Outputs["content/games/$twsId/es.html"]
        $twsEn = [xml]$twsGame.Outputs["content/games/$twsId/en.html"]
        Assert-ImportEngine ($twsGame.Summary.es.HeadingTopology -ceq 'h2[h3]' -and $twsGame.Summary.en.HeadingTopology -ceq 'h2[h3]') "game:$twsId TWS h2 to h3 topology"
        Assert-ImportEngine ($twsEs.SelectNodes('//h3[text()="Main Features"]').Count -eq 1 -and $twsEn.SelectNodes('//h3[text()="Main Features"]').Count -eq 1 -and $twsEs.SelectNodes('//p[text()="Main Features"]').Count -eq 0 -and $twsEn.SelectNodes('//p[text()="Main Features"]').Count -eq 0) "game:$twsId schema Main Features output"
        foreach ($language in @('es', 'en')) {
            $currentTwsOutput = Get-Content -LiteralPath (Join-Path $root "content\games\$twsId\$language.html") -Raw -Encoding UTF8
            Assert-ImportEngine ($currentTwsOutput -ceq $twsGame.Outputs["content/games/$twsId/$language.html"]) "game:$twsId current $language output matches compiler"
        }
    }
    foreach ($eaId in @('ea-sports-pga-tour', 'madden-nfl-25', 'madden-nfl-26', 'madden-nfl-27')) {
        $eaGame = $gameItems | Where-Object Id -CEQ $eaId
        Assert-ImportEngine ($eaGame.Status -eq 'UNCHANGED' -and @($eaGame.Summary.en.Sections).Count -eq 2 -and @($eaGame.Summary.en.Subsections).Count -gt 0) "game:$eaId existing EA h2/h3 source remains unchanged"
    }
    $registryWithEngineImages = @($compiledGameRegistry.Games.PSObject.Properties.Value | Where-Object { $null -ne $_.PSObject.Properties['engineId'] })
    Assert-ImportEngine ($registryWithEngineImages.Count -eq 0 -and -not (Test-Path -LiteralPath (Join-Path $root 'assets\engines'))) 'Engine image system remains absent'
    try { $parsedRegistry = $compiledGameRegistry.Json | ConvertFrom-Json; $jsonValid = $null -ne $parsedRegistry.games } catch { $jsonValid = $false }
    Assert-ImportEngine $jsonValid 'multi-Game registry JSON is valid'
    Assert-ImportEngine ((Get-Content (Join-Path $root 'data\games.json') -Raw -Encoding UTF8) -ceq $compiledGameRegistry.Json) 'current Game registry matches the compiler'

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
