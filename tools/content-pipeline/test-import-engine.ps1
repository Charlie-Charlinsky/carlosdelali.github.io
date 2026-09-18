[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\ContentPipeline.ps1')
. (Join-Path $PSScriptRoot 'lib\ImportEngine.ps1')
. (Join-Path $PSScriptRoot 'test-game-parity.ps1')
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

function New-GameResourceFixture {
    param([object[]]$Entries = @(), [switch]$NoResources)
    $blocks = @(
        (New-TestParagraph 'Fixture Game' -Style 'Heading1'),
        (New-TestParagraph 'El juego' -Style 'Heading2'),
        (New-TestParagraph 'Texto de prueba'),
        (New-TestParagraph 'ENGLISH VERSION'),
        (New-TestParagraph 'Fixture Game' -Style 'Heading1'),
        (New-TestParagraph 'The game' -Style 'Heading2'),
        (New-TestParagraph 'Fixture text')
    )
    if (-not $NoResources) {
        $blocks += @(
            (New-TestParagraph 'Resources' -Style 'Heading2'),
            (New-TestParagraph 'Youtube Videos:' -Style 'Heading2')
        )
        $blocks += $Entries
    }
    return [pscustomobject]@{ Blocks = $blocks }
}

try {
    $before = Get-ContentTreeFingerprint -RepositoryRoot $root
    Invoke-GameParityMatrix
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

    $noResources = Split-GameDocx (New-GameResourceFixture -NoResources)
    $noResourcesPair = Convert-GameBilingual -Blocks $noResources -GameId 'fixture-no-resources' -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
    Assert-ImportEngine (-not $noResources.Resources.Present -and @($noResources.Resources.YouTubeVideos).Count -eq 0 -and $noResourcesPair.es.Html -match 'Texto de prueba') 'Resources: Game without Resources imports normally'

    $emptyResources = Split-GameDocx (New-GameResourceFixture -Entries @(
        (New-TestParagraph 'Link 1:' -Style 'Heading2'),
        (New-TestParagraph 'Link 2:' -Style 'Heading2'),
        (New-TestParagraph 'Link 3:' -Style 'Heading2'),
        (New-TestParagraph 'Link 4:' -Style 'Heading2')
    ))
    Assert-ImportEngine ($emptyResources.Resources.Present -and @($emptyResources.Resources.YouTubeVideos).Count -eq 0 -and $emptyResources.Resources.EmptyLinks -eq 4) 'Resources: empty links import as zero videos'

    $watchUrl = 'https://www.youtube.com/watch?v=AAAAAAAAAAA'
    $watchResources = Split-GameDocx (New-GameResourceFixture -Entries @(
        (New-TestParagraph "Link 1: $watchUrl" -Style 'Heading2' -Url $watchUrl)
    ))
    Assert-ImportEngine ($watchResources.Resources.YouTubeVideos[0].videoId -ceq 'AAAAAAAAAAA') 'Resources: direct youtube.com watch URL extracts videoId'

    $shortUrl = 'https://youtu.be/BBBBBBBBBBB?si=share-token'
    $orderedResources = Split-GameDocx (New-GameResourceFixture -Entries @(
        (New-TestParagraph "Link 1: $watchUrl" -Style 'Heading2' -Url $watchUrl),
        (New-TestParagraph 'Link 2:' -Style 'Heading2'),
        (New-TestParagraph "Link 3: $shortUrl" -Style 'Heading2' -Url $shortUrl)
    ))
    Assert-ImportEngine ((@($orderedResources.Resources.YouTubeVideos | ForEach-Object videoId) -join '|') -ceq 'AAAAAAAAAAA|BBBBBBBBBBB') 'Resources: youtu.be query parsing and authored Link order'
    Assert-ImportEngine ($orderedResources.Resources.EmptyLinks -eq 1) 'Resources: empty intermediate links are ignored'

    $fourResources = Split-GameDocx (New-GameResourceFixture -Entries @(
        (New-TestParagraph 'Link 1: https://youtu.be/AAAAAAAAAAA' -Style 'Heading2'),
        (New-TestParagraph 'Link 2: https://youtu.be/BBBBBBBBBBB' -Style 'Heading2'),
        (New-TestParagraph 'Link 3: https://youtu.be/CCCCCCCCCCC' -Style 'Heading2'),
        (New-TestParagraph 'Link 4: https://youtu.be/DDDDDDDDDDD' -Style 'Heading2')
    ))
    Assert-ImportEngine (@($fourResources.Resources.YouTubeVideos).Count -eq 4) 'Resources: four authored videos are accepted'

    $fiveResourcesRejected = $false
    try {
        [void](Split-GameDocx (New-GameResourceFixture -Entries @(
            (New-TestParagraph 'Link 1: https://youtu.be/AAAAAAAAAAA' -Style 'Heading2'),
            (New-TestParagraph 'Link 2: https://youtu.be/BBBBBBBBBBB' -Style 'Heading2'),
            (New-TestParagraph 'Link 3: https://youtu.be/CCCCCCCCCCC' -Style 'Heading2'),
            (New-TestParagraph 'Link 4: https://youtu.be/DDDDDDDDDDD' -Style 'Heading2'),
            (New-TestParagraph 'Link 5: https://youtu.be/EEEEEEEEEEE' -Style 'Heading2')
        )))
    } catch { $fiveResourcesRejected = $_.Exception.Message -match 'four-video authoring limit' }
    Assert-ImportEngine $fiveResourcesRejected 'Resources: a fifth authored video is rejected'

    foreach ($invalidUrl in @('https://www.youtube.com/results?search_query=fixture', 'not-a-youtube-url')) {
        $invalidResourceRejected = $false
        try { [void](Split-GameDocx (New-GameResourceFixture -Entries @((New-TestParagraph "Link 1: $invalidUrl" -Style 'Heading2')))) } catch { $invalidResourceRejected = $_.Exception.Message -match 'INVALID_RESOURCE_URL' }
        Assert-ImportEngine $invalidResourceRejected "Resources: invalid direct-video URL rejected ($invalidUrl)"
    }

    $resourcePair = Convert-GameBilingual -Blocks $orderedResources -GameId 'fixture-media' -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
    Assert-ImportEngine ($resourcePair.es.Html -notmatch 'Resources|Youtube Videos|Link 1' -and $resourcePair.en.Html -notmatch 'Resources|Youtube Videos|Link 1') 'Resources: technical block is absent from ES and EN HTML'
    Assert-GameParity -Spanish $resourcePair.es -English $resourcePair.en
    Assert-ImportEngine ($resourcePair.es.Structure -ceq $resourcePair.en.Structure) 'Resources: technical metadata is excluded from bilingual parity'

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

    $authoredBreak = Invoke-ListFixture @(
        (New-TestParagraph 'First group' '18' 0 'bullet' -ParagraphIndex 23),
        (New-TestParagraph 'First child' '18' 1 'bullet' -ParagraphIndex 24),
        (New-TestParagraph '' -ParagraphIndex 25),
        (New-TestParagraph 'Second group' '18' 0 'bullet' -ParagraphIndex 26)
    )
    $authoredBreakLists = @($authoredBreak.Document.SelectNodes('/article/ul'))
    Assert-ImportEngine ($authoredBreak.Signature -ceq 'ul[li[ul[li]]]|break|ul[li]') 'CV GROUP BREAKS: blank paragraph terminates the current list topology'
    Assert-ImportEngine ($authoredBreakLists.Count -eq 2 -and $authoredBreakLists[1].GetAttribute('data-authored-break-before') -ceq 'true') 'CV GROUP BREAKS: following list begins as an independent authored block'
    Assert-ImportEngine ($authoredBreak.Document.SelectNodes('//p[not(node())]').Count -eq 0 -and $authoredBreak.Document.SelectNodes('//br').Count -eq 0) 'CV GROUP BREAKS: blank paragraph does not emit empty paragraphs or br hacks'

    $authoredParagraphBreak = Invoke-ListFixture @(
        (New-TestParagraph 'Paragraph text before.' -ParagraphIndex 27),
        (New-TestParagraph '' -ParagraphIndex 28),
        (New-TestParagraph 'Paragraph text after.' -ParagraphIndex 29)
    )
    $authoredParagraphs = @($authoredParagraphBreak.Document.SelectNodes('/article/p'))
    Assert-ImportEngine ($authoredParagraphBreak.Signature -ceq 'p|break|p' -and $authoredParagraphs[1].GetAttribute('data-authored-break-before') -ceq 'true') 'CV GROUP BREAKS: non-list authored boundary remains structural metadata'
    Assert-ImportEngine (($authoredParagraphs.InnerText -join '|') -ceq 'Paragraph text before.|Paragraph text after.') 'CV RICH TEXT: paragraph text survives authored boundaries unchanged'

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

    $contactSchema = (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.contact
    Assert-ImportEngine ($contactSchema.firstHeadingStyle -ceq 'Heading2' -and $null -eq $contactSchema.PSObject.Properties['title']) 'A. Contact schema declares H2-first with no Heading 1 envelope'

    $contactEmail = 'contact@example.com'
    $contactDisplayText = 'https://linkedin.com/in/carjelosa'
    $contactTarget = 'https://profiles.example.test/member'
    $contactLinkedEs = Convert-ContactLanguage -Paragraphs @(
        (New-TestParagraph 'Contacto' -Style 'Heading2'),
        (New-TestParagraph 'Email' -Style 'Heading3'),
        (New-TestParagraph $contactEmail -Url ('mailto:' + $contactEmail)),
        (New-TestParagraph 'LinkedIn' -Style 'Heading3'),
        (New-TestParagraph $contactDisplayText -Url $contactTarget)
    ) -Language 'es' -Schema $contactSchema
    $contactLinkedEn = Convert-ContactLanguage -Paragraphs @(
        (New-TestParagraph 'Contact' -Style 'Heading2'),
        (New-TestParagraph 'Email' -Style 'Heading3'),
        (New-TestParagraph $contactEmail -Url ('mailto:' + $contactEmail)),
        (New-TestParagraph 'LinkedIn' -Style 'Heading3'),
        (New-TestParagraph $contactDisplayText -Url $contactTarget)
    ) -Language 'en' -Schema $contactSchema
    Assert-ContactParity -Spanish $contactLinkedEs -English $contactLinkedEn
    $contactLinkedXml = [xml]$contactLinkedEn.Html
    Assert-ImportEngine ($contactLinkedXml.SelectNodes('/article/section/h2[text()="Contact"]').Count -eq 1 -and $contactLinkedXml.SelectNodes('//h1').Count -eq 0) 'B. Contact H2 compiles once without a duplicate title'
    Assert-ImportEngine ($contactLinkedXml.SelectNodes('/article/section/section/h3[text()="Email"]').Count -eq 1 -and $contactLinkedXml.SelectNodes('/article/section/section/h3[text()="LinkedIn"]').Count -eq 1) 'C. Contact Email and LinkedIn Heading 3 fields compile'
    Assert-ImportEngine ($contactLinkedEn.Values.linkedin.Text -ceq $contactDisplayText -and $contactLinkedEn.Values.linkedin.Url -ceq $contactTarget -and $contactLinkedEn.Values.linkedin.Text -cne $contactLinkedEn.Values.linkedin.Url) 'D. Contact display text and hyperlink target remain separate source properties'
    Assert-ImportEngine ($contactLinkedXml.SelectSingleNode('//section[@id="linkedin"]/p/a').InnerText -ceq $contactDisplayText -and $contactLinkedXml.SelectSingleNode('//section[@id="linkedin"]/p/a').GetAttribute('href') -ceq $contactTarget) 'E. arbitrary authored LinkedIn display text is emitted unchanged'
    Assert-ImportEngine ($contactLinkedXml.SelectNodes('//section[@id="email"]/p/a[@href="mailto:contact@example.com"]').Count -eq 1) 'F. valid Contact Email mailto behaviour remains unchanged'

    $namedDisplay = Convert-ContactLanguage -Paragraphs @(
        (New-TestParagraph 'Contact' -Style 'Heading2'),
        (New-TestParagraph 'LinkedIn' -Style 'Heading3'),
        (New-TestParagraph 'LinkedIn Profile' -Url $contactTarget)
    ) -Language 'en' -Schema $contactSchema
    Assert-ImportEngine ($namedDisplay.Values.linkedin.Text -ceq 'LinkedIn Profile' -and $namedDisplay.Values.linkedin.Url -ceq $contactTarget) 'G. valid HTTPS targets do not require a particular display string'

    $contactMissing = Convert-ContactLanguage -Paragraphs @(
        (New-TestParagraph 'Contact' -Style 'Heading2')
    ) -Language 'en' -Schema $contactSchema
    Assert-ImportEngine (([xml]$contactMissing.Html).SelectNodes('/article/section/section/p[text()="?"]').Count -eq 2) 'missing Contact fields compile to visible question marks'
    $contactPresenceMismatchRejected = $false
    try { Assert-ContactParity -Spanish $contactLinkedEs -English $contactMissing } catch { $contactPresenceMismatchRejected = $_.Exception.Message -match 'field presence differs' }
    Assert-ImportEngine $contactPresenceMismatchRejected 'Contact ES/EN field presence mismatch is rejected'

    $differentTargetEn = Convert-ContactLanguage -Paragraphs @(
        (New-TestParagraph 'Contact' -Style 'Heading2'),
        (New-TestParagraph 'Email' -Style 'Heading3'),
        (New-TestParagraph $contactEmail -Url ('mailto:' + $contactEmail)),
        (New-TestParagraph 'LinkedIn' -Style 'Heading3'),
        (New-TestParagraph $contactDisplayText -Url 'https://profiles.example.test/different')
    ) -Language 'en' -Schema $contactSchema
    $differentContactTargetRejected = $false
    try { Assert-ContactParity -Spanish $contactLinkedEs -English $differentTargetEn } catch { $differentContactTargetRejected = $_.Exception.Message -match 'field URLs differ for linkedin' }
    Assert-ImportEngine $differentContactTargetRejected 'H. different Contact LinkedIn destinations fail ES/EN parity'

    $httpContactRejected = $false
    try {
        [void](Convert-ContactLanguage -Paragraphs @(
            (New-TestParagraph 'Contact' -Style 'Heading2'),
            (New-TestParagraph 'LinkedIn' -Style 'Heading3'),
            (New-TestParagraph $contactDisplayText -Url 'http://profiles.example.test/member')
        ) -Language 'en' -Schema $contactSchema)
    } catch { $httpContactRejected = $_.Exception.Message -match 'LinkedIn link must use HTTPS' }
    Assert-ImportEngine $httpContactRejected 'I. Contact LinkedIn HTTP targets remain rejected'

    $unsafeContactRejected = $false
    try {
        [void](Convert-ContactLanguage -Paragraphs @(
            (New-TestParagraph 'Contact' -Style 'Heading2'),
            (New-TestParagraph 'LinkedIn' -Style 'Heading3'),
            (New-TestParagraph 'Unsafe' -Url 'javascript:alert(1)')
        ) -Language 'en' -Schema $contactSchema)
    } catch { $unsafeContactRejected = $_.Exception.Message -match 'unsafe URL' }
    Assert-ImportEngine $unsafeContactRejected 'J. unsafe Contact URLs remain rejected'

    $plainLinkedInEn = Convert-ContactLanguage -Paragraphs @(
        (New-TestParagraph 'Contact' -Style 'Heading2'),
        (New-TestParagraph 'Email' -Style 'Heading3'),
        (New-TestParagraph $contactEmail -Url ('mailto:' + $contactEmail)),
        (New-TestParagraph 'LinkedIn' -Style 'Heading3'),
        (New-TestParagraph $contactDisplayText)
    ) -Language 'en' -Schema $contactSchema
    $contactLinkPresenceMismatchRejected = $false
    try { Assert-ContactParity -Spanish $contactLinkedEs -English $plainLinkedInEn } catch { $contactLinkPresenceMismatchRejected = $_.Exception.Message -match 'field URLs differ for linkedin' }
    Assert-ImportEngine $contactLinkPresenceMismatchRejected 'K. plain-text versus hyperlink Contact parity mismatch remains rejected'

    $contactH1Rejected = $false
    try {
        [void](Convert-ContactLanguage -Paragraphs @(
            (New-TestParagraph 'Contact' -Style 'Heading1'),
            (New-TestParagraph 'Contact' -Style 'Heading2')
        ) -Language 'en' -Schema $contactSchema)
    } catch { $contactH1Rejected = $_.Exception.Message -match 'Unexpected Contact visible heading' }
    Assert-ImportEngine $contactH1Rejected 'Contact does not consume or require a Heading 1 envelope'

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
    $localizedGameDocument = Split-GameDocx (Read-DocxDocument -Path (Join-Path $root 'local-content\inbox\game__a-night-with-cleo__ES-EN.docx'))
    Assert-ImportEngine ($localizedGameDocument.es[0].Style -ceq 'Heading1' -and $localizedGameDocument.en[0].Style -ceq 'Heading1') 'real localized Game title styles normalize to Heading 1'

    $currentContactPlan = New-ContentImportPlan -RepositoryRoot $root -IncludeUnchanged -TargetKeys @('contact:main')
    $currentContact = @($currentContactPlan.Items)[0]
    $currentContactEs = [xml]$currentContact.Outputs['content/contact/es.html']
    $currentContactEn = [xml]$currentContact.Outputs['content/contact/en.html']
    Assert-ImportEngine ($currentContactPlan.Items.Count -eq 1 -and $currentContact.TargetKey -ceq 'contact:main' -and $currentContact.Status -in @('NEW', 'UNCHANGED')) 'current contact:main source passes the H2-first import plan'
    Assert-ImportEngine ($currentContact.Summary.es.Values.linkedin.Text -ceq 'https://linkedin.com/in/carjelosa' -and $currentContact.Summary.en.Values.linkedin.Text -ceq 'https://linkedin.com/in/carjelosa') 'current Contact LinkedIn display text remains source-authoritative'
    Assert-ImportEngine ($currentContact.Summary.es.Values.linkedin.Url -ceq 'https://linkedin.com/in/carjelosa' -and $currentContact.Summary.en.Values.linkedin.Url -ceq 'https://linkedin.com/in/carjelosa') 'current Contact LinkedIn HTTPS relationship targets match'
    Assert-ImportEngine ($currentContactEs.SelectNodes('//h1').Count -eq 0 -and $currentContactEn.SelectNodes('//h1').Count -eq 0 -and $currentContactEs.SelectNodes('/article/section/h2').Count -eq 1 -and $currentContactEn.SelectNodes('/article/section/h2').Count -eq 1) 'current Contact output contains one H2 and no duplicate H1 title'
    Assert-ImportEngine ($currentContactEs.SelectNodes('/article/section/section/h3').Count -eq 2 -and $currentContactEn.SelectNodes('/article/section/section/h3').Count -eq 2) 'current Contact ES/EN Heading 3 topology matches'

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

    $aliasSchema = (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
    $aliasPairs = @(
        @("Mec$([char]0x00e1)nicas principales", 'Main features', 'mainFeatures'),
        @("Mejora del gameplay & implementaci$([char]0x00f3)n", 'Gameplay upgrade & implementation', 'gameplayUpgradeImplementation'),
        @('Main Features', 'Main Features', 'mainFeatures'),
        @('Gameplay Upgrade & Implementation', 'Gameplay Upgrade & Implementation', 'gameplayUpgradeImplementation'),
        @('La tienda', 'The Shop', 'shop'),
        @('Las carreras', 'The Races', 'races'),
        @("Recompensas y sistema de progresi$([char]0x00f3)n", 'Rewards & Progression System', 'rewardsProgression'),
        @('Balanceo & FX', 'Balancing & FX', 'balancingFx'),
        @('Level Design', 'Level Design', 'levelDesign')
    )
    foreach ($pair in $aliasPairs) {
        $field = $pair[2]
        $definition = $aliasSchema.subsectionFields.$field
        $models = @{}
        foreach ($language in @('es', 'en')) {
            $label = if ($language -eq 'es') { $pair[0] } else { $pair[1] }
            $paragraphs = @((New-TestParagraph 'Overview' -Style 'Heading2'), (New-TestParagraph 'Body'))
            if ($definition.parentSectionId -ceq 'contribution') {
                $paragraphs += New-TestParagraph 'Contribution' -Style 'Heading2'
            }
            $paragraphs += @((New-TestParagraph $label), (New-TestParagraph 'Authored subsection body'))
            $models[$language] = Invoke-GameFixture $paragraphs -Language $language
            $xml = [xml]$models[$language].Html
            $node = $xml.SelectSingleNode("/article/section[@id='$($definition.parentSectionId)']/section[@id='$($definition.id)']/h3")
            Assert-ImportEngine ($null -ne $node -and $node.InnerText -ceq $label) "$field $language alias renders H3 with exact authored text"
            Assert-ImportEngine ($node.ParentNode.SelectSingleNode('p').InnerText -ceq 'Authored subsection body') "$field $language alias owns following prose"
        }
        Assert-GameParity -Spanish $models.es -English $models.en
        Assert-ImportEngine ($models.es.HeadingTopology -ceq $models.en.HeadingTopology) "$field alias pair has equivalent ES/EN topology"
    }
    foreach ($unknown in @('Main features extra', 'Prefix Main features', 'Mecanicas principales', 'MECHANICS', 'Unknown subsection')) {
        $model = Invoke-GameFixture @((New-TestParagraph 'Overview' -Style 'Heading2'), (New-TestParagraph $unknown))
        $xml = [xml]$model.Html
        Assert-ImportEngine ($xml.SelectNodes('//h3').Count -eq 0 -and $xml.SelectSingleNode('/article/section/p').InnerText -ceq $unknown) "unknown Normal label stays prose: $unknown"
    }
    $wordHeadingPrecedence = Invoke-GameFixture @(
        (New-TestParagraph 'Main features' -Style 'Heading2'),
        (New-TestParagraph 'The Shop' -Style 'Heading3'),
        (New-TestParagraph 'Body')
    )
    Assert-ImportEngine ($wordHeadingPrecedence.HeadingTopology -ceq 'h2[h3]' -and ([xml]$wordHeadingPrecedence.Html).SelectSingleNode('/article/section/h2').InnerText -ceq 'Main features') 'genuine Word headings take precedence over Normal-only schema aliases'

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
    try { Assert-GameParity -Spanish $schemaSpanish -English $contributionSubsections } catch { $contributionMismatchRejected = $_.Exception.Data.Contains('GameParityDiagnostic') -and $_.Exception.Data['GameParityDiagnostic'].Classification -ceq 'AMBIGUOUS' }
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

    $richTextParagraph = New-TestParagraph 'The team had two designers, built Battle Pass, and worked remotely.'
    $richTextParagraph.Runs = @(
        [pscustomobject]@{ Text = 'The team had '; Bold = $false; Italic = $false; Url = $null },
        [pscustomobject]@{ Text = 'two designers'; Bold = $true; Italic = $false; Url = $null },
        [pscustomobject]@{ Text = ', built '; Bold = $false; Italic = $false; Url = $null },
        [pscustomobject]@{ Text = 'Battle'; Bold = $true; Italic = $false; Url = $null },
        [pscustomobject]@{ Text = ' '; Bold = $true; Italic = $false; Url = $null },
        [pscustomobject]@{ Text = 'Pass'; Bold = $true; Italic = $false; Url = $null },
        [pscustomobject]@{ Text = ', and worked '; Bold = $false; Italic = $false; Url = $null },
        [pscustomobject]@{ Text = 'remotely'; Bold = $true; Italic = $false; Url = $null },
        [pscustomobject]@{ Text = '.'; Bold = $false; Italic = $false; Url = $null }
    )
    $richTextParagraph.Text = @($richTextParagraph.Runs | ForEach-Object Text) -join ''
    $richTextFixture = Invoke-ListFixture @($richTextParagraph)
    $richTextXml = [xml]$richTextFixture.Html
    $richStrong = @($richTextXml.SelectNodes('/article/p/strong'))
    Assert-ImportEngine ($richStrong.Count -eq 3 -and ($richStrong.InnerText -join '|') -ceq 'two designers|Battle Pass|remotely') 'CV RICH TEXT: partial and separated bold fragments render as strong'
    Assert-ImportEngine ($richTextXml.SelectNodes('//h1 | //h2 | //h3 | //h4 | //h5 | //h6').Count -eq 0) 'CV RICH TEXT: bold text does not define heading structure'
    Assert-ImportEngine ($richTextXml.SelectNodes('/article/p/strong[normalize-space(.)="Battle Pass"]').Count -eq 1) 'CV RICH TEXT: adjacent bold runs and bold whitespace coalesce into one phrase'
    Assert-ImportEngine ($richTextXml.DocumentElement.InnerText -ceq $richTextParagraph.Text) 'CV RICH TEXT: authored plain text remains byte-for-character unchanged'
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
    try { Assert-GameParity -Spanish $equivalentSpanish -English $multipleSubsectionGame } catch { $differentTopologyRejected = $_.Exception.Data.Contains('GameParityDiagnostic') -and $_.Exception.Data['GameParityDiagnostic'].Classification -ceq 'AMBIGUOUS' }
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
    $qualifiedAccessSpanish = Invoke-GameFixture @(
        (New-TestParagraph 'Acceso(VPN requerida)' -Style 'Heading2'),
        (New-TestParagraph $accessTarget -Url $accessTarget),
        (New-TestParagraph 'El Juego' -Style 'Heading2'),
        (New-TestParagraph 'Texto')
    ) -Language 'es'
    $qualifiedAccessEnglish = Invoke-GameFixture @(
        (New-TestParagraph 'Access(VPN required)' -Style 'Heading2'),
        (New-TestParagraph $accessTarget -Url $accessTarget),
        (New-TestParagraph 'The Game' -Style 'Heading2'),
        (New-TestParagraph 'Text')
    )
    Assert-GameParity -Spanish $qualifiedAccessSpanish -English $qualifiedAccessEnglish
    Assert-ImportEngine ($qualifiedAccessSpanish.Metadata.access.Label -ceq 'Acceso(VPN requerida)' -and $qualifiedAccessEnglish.Metadata.access.Label -ceq 'Access(VPN required)') 'Access qualifier maps to access while preserving exact authored labels'
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
        'the-little-prince' = @('levelDesign')
        'runbot' = @('gameplayUpgradeImplementation')
        'xtreme-racing-2' = @('shop', 'races')
        'skull-towers' = @('rewardsProgression', 'balancingFx')
    }
    $gameSchema = (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
    foreach ($generaId in $generaExpected.Keys) {
        $generaDocument = Split-GameDocx (Read-DocxDocument -Path (Join-Path $root "local-content\inbox\game__${generaId}__ES-EN.docx"))
        $generaEs = Convert-GameLanguage -Paragraphs $generaDocument.es -Language 'es' -GameId $generaId -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
        $generaEn = Convert-GameLanguage -Paragraphs $generaDocument.en -Language 'en' -GameId $generaId -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
        Assert-GameParity -Spanish $generaEs -English $generaEn
        foreach ($language in @('es', 'en')) {
            $model = if ($language -eq 'es') { $generaEs } else { $generaEn }
            $authoredHeadings = @($generaDocument.$language | Where-Object {
                $_.Style -eq 'Heading3' -or ($_.Style -eq 'Normal' -and $null -ne (Get-MappedValue -Map $gameSchema.schemaSubsections.$language -Label $_.Text.Trim()))
            })
            $resolvedFields = @($authoredHeadings | ForEach-Object { Get-MappedValue -Map $gameSchema.schemaSubsections.$language -Label $_.Text.Trim() })
            $renderedHeadings = @(([xml]$model.Html).SelectNodes('/article/section[@id="contribution"]/section/h3'))
            Assert-ImportEngine (($resolvedFields -join '|') -ceq ($generaExpected[$generaId] -join '|')) "game:$generaId $language semantic Contribution fields"
            Assert-ImportEngine ($renderedHeadings.Count -eq $generaExpected[$generaId].Count -and ($renderedHeadings.InnerText -join '|') -ceq ($authoredHeadings.Text -join '|')) "game:$generaId $language Contribution H3 preserves authored display text"
        }
        Assert-ImportEngine ($generaEs.HeadingTopology -ceq $generaEn.HeadingTopology) "game:$generaId ES/EN Contribution topology parity"
    }

    $expectedTargetKeys = @('about:main', 'cv:main', 'game:ea-sports-pga-tour', 'game:madden-nfl-25', 'game:madden-nfl-26', 'game:madden-nfl-27')
    $plan = New-ContentImportPlan -RepositoryRoot $root -IncludeUnchanged -TargetKeys $expectedTargetKeys
    $targets = @($plan.Items | ForEach-Object TargetKey)
    $expectedTargets = $expectedTargetKeys -join '|'
    Assert-ImportEngine (($targets -join '|') -ceq $expectedTargets) 'all expected targets resolve in deterministic order'
    Assert-ImportEngine ($plan.Scan.Counts.INVALID -eq 0) 'filename and target preflight'
    Assert-ImportEngine ($plan.Items.Count -eq 6) 'stable About, CV, and EA DOCX fixtures parse'

    $manifest = Read-ContentPipelineManifest -Path (Get-ContentPipelinePaths -RepositoryRoot $root).Manifest
    $previousAcceptedTargetKeys = @($manifest.entries.PSObject.Properties | Where-Object Name -CNE 'contact:main' | ForEach-Object Name)
    $previousAcceptedPlan = New-ContentImportPlan -RepositoryRoot $root -IncludeUnchanged -TargetKeys $previousAcceptedTargetKeys
    Assert-ImportEngine ($previousAcceptedTargetKeys.Count -eq 21 -and $previousAcceptedPlan.Items.Count -eq 21) 'all 21 existing non-Contact targets parse with pending editorial updates'
    foreach ($entry in $manifest.entries.PSObject.Properties.Value) {
        Assert-ImportEngine ((Get-ContentFileSha256 -Path (Join-Path $root $entry.canonicalFile)) -ceq $entry.sha256) "$($entry.targetKey) canonical matches accepted hash independently of inbox edits"
    }

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
    $cvDocument = Split-BilingualDocx (Read-DocxDocument -Path (Join-Path $root 'local-content\inbox\cv__main__ES-EN.docx')) -PreserveBlankParagraphs
    $cvEs = Convert-CvLanguage -Paragraphs $cvDocument.es -Language 'es' -CurrentHtmlPath (Join-Path $root 'content\cv\es.html') -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.cv
    $cvEn = Convert-CvLanguage -Paragraphs $cvDocument.en -Language 'en' -CurrentHtmlPath (Join-Path $root 'content\cv\en.html') -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.cv
    Assert-ImportEngine ($cvEs.Structure -ceq $cvEn.Structure) 'current CV ES/EN list topology parity'
    Assert-ImportEngine (($cvEs.Structure -split '\|')[0] -like 'work-experience:*' -and ($cvEn.Structure -split '\|')[0] -like 'work-experience:*') 'CV source-authored Professional Experience section remains first'
    Assert-ImportEngine (@($cvDocument.es | Where-Object { Test-BlankParagraph $_ }).Count -gt 0 -and @($cvDocument.es | Where-Object { Test-BlankParagraph $_ }).Count -eq @($cvDocument.en | Where-Object { Test-BlankParagraph $_ }).Count) 'current CV preserves bilingual authored blank-paragraph topology'
    Assert-ImportEngine ((@($cvEs.Ludography | ForEach-Object Games | ForEach-Object { $_ }) -join '|') -ceq (@($cvEn.Ludography | ForEach-Object Games | ForEach-Object { $_ }) -join '|')) 'CV Ludography ordering remains bilingual and unchanged'
    foreach ($model in @($cvEs, $cvEn)) {
        $generatedRichCv = [xml]$model.Html
        Assert-ImportEngine ($generatedRichCv.SelectNodes('//strong').Count -gt 0) 'current CV preserves authored inline strong output'
        Assert-ImportEngine ($generatedRichCv.SelectNodes('//*[@data-authored-break-before="true"]').Count -gt 0) 'current CV preserves authored group-boundary metadata'
        Assert-ImportEngine ($model.Html -notmatch '</strong><strong>') 'current CV emits no adjacent fragmented strong elements'
        Assert-ImportEngine ($generatedRichCv.SelectNodes('//p[not(node())] | //br/following-sibling::br').Count -eq 0) 'current CV emits no empty paragraph or br-br spacing hack'
    }
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
        $twsDocument = Split-GameDocx (Read-DocxDocument -Path $canonicalPath)
        $twsPair = Convert-GameBilingual -Blocks $twsDocument -GameId $twsId -Schema (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
        $twsEsModel = $twsPair.es
        $twsEnModel = $twsPair.en
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
            Summary = [pscustomobject]@{ es = $twsEsModel; en = $twsEnModel; Resources = $twsPair.Resources }
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
        $acceptedTws = Split-GameDocx (Read-DocxDocument -Path (Join-Path $root "local-content\canonical\game\$twsId\content.docx"))
        foreach ($language in @('es', 'en')) {
            $authored = @($twsGame.Summary.$language.SemanticNodes | Where-Object { $_.Kind -ceq 'h3' -and $_.SemanticId -ceq 'main-features' })
            $sourceHeading = @($acceptedTws.$language | Where-Object { $_.ParagraphIndex -eq $authored[0].ParagraphIndex })
            $rendered = @(([xml]$twsGame.Outputs["content/games/$twsId/$language.html"]).SelectNodes('/article/section[@id="overview"]/section/h3'))
            Assert-ImportEngine ($authored.Count -eq 1 -and $rendered.Count -eq 1 -and $sourceHeading.Count -eq 1 -and $rendered[0].InnerText -ceq $sourceHeading[0].Text) "game:$twsId $language Main Features H3 preserves authored display text"
            $currentTwsOutput = Get-Content -LiteralPath (Join-Path $root "content\games\$twsId\$language.html") -Raw -Encoding UTF8
            Assert-ImportEngine ($currentTwsOutput -ceq $twsGame.Outputs["content/games/$twsId/$language.html"]) "game:$twsId current $language output matches compiler"
        }
    }
    foreach ($eaId in @('ea-sports-pga-tour', 'madden-nfl-25', 'madden-nfl-26', 'madden-nfl-27')) {
        $eaGame = $gameItems | Where-Object Id -CEQ $eaId
        Assert-ImportEngine ($eaGame.Status -in @('CHANGED', 'UNCHANGED') -and @($eaGame.Summary.en.Sections).Count -eq 2 -and @($eaGame.Summary.en.Subsections).Count -gt 0) "game:$eaId existing EA h2/h3 contract remains valid"
    }
    $registryWithEngineImages = @($compiledGameRegistry.Games.PSObject.Properties.Value | Where-Object { $null -ne $_.PSObject.Properties['engineId'] })
    Assert-ImportEngine ($registryWithEngineImages.Count -eq 0 -and -not (Test-Path -LiteralPath (Join-Path $root 'assets\engines'))) 'Engine image system remains absent'
    try { $parsedRegistry = $compiledGameRegistry.Json | ConvertFrom-Json; $jsonValid = $null -ne $parsedRegistry.games } catch { $jsonValid = $false }
    Assert-ImportEngine $jsonValid 'multi-Game registry JSON is valid'
    $acceptedGameItems = @()
    foreach ($entry in @($manifest.entries.PSObject.Properties.Value | Where-Object targetKey -Like 'game:*')) {
        $id = $entry.targetKey.Split(':')[1]
        $acceptedDoc = Split-GameDocx (Read-DocxDocument -Path (Join-Path $root $entry.canonicalFile))
        $acceptedPair = Convert-GameBilingual -Blocks $acceptedDoc -GameId $id -Schema $gameSchema
        $acceptedEs = $acceptedPair.es
        $acceptedEn = $acceptedPair.en
        Assert-GameParity -Spanish $acceptedEs -English $acceptedEn
        foreach ($language in @('es', 'en')) {
            $model = if ($language -eq 'es') { $acceptedEs } else { $acceptedEn }
            Assert-ImportEngine ((Get-Content (Join-Path $root "content/games/$id/$language.html") -Raw -Encoding UTF8) -ceq $model.Html) "game:$id $language output matches accepted canonical"
        }
        $acceptedGameItems += [pscustomobject]@{ Id = $id; Summary = [pscustomobject]@{ es = $acceptedEs; en = $acceptedEn; Resources = $acceptedPair.Resources } }
    }
    $acceptedRegistry = New-UpdatedGameRegistry -RepositoryRoot $root -GameItems $acceptedGameItems -Config (Get-ContentPipelineConfig -RepositoryRoot $root)
    $currentRegistryModel = Get-Content (Join-Path $root 'data\games.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $acceptedRegistryModel = $acceptedRegistry.Json | ConvertFrom-Json
    $registryEquivalent = @($currentRegistryModel.games).Count -eq @($acceptedRegistryModel.games).Count
    for ($registryIndex = 0; $registryEquivalent -and $registryIndex -lt @($currentRegistryModel.games).Count; $registryIndex++) {
        $currentGame = $currentRegistryModel.games[$registryIndex]
        $acceptedGame = $acceptedRegistryModel.games[$registryIndex]
        $currentNames = @($currentGame.PSObject.Properties.Name | Sort-Object)
        $acceptedNames = @($acceptedGame.PSObject.Properties.Name | Sort-Object)
        $registryEquivalent = ($currentNames -join '|') -ceq ($acceptedNames -join '|')
        foreach ($name in $currentNames) {
            if (-not $registryEquivalent -or (ConvertTo-StableJson $currentGame.$name) -cne (ConvertTo-StableJson $acceptedGame.$name)) { $registryEquivalent = $false; break }
        }
    }
    Assert-ImportEngine $registryEquivalent 'current Game registry matches accepted canonicals semantically'

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
