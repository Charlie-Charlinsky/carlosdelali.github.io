Set-StrictMode -Version Latest

$script:WordNamespace = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$script:OfficeRelationshipNamespace = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'

function Read-ZipXmlEntry {
    param($Archive, [string]$Name, [switch]$Required)
    $entry = $Archive.GetEntry($Name)
    if ($null -eq $entry) {
        if ($Required) { throw "DOCX entry is missing: $Name" }
        return $null
    }
    $reader = New-Object System.IO.StreamReader($entry.Open())
    try { return [xml]$reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Get-WordAttribute {
    param($Node, [string]$Name)
    return $Node.GetAttribute($Name, $script:WordNamespace)
}

function Test-WordToggle {
    param($Node)
    if ($null -eq $Node) { return $false }
    $value = Get-WordAttribute -Node $Node -Name 'val'
    return @('0', 'false', 'off', 'no') -notcontains $value.ToLowerInvariant()
}

function Convert-DocxRun {
    param($Run, $NamespaceManager, [string]$Url)

    $text = New-Object System.Text.StringBuilder
    foreach ($child in $Run.ChildNodes) {
        switch ($child.LocalName) {
            't' { [void]$text.Append($child.InnerText) }
            'tab' { [void]$text.Append([char]9) }
            'br' { [void]$text.Append([char]10) }
            'noBreakHyphen' { [void]$text.Append([char]0x2011) }
        }
    }
    $properties = $Run.SelectSingleNode('w:rPr', $NamespaceManager)
    $bold = $false
    $italic = $false
    if ($null -ne $properties) {
        $bold = Test-WordToggle ($properties.SelectSingleNode('w:b', $NamespaceManager))
        $italic = Test-WordToggle ($properties.SelectSingleNode('w:i', $NamespaceManager))
    }
    return [pscustomobject][ordered]@{
        Text = $text.ToString()
        Bold = $bold
        Italic = $italic
        Url = $Url
    }
}

function Read-DocxDocument {
    param([Parameter(Mandatory = $true)][string]$Path)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $document = Read-ZipXmlEntry -Archive $archive -Name 'word/document.xml' -Required
        $relationshipsXml = Read-ZipXmlEntry -Archive $archive -Name 'word/_rels/document.xml.rels'
        $numberingXml = Read-ZipXmlEntry -Archive $archive -Name 'word/numbering.xml'
        $namespace = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
        $namespace.AddNamespace('w', $script:WordNamespace)
        $namespace.AddNamespace('r', $script:OfficeRelationshipNamespace)

        $relationships = @{}
        if ($null -ne $relationshipsXml) {
            foreach ($relationship in $relationshipsXml.DocumentElement.ChildNodes) {
                if ($relationship.LocalName -eq 'Relationship') {
                    $relationships[[string]$relationship.Id] = [string]$relationship.Target
                }
            }
        }

        $numberFormats = @{}
        if ($null -ne $numberingXml) {
            $numberingNamespace = New-Object System.Xml.XmlNamespaceManager($numberingXml.NameTable)
            $numberingNamespace.AddNamespace('w', $script:WordNamespace)
            $abstractFormats = @{}
            foreach ($abstract in $numberingXml.SelectNodes('//w:abstractNum', $numberingNamespace)) {
                $abstractId = Get-WordAttribute -Node $abstract -Name 'abstractNumId'
                $levels = @{}
                foreach ($level in $abstract.SelectNodes('w:lvl', $numberingNamespace)) {
                    $levelId = Get-WordAttribute -Node $level -Name 'ilvl'
                    $formatNode = $level.SelectSingleNode('w:numFmt', $numberingNamespace)
                    $levels[$levelId] = if ($formatNode) { Get-WordAttribute -Node $formatNode -Name 'val' } else { 'bullet' }
                }
                $abstractFormats[$abstractId] = $levels
            }
            foreach ($number in $numberingXml.SelectNodes('//w:num', $numberingNamespace)) {
                $numberId = Get-WordAttribute -Node $number -Name 'numId'
                $abstractNode = $number.SelectSingleNode('w:abstractNumId', $numberingNamespace)
                $abstractId = Get-WordAttribute -Node $abstractNode -Name 'val'
                $numberFormats[$numberId] = $abstractFormats[$abstractId]
            }
        }

        $blocks = @()
        $paragraphIndex = 0
        foreach ($node in $document.SelectSingleNode('//w:body', $namespace).ChildNodes) {
            if ($node.LocalName -eq 'tbl') {
                $blocks += [pscustomobject]@{ Kind = 'table'; Text = $node.InnerText }
                continue
            }
            if ($node.LocalName -ne 'p') { continue }

            $styleNode = $node.SelectSingleNode('w:pPr/w:pStyle', $namespace)
            $style = if ($styleNode) { Get-WordAttribute -Node $styleNode -Name 'val' } else { 'Normal' }
            $numberNode = $node.SelectSingleNode('w:pPr/w:numPr/w:numId', $namespace)
            $levelNode = $node.SelectSingleNode('w:pPr/w:numPr/w:ilvl', $namespace)
            $numberId = if ($numberNode) { Get-WordAttribute -Node $numberNode -Name 'val' } else { $null }
            $level = if ($levelNode) { [int](Get-WordAttribute -Node $levelNode -Name 'val') } else { $null }
            $listFormat = $null
            if ($null -ne $numberId -and $numberFormats.ContainsKey($numberId)) {
                $formatMap = $numberFormats[$numberId]
                $formatKey = if ($null -eq $level) { '0' } else { [string]$level }
                if ($formatMap.ContainsKey($formatKey)) { $listFormat = [string]$formatMap[$formatKey] }
            }

            $runs = @()
            foreach ($child in $node.ChildNodes) {
                if ($child.LocalName -eq 'r') {
                    $runs += Convert-DocxRun -Run $child -NamespaceManager $namespace -Url $null
                } elseif ($child.LocalName -eq 'hyperlink') {
                    $relationshipId = $child.GetAttribute('id', $script:OfficeRelationshipNamespace)
                    $url = if ($relationships.ContainsKey($relationshipId)) { [string]$relationships[$relationshipId] } else { $null }
                    foreach ($run in $child.SelectNodes('w:r', $namespace)) {
                        $runs += Convert-DocxRun -Run $run -NamespaceManager $namespace -Url $url
                    }
                }
            }
            $blocks += [pscustomobject][ordered]@{
                Kind = 'paragraph'
                ParagraphIndex = $paragraphIndex
                Style = $style
                Text = (@($runs | ForEach-Object Text) -join '')
                Runs = $runs
                NumberId = $numberId
                ListLevel = $level
                ListFormat = $listFormat
            }
            $paragraphIndex++
        }
        return [pscustomobject]@{ Path = $Path; Blocks = $blocks }
    } finally {
        $archive.Dispose()
    }
}

function Split-BilingualDocx {
    param([Parameter(Mandatory = $true)][object]$Document)

    if (@($Document.Blocks | Where-Object Kind -eq 'table').Count -gt 0) {
        throw 'Tables are not supported by the initial About/CV/Game schemas.'
    }
    $paragraphs = @($Document.Blocks | Where-Object Kind -eq 'paragraph')
    $markers = @()
    for ($index = 0; $index -lt $paragraphs.Count; $index++) {
        if ($paragraphs[$index].Text.Trim() -ceq 'ENGLISH VERSION') { $markers += $index }
    }
    if ($markers.Count -ne 1) { throw "Expected exactly one ENGLISH VERSION marker; found $($markers.Count)." }

    $es = if ($markers[0] -gt 0) { @($paragraphs[0..($markers[0] - 1)]) } else { @() }
    $en = if ($markers[0] + 1 -lt $paragraphs.Count) { @($paragraphs[($markers[0] + 1)..($paragraphs.Count - 1)]) } else { @() }
    return [pscustomobject]@{
        es = @($es | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Text) })
        en = @($en | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Text) })
    }
}

function Get-MappedValue {
    param($Map, [string]$Label)
    $property = $Map.PSObject.Properties[$Label]
    if ($null -eq $property) { return $null }
    return [string]$property.Value
}

function Test-SafeContentUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }
    if ($Url.StartsWith('/')) { return $true }
    $uri = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri)) { return $false }
    return @('http', 'https', 'mailto') -contains $uri.Scheme.ToLowerInvariant()
}

function New-HtmlDocument {
    param([string]$AttributeName, [string]$AttributeValue)
    $document = New-Object System.Xml.XmlDocument
    $article = $document.CreateElement('article')
    $article.SetAttribute($AttributeName, $AttributeValue)
    [void]$document.AppendChild($article)
    return [pscustomobject]@{ Document = $document; Article = $article }
}

function Add-HtmlElement {
    param($Document, $Parent, [string]$Name, [string]$Text, [hashtable]$Attributes = @{})
    $element = $Document.CreateElement($Name)
    foreach ($key in $Attributes.Keys) { $element.SetAttribute($key, [string]$Attributes[$key]) }
    if ($null -ne $Text) { [void]$element.AppendChild($Document.CreateTextNode($Text)) }
    [void]$Parent.AppendChild($element)
    return $element
}

function Add-InlineRuns {
    param($Document, $Parent, [object[]]$Runs)
    foreach ($run in $Runs) {
        if ([string]::IsNullOrEmpty($run.Text)) { continue }
        $container = $Parent
        if ($run.Url) {
            if (-not (Test-SafeContentUrl -Url $run.Url)) { throw "Unsafe or unsupported authored URL: $($run.Url)" }
            $container = Add-HtmlElement -Document $Document -Parent $container -Name 'a' -Text $null -Attributes @{ href = $run.Url }
        }
        if ($run.Bold) { $container = Add-HtmlElement -Document $Document -Parent $container -Name 'strong' -Text $null }
        if ($run.Italic) { $container = Add-HtmlElement -Document $Document -Parent $container -Name 'em' -Text $null }
        $parts = $run.Text -split "`n", -1
        for ($index = 0; $index -lt $parts.Count; $index++) {
            if ($parts[$index].Length -gt 0) { [void]$container.AppendChild($Document.CreateTextNode($parts[$index])) }
            if ($index -lt $parts.Count - 1) { [void]$container.AppendChild($Document.CreateElement('br')) }
        }
    }
}

function Add-SemanticParagraph {
    param($Document, $Parent, $Paragraph, [string]$ElementName = 'p')
    $element = Add-HtmlElement -Document $Document -Parent $Parent -Name $ElementName -Text $null
    if ($ElementName -match '^h[1-6]$') {
        [void]$element.AppendChild($Document.CreateTextNode($Paragraph.Text))
    } else {
        Add-InlineRuns -Document $Document -Parent $element -Runs @($Paragraph.Runs)
    }
    return $element
}

function Get-ListElementName {
    param($Paragraph)
    return $(if ($Paragraph.ListFormat -eq 'bullet') { 'ul' } else { 'ol' })
}

function Get-ListTopologySignature {
    param([Parameter(Mandatory = $true)][System.Xml.XmlNode]$Node)

    if ($Node.Name -notin @('ul', 'ol')) { throw "Cannot create list topology from '$($Node.Name)'." }
    $items = @()
    foreach ($item in @($Node.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })) {
        if ($item.Name -ne 'li') { throw "List '$($Node.Name)' contains an unexpected '$($item.Name)' element." }
        $children = @($item.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and $_.Name -in @('ul', 'ol') })
        $childSignature = @($children | ForEach-Object { Get-ListTopologySignature -Node $_ })
        $items += $(if ($childSignature.Count) { "li[$($childSignature -join ',')]" } else { 'li' })
    }
    return "$($Node.Name)[$($items -join ',')]"
}

function Get-ListParagraphIndex {
    param($Paragraph, [int]$Fallback)
    $property = $Paragraph.PSObject.Properties['ParagraphIndex']
    if ($null -ne $property) { return [int]$property.Value }
    return $Fallback
}

function Throw-InvalidListHierarchy {
    param($Paragraph, [int]$FallbackIndex, [int]$PreviousLevel, [int]$RequestedLevel, [string]$Target, [string]$Language)

    $preview = $Paragraph.Text.Trim()
    if ($preview.Length -gt 80) { $preview = $preview.Substring(0, 80) + '...' }
    $paragraphIndex = Get-ListParagraphIndex -Paragraph $Paragraph -Fallback $FallbackIndex
    throw "INVALID_LIST_HIERARCHY target=$Target language=$Language paragraph=$paragraphIndex text='$preview' previousLevel=$PreviousLevel requestedLevel=$RequestedLevel"
}

function Add-HierarchicalListSequence {
    param(
        $Document,
        $Parent,
        [object[]]$Paragraphs,
        [int]$StartIndex,
        [string]$Target = 'unknown',
        [string]$Language = 'unknown'
    )

    $stack = New-Object System.Collections.ArrayList
    $roots = @()
    $index = $StartIndex
    $previousLevel = -1
    while ($index -lt $Paragraphs.Count -and $null -ne $Paragraphs[$index].NumberId) {
        $paragraph = $Paragraphs[$index]
        $level = if ($null -eq $paragraph.ListLevel) { 0 } else { [int]$paragraph.ListLevel }
        if ($level -lt 0 -or $level -gt ($previousLevel + 1)) {
            Throw-InvalidListHierarchy -Paragraph $paragraph -FallbackIndex $index -PreviousLevel $previousLevel -RequestedLevel $level -Target $Target -Language $Language
        }

        while ($stack.Count -gt ($level + 1)) { $stack.RemoveAt($stack.Count - 1) }
        $listName = Get-ListElementName -Paragraph $paragraph
        $numberId = [string]$paragraph.NumberId
        $context = if ($stack.Count -gt $level) { $stack[$level] } else { $null }
        $requiresList = $null -eq $context -or $context.Name -cne $listName -or $context.NumberId -cne $numberId
        if ($requiresList) {
            while ($stack.Count -gt $level) { $stack.RemoveAt($stack.Count - 1) }
            if ($level -eq 0) {
                $listParent = $Parent
            } else {
                $parentContext = $stack[$level - 1]
                if ($null -eq $parentContext -or $null -eq $parentContext.LastItem) {
                    Throw-InvalidListHierarchy -Paragraph $paragraph -FallbackIndex $index -PreviousLevel $previousLevel -RequestedLevel $level -Target $Target -Language $Language
                }
                $listParent = $parentContext.LastItem
            }
            $list = Add-HtmlElement -Document $Document -Parent $listParent -Name $listName -Text $null
            $context = [pscustomobject]@{ Name = $listName; NumberId = $numberId; List = $list; LastItem = $null }
            [void]$stack.Add($context)
            if ($level -eq 0) { $roots += $list }
        }

        $item = Add-HtmlElement -Document $Document -Parent $context.List -Name 'li' -Text $null
        Add-InlineRuns -Document $Document -Parent $item -Runs @($paragraph.Runs)
        $context.LastItem = $item
        $previousLevel = $level
        $index++
    }

    return [pscustomobject]@{
        NextIndex = $index
        Roots = $roots
        Signature = @($roots | ForEach-Object { Get-ListTopologySignature -Node $_ })
    }
}

function Add-ParagraphSequence {
    param($Document, $Parent, [object[]]$Paragraphs, [string]$Target = 'unknown', [string]$Language = 'unknown')
    $signature = @()
    $index = 0
    while ($index -lt $Paragraphs.Count) {
        $paragraph = $Paragraphs[$index]
        if ($paragraph.Style -match '^Heading') { throw "Unexpected heading in paragraph sequence: $($paragraph.Text)" }
        if ($null -ne $paragraph.NumberId) {
            $listResult = Add-HierarchicalListSequence -Document $Document -Parent $Parent -Paragraphs $Paragraphs -StartIndex $index -Target $Target -Language $Language
            $signature += @($listResult.Signature)
            $index = $listResult.NextIndex
            continue
        }
        Add-SemanticParagraph -Document $Document -Parent $Parent -Paragraph $paragraph | Out-Null
        $signature += 'p'
        $index++
    }
    return $signature
}

function ConvertTo-SemanticHtml {
    param([Parameter(Mandatory = $true)][System.Xml.XmlDocument]$Document)
    $containers = @($Document.SelectNodes('//*[self::article or self::section or self::ul or self::ol]'))
    foreach ($container in $containers) {
        foreach ($node in @($container.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Whitespace -or ($_.NodeType -eq [System.Xml.XmlNodeType]::Text -and [string]::IsNullOrWhiteSpace($_.Value)) })) {
            [void]$container.RemoveChild($node)
        }
        $depth = 0
        $ancestor = $container.ParentNode
        while ($null -ne $ancestor -and $ancestor.NodeType -eq [System.Xml.XmlNodeType]::Element) { $depth++; $ancestor = $ancestor.ParentNode }
        $children = @($container.ChildNodes | Where-Object NodeType -eq ([System.Xml.XmlNodeType]::Element))
        foreach ($child in $children) {
            [void]$container.InsertBefore($Document.CreateWhitespace("`n" + ('    ' * ($depth + 1))), $child)
        }
        if ($children.Count) { [void]$container.AppendChild($Document.CreateWhitespace("`n" + ('    ' * $depth))) }
    }
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.OmitXmlDeclaration = $true
    $settings.Indent = $false
    $settings.NewLineChars = "`n"
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
    $builder = New-Object System.Text.StringBuilder
    $writer = [System.Xml.XmlWriter]::Create($builder, $settings)
    try { $Document.WriteTo($writer); $writer.Flush() } finally { $writer.Dispose() }
    return $builder.ToString().Trim() + "`n"
}

function Get-ProtectedHtmlNode {
    param([string]$Path, [string]$XPath)
    try { $document = [xml](Get-Content -LiteralPath $Path -Raw -Encoding UTF8) } catch { throw "Existing semantic HTML is not well-formed: $Path" }
    $node = $document.SelectSingleNode($XPath)
    if ($null -eq $node) { throw "Protected semantic node is missing in ${Path}: $XPath" }
    return $node
}

function Convert-AboutLanguage {
    param([object[]]$Paragraphs, [string]$Language, [string]$CurrentHtmlPath, $Schema)
    if ($Paragraphs.Count -lt 2) { throw "About $Language requires a title and prose." }
    if ($Paragraphs[0].Text.Trim() -cne [string]$Schema.title.$Language) { throw "Unexpected About title for ${Language}: $($Paragraphs[0].Text)" }
    $prose = @($Paragraphs[1..($Paragraphs.Count - 1)])
    if ($prose.Count -ne 4 -or @($prose | Where-Object { $_.Style -match '^Heading' -or $null -ne $_.NumberId }).Count -gt 0) {
        throw "About $Language must contain exactly four prose paragraphs."
    }

    $html = New-HtmlDocument -AttributeName 'data-page-id' -AttributeValue 'about'
    $identity = Get-ProtectedHtmlNode -Path $CurrentHtmlPath -XPath "/article/section[@id='identity']"
    [void]$html.Article.AppendChild($html.Document.ImportNode($identity, $true))
    $copy = Add-HtmlElement -Document $html.Document -Parent $html.Article -Name 'section' -Text $null -Attributes @{ id = 'about-copy' }
    Add-HtmlElement -Document $html.Document -Parent $copy -Name 'h2' -Text $Paragraphs[0].Text | Out-Null
    foreach ($paragraph in $prose) { Add-SemanticParagraph -Document $html.Document -Parent $copy -Paragraph $paragraph | Out-Null }
    $contact = Get-ProtectedHtmlNode -Path $CurrentHtmlPath -XPath "/article/section[@id='contact']"
    [void]$html.Article.AppendChild($html.Document.ImportNode($contact, $true))
    return [pscustomobject]@{ Html = ConvertTo-SemanticHtml $html.Document; Structure = 'about|p:4'; ParagraphCount = 4 }
}

function Split-TopSections {
    param([object[]]$Paragraphs, $LabelMap, [string]$Language)
    $sections = @()
    $current = $null
    foreach ($paragraph in $Paragraphs) {
        if ($paragraph.Style -eq 'Heading2') {
            $canonical = Get-MappedValue -Map $LabelMap -Label $paragraph.Text.Trim()
            if ($null -eq $canonical) { throw "Unknown $Language section heading: $($paragraph.Text)" }
            $current = [pscustomobject]@{ Id = $canonical; Heading = $paragraph; Items = @() }
            $sections += $current
        } else {
            if ($null -eq $current) { throw "Content appears before the first $Language section heading." }
            $current.Items += $paragraph
        }
    }
    return $sections
}

function Split-Subsections {
    param([object[]]$Paragraphs, [string]$Context)
    $sections = @()
    $current = $null
    foreach ($paragraph in $Paragraphs) {
        if ($paragraph.Style -eq 'Heading3') {
            $current = [pscustomobject]@{ Heading = $paragraph; Items = @() }
            $sections += $current
        } else {
            if ($null -eq $current) { throw "$Context content appears before its first Heading 3 entry." }
            $current.Items += $paragraph
        }
    }
    return $sections
}

function Get-CvLudographyModel {
    param([object[]]$Paragraphs, [string]$Language)
    $groups = Split-Subsections -Paragraphs $Paragraphs -Context "CV Ludography $Language"
    $model = @()
    foreach ($group in $groups) {
        $items = @($group.Items)
        if ($items.Count -eq 0 -or @($items | Where-Object { $null -eq $_.NumberId -or $_.ListLevel -notin @($null, 0) -or $_.ListFormat -eq 'bullet' }).Count -gt 0) {
            throw "CV Ludography group '$($group.Heading.Text)' must contain a flat ordered list."
        }
        $model += [pscustomobject]@{ Studio = $group.Heading.Text.Trim(); Games = @($items | ForEach-Object { $_.Text.Trim() }) }
    }
    return $model
}

function Get-OnlyDocxLink {
    param([object[]]$Paragraphs, [string]$Context)
    $runs = @($Paragraphs | ForEach-Object Runs | Where-Object { $_.Url -and -not [string]::IsNullOrWhiteSpace($_.Text) })
    if ($runs.Count -ne 1) { throw "$Context must contain exactly one hyperlink." }
    if (-not (Test-SafeContentUrl -Url $runs[0].Url)) { throw "$Context contains an unsafe URL." }
    return $runs[0]
}

function Convert-CvLanguage {
    param([object[]]$Paragraphs, [string]$Language, [string]$CurrentHtmlPath, $Schema)
    $sections = Split-TopSections -Paragraphs $Paragraphs -LabelMap $Schema.sections.$Language -Language $Language
    $expected = @('education', 'work-experience', 'ludography', 'downloads')
    if (($sections.Id -join '|') -cne ($expected -join '|')) { throw "CV $Language section order does not match the schema." }

    $html = New-HtmlDocument -AttributeName 'data-page-id' -AttributeValue 'cv'
    $signature = @()
    $ludography = $null
    $downloadText = $null
    foreach ($section in $sections) {
        $output = Add-HtmlElement -Document $html.Document -Parent $html.Article -Name 'section' -Text $null -Attributes @{ id = $section.Id }
        Add-HtmlElement -Document $html.Document -Parent $output -Name 'h2' -Text $section.Heading.Text | Out-Null
        if ($section.Id -in @('education', 'work-experience')) {
            $entries = Split-Subsections -Paragraphs @($section.Items) -Context "CV $Language $($section.Id)"
            $entrySignatures = @()
            foreach ($entry in $entries) {
                $child = Add-HtmlElement -Document $html.Document -Parent $output -Name 'section' -Text $null
                Add-HtmlElement -Document $html.Document -Parent $child -Name 'h3' -Text $entry.Heading.Text | Out-Null
                $bodySignature = @(Add-ParagraphSequence -Document $html.Document -Parent $child -Paragraphs @($entry.Items) -Target 'cv:main' -Language $Language)
                $entrySignatures += ($bodySignature -join ',')
            }
            $signature += "$($section.Id):$($entries.Count):$($entrySignatures -join ';')"
        } elseif ($section.Id -eq 'ludography') {
            $ludography = Get-CvLudographyModel -Paragraphs @($section.Items) -Language $Language
            $signature += "ludography:$($ludography.Count):$(@($ludography | ForEach-Object { $_.Games.Count }) -join ',')"
        } else {
            $link = Get-OnlyDocxLink -Paragraphs @($section.Items) -Context "CV Downloads $Language"
            if ($link.Text -match '(?i)portfolio' -or $link.Url -match '(?i)portfolio') { throw 'Download Portfolio is not permitted by the current publication contract.' }
            $sourceUri = [Uri]$link.Url
            if ($sourceUri.AbsolutePath -cne '/assets/downloads/cv/carlos-lopez-cv.pdf') { throw "Unexpected CV download target: $($link.Url)" }
            $protectedLink = Get-ProtectedHtmlNode -Path $CurrentHtmlPath -XPath "/article/section[@id='downloads']//*[@data-publication-item='cv']//a"
            $paragraph = Add-HtmlElement -Document $html.Document -Parent $output -Name 'p' -Text $null -Attributes @{ 'data-publication-group' = 'cv-downloads'; 'data-publication-item' = 'cv' }
            $strong = Add-HtmlElement -Document $html.Document -Parent $paragraph -Name 'strong' -Text $null
            Add-HtmlElement -Document $html.Document -Parent $strong -Name 'a' -Text $link.Text -Attributes @{ href = $protectedLink.GetAttribute('href') } | Out-Null
            $downloadText = $link.Text
            $signature += 'downloads:cv:1'
        }
    }
    return [pscustomobject]@{
        Html = ConvertTo-SemanticHtml $html.Document
        Structure = $signature -join '|'
        Ludography = $ludography
        DownloadText = $downloadText
        EducationCount = @($sections | Where-Object Id -eq 'education' | ForEach-Object { Split-Subsections @($_.Items) 'education' }).Count
        ExperienceCount = @($sections | Where-Object Id -eq 'work-experience' | ForEach-Object { Split-Subsections @($_.Items) 'experience' }).Count
    }
}

function ConvertTo-ContentFragmentId {
    param([Parameter(Mandatory = $true)][string]$Text, [Parameter(Mandatory = $true)][string]$Fallback)

    $builder = New-Object System.Text.StringBuilder
    foreach ($character in $Text.Normalize([Text.NormalizationForm]::FormD).ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($character)
        }
    }
    $fragment = ([regex]::Replace($builder.ToString().ToLowerInvariant(), '[^a-z0-9]+', '-')).Trim('-')
    return $(if ([string]::IsNullOrWhiteSpace($fragment)) { $Fallback } else { $fragment })
}

function Convert-GameLanguage {
    param([object[]]$Paragraphs, [string]$Language, [string]$GameId, $Schema)
    if ($Paragraphs.Count -lt 2) { throw "Game $Language document is incomplete." }
    $titleIndex = -1
    for ($index = 0; $index -lt $Paragraphs.Count; $index++) {
        if ($Paragraphs[$index].Style -eq 'Heading1') { $titleIndex = $index; break }
    }
    if ($titleIndex -lt 0) { throw "Game $Language title is missing." }
    $title = $Paragraphs[$titleIndex].Text.Trim()
    $metadata = [ordered]@{}
    $metadataOrder = @()
    $sourcePresence = [ordered]@{ year = $false; company = $false; platform = $false; access = $false; engine = $false }
    $metadataMap = $Schema.metadata.$Language
    $index = $titleIndex + 1
    while ($index -lt $Paragraphs.Count) {
        $labelParagraph = $Paragraphs[$index]
        $field = Get-MappedValue -Map $metadataMap -Label $labelParagraph.Text.Trim()
        if ($null -eq $field) { break }
        if ($labelParagraph.Style -ne 'Heading2') { throw "Game $Language metadata label '$($labelParagraph.Text)' must use Heading 2." }
        if ($metadata.Contains($field)) { throw "Duplicate Game $Language metadata field: $field" }
        $index++
        if ($index -ge $Paragraphs.Count) { throw "Game $Language metadata field '$field' has no value." }
        $valueParagraph = $Paragraphs[$index]
        $link = @($valueParagraph.Runs | Where-Object Url | Select-Object -First 1)
        $metadata[$field] = [pscustomobject]@{ Value = $valueParagraph.Text.Trim(); Url = if ($link.Count) { $link[0].Url } else { $null } }
        $metadataOrder += $field
        $sourcePresence[$field] = $true
        $index++
    }
    foreach ($field in @('year', 'company', 'platform', 'access', 'engine')) {
        if (-not $metadata.Contains($field)) { $metadata[$field] = [pscustomobject]@{ Value = '?'; Url = $null } }
    }

    $sections = @()
    $current = $null
    $currentSubsection = $null
    $sectionIds = @($Schema.sectionIds)
    if ($sectionIds.Count -eq 0) { throw 'Game section ID schema is empty.' }
    $fragmentCounts = @{}
    for (; $index -lt $Paragraphs.Count; $index++) {
        $paragraph = $Paragraphs[$index]
        if ($paragraph.Style -eq 'Heading2') {
            if ($sections.Count -ge $sectionIds.Count) { throw "Game $Language has more Heading 2 sections than the schema permits." }
            $sectionId = [string]$sectionIds[$sections.Count]
            $current = [pscustomobject]@{ Id = $sectionId; Heading = $paragraph; Paragraphs = @(); Subsections = @() }
            $sections += $current
            $currentSubsection = $null
        } elseif ($paragraph.Style -eq 'Heading3') {
            if ($null -eq $current) { throw "Game $Language Heading 3 appears before its parent Heading 2: $($paragraph.Text)" }
            $baseId = ConvertTo-ContentFragmentId -Text $paragraph.Text.Trim() -Fallback "subsection-$($current.Subsections.Count + 1)"
            $fragmentCounts[$baseId] = if ($fragmentCounts.ContainsKey($baseId)) { [int]$fragmentCounts[$baseId] + 1 } else { 1 }
            $subsectionId = if ($fragmentCounts[$baseId] -eq 1) { $baseId } else { "$baseId-$($fragmentCounts[$baseId])" }
            $currentSubsection = [pscustomobject]@{ Id = $subsectionId; Heading = $paragraph; Paragraphs = @() }
            $current.Subsections += $currentSubsection
        } else {
            if ($paragraph.Style -match '^Heading') { throw "Unsupported Game $Language heading level '$($paragraph.Style)': $($paragraph.Text)" }
            if ($null -eq $current) { throw "Game $Language prose appears outside a section." }
            if ($null -ne $currentSubsection) { $currentSubsection.Paragraphs += $paragraph } else { $current.Paragraphs += $paragraph }
        }
    }
    if (($sections.Id -join '|') -cne ($sectionIds -join '|')) { throw "Game $Language Heading 2 section count does not match the schema." }

    $html = New-HtmlDocument -AttributeName 'data-game-id' -AttributeValue $GameId
    $signature = @()
    foreach ($section in $sections) {
        $output = Add-HtmlElement -Document $html.Document -Parent $html.Article -Name 'section' -Text $null -Attributes @{ id = $section.Id }
        Add-HtmlElement -Document $html.Document -Parent $output -Name 'h2' -Text $section.Heading.Text | Out-Null
        $direct = @(Add-ParagraphSequence -Document $html.Document -Parent $output -Paragraphs @($section.Paragraphs) -Target "game:$GameId" -Language $Language)
        $subSignatures = @()
        foreach ($subsection in $section.Subsections) {
            $child = Add-HtmlElement -Document $html.Document -Parent $output -Name 'section' -Text $null -Attributes @{ id = $subsection.Id }
            Add-HtmlElement -Document $html.Document -Parent $child -Name 'h3' -Text $subsection.Heading.Text | Out-Null
            $body = @(Add-ParagraphSequence -Document $html.Document -Parent $child -Paragraphs @($subsection.Paragraphs) -Target "game:$GameId" -Language $Language)
            $subSignatures += "h3:$($body -join ',')"
        }
        $signature += "$($section.Id):h2:$($direct -join ','):$($subSignatures -join ';')"
    }
    return [pscustomobject]@{
        Html = ConvertTo-SemanticHtml $html.Document
        Structure = $signature -join '|'
        Title = $title
        Metadata = [pscustomobject]$metadata
        MetadataOrder = $metadataOrder
        SourcePresence = [pscustomobject]$sourcePresence
        Sections = @($sections | ForEach-Object Id)
        SectionHeadings = @($sections | ForEach-Object { $_.Heading.Text })
        Subsections = @($sections | ForEach-Object Subsections | ForEach-Object { $_.Heading.Text })
        HeadingTopology = @($sections | ForEach-Object { "h2[$(@($_.Subsections | ForEach-Object { 'h3' }) -join ',')]" }) -join '|'
    }
}

function Assert-CvParity {
    param($Spanish, $English)
    if ($Spanish.Structure -cne $English.Structure) { throw 'CV ES/EN semantic structures are not equivalent.' }
    $esGroups = @($Spanish.Ludography)
    $enGroups = @($English.Ludography)
    if ($esGroups.Count -ne $enGroups.Count) { throw 'CV ES/EN Ludography group counts differ.' }
    for ($index = 0; $index -lt $esGroups.Count; $index++) {
        if ($esGroups[$index].Studio -cne $enGroups[$index].Studio -or ($esGroups[$index].Games -join '|') -cne ($enGroups[$index].Games -join '|')) {
            throw 'CV ES/EN Ludography order differs.'
        }
    }
}

function Assert-GameParity {
    param($Spanish, $English)
    if ($Spanish.Structure -cne $English.Structure) { throw 'Game ES/EN semantic structures are not equivalent.' }
    if ($Spanish.Title -cne $English.Title) { throw 'Game ES/EN titles differ.' }
    if (($Spanish.MetadataOrder -join '|') -cne ($English.MetadataOrder -join '|')) { throw 'Game ES/EN metadata field order differs.' }
    foreach ($field in @('year', 'company', 'platform', 'access', 'engine')) {
        if ($Spanish.SourcePresence.$field -ne $English.SourcePresence.$field) { throw "Game ES/EN metadata presence differs for $field." }
        if ($Spanish.Metadata.$field.Value -cne $English.Metadata.$field.Value) { throw "Game ES/EN metadata values differ for $field." }
        if ([string]$Spanish.Metadata.$field.Url -cne [string]$English.Metadata.$field.Url) { throw "Game ES/EN metadata URLs differ for $field." }
    }
}

function ConvertTo-StableJson {
    param($Value, [int]$Depth = 0)
    $indent = '  ' * $Depth
    $childIndent = '  ' * ($Depth + 1)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [string] -or $Value -is [char]) { return ($Value.ToString() | ConvertTo-Json -Compress) }
    if ($Value -is [bool]) { return $(if ($Value) { 'true' } else { 'false' }) }
    if ($Value -is [ValueType]) { return [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture) }
    if ($Value -is [System.Collections.IDictionary]) {
        $pairs = @()
        foreach ($key in $Value.Keys) { $pairs += "$childIndent$(ConvertTo-StableJson ([string]$key)): $(ConvertTo-StableJson $Value[$key] ($Depth + 1))" }
        if ($pairs.Count -eq 0) { return '{}' }
        return "{`n$($pairs -join ",`n")`n$indent}"
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = @($Value | ForEach-Object { "$childIndent$(ConvertTo-StableJson $_ ($Depth + 1))" })
        if ($items.Count -eq 0) { return '[]' }
        return "[`n$($items -join ",`n")`n$indent]"
    }
    $properties = @($Value.PSObject.Properties | Where-Object MemberType -in @('NoteProperty', 'Property'))
    $pairs = @($properties | ForEach-Object { "$childIndent$(ConvertTo-StableJson $_.Name): $(ConvertTo-StableJson $_.Value ($Depth + 1))" })
    if ($pairs.Count -eq 0) { return '{}' }
    return "{`n$($pairs -join ",`n")`n$indent}"
}

function New-UpdatedGameRegistry {
    param([string]$RepositoryRoot, [object[]]$GameItems, $Config)
    $path = Join-Path $RepositoryRoot 'data\games.json'
    $registry = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $games = @($registry.games)
    $protected = @($Config.contentTypes.game.protectedFields)
    $updatedGames = [ordered]@{}
    $missingFields = @()
    foreach ($item in $GameItems) {
        $gameIndex = -1
        for ($index = 0; $index -lt $games.Count; $index++) { if ($games[$index].id -ceq $item.Id) { $gameIndex = $index; break } }
        if ($gameIndex -lt 0) { throw "Game registry entry is missing: $($item.Id)" }
        $current = $games[$gameIndex]
        $metadata = $item.Summary.en.Metadata
        $accessUrl = if ($metadata.access.Value -eq '?') { $null } elseif ($metadata.access.Url) { $metadata.access.Url } elseif (Test-SafeContentUrl $metadata.access.Value) { $metadata.access.Value } else { throw "Game Access must be an authored safe URL: $($item.Id)" }
        if ($null -ne $accessUrl -and -not (Test-SafeContentUrl $accessUrl)) { throw "Game Access URL is unsafe: $($item.Id)" }
        $updates = [ordered]@{
            title = $item.Summary.en.Title
            studio = $metadata.company.Value
            year = $metadata.year.Value
            platform = $metadata.platform.Value
            accessUrl = $accessUrl
            engineName = if ($metadata.engine.Value -eq '?') { $null } else { $metadata.engine.Value }
        }
        $updated = [ordered]@{}
        foreach ($property in $current.PSObject.Properties) {
            if ($property.Name -in @('year', 'platform', 'accessUrl', 'engineName')) { continue }
            if ($updates.Contains($property.Name)) { $updated[$property.Name] = $updates[$property.Name] } else { $updated[$property.Name] = $property.Value }
            if ($property.Name -eq 'published') {
                $updated.year = $updates.year
                $updated.platform = $updates.platform
                $updated.accessUrl = $updates.accessUrl
                $updated.engineName = $updates.engineName
            }
        }
        $updatedGame = [pscustomobject]$updated
        foreach ($field in $protected) {
            if ($field -eq 'registryOrder') { continue }
            $beforeProperty = $current.PSObject.Properties[$field]
            $afterProperty = $updatedGame.PSObject.Properties[$field]
            $before = if ($beforeProperty) { ConvertTo-StableJson $beforeProperty.Value } else { '<absent>' }
            $after = if ($afterProperty) { ConvertTo-StableJson $afterProperty.Value } else { '<absent>' }
            if ($before -cne $after) { throw "Protected Game field changed for $($item.Id): $field" }
        }
        $games[$gameIndex] = $updatedGame
        $updatedGames[$item.Id] = $updatedGame
        $missingFields += [pscustomobject]@{ GameId = $item.Id; Fields = @($item.Summary.en.SourcePresence.PSObject.Properties | Where-Object { -not $_.Value } | ForEach-Object Name) }
    }
    $registry.games = $games
    return [pscustomobject]@{
        Json = (ConvertTo-StableJson $registry) + "`n"
        Games = [pscustomobject]$updatedGames
        Warnings = @()
        ProtectedFields = $protected
        MissingFields = $missingFields
    }
}

function New-ContentImportPlan {
    param(
        [string]$RepositoryRoot = (Get-ContentPipelineRepositoryRoot),
        [switch]$IncludeUnchanged
    )
    $scan = Get-ContentInboxScan -RepositoryRoot $RepositoryRoot
    if ($scan.Counts.INVALID -gt 0) {
        $details = @($scan.Entries | Where-Object Status -eq 'INVALID' | ForEach-Object { "$($_.Source): $($_.Reason)" }) -join '; '
        throw "Inbox preflight failed: $details"
    }
    $config = Get-ContentPipelineConfig -RepositoryRoot $RepositoryRoot
    $items = @()
    $gameItems = @()
    $candidateStatuses = if ($IncludeUnchanged) { @('NEW', 'CHANGED', 'UNCHANGED') } else { @('NEW', 'CHANGED') }
    foreach ($entry in @($scan.Entries | Where-Object Status -in $candidateStatuses)) {
        $identity = ConvertTo-ContentSourceIdentity -FileName $entry.Source -Config $config
        $target = Resolve-ContentPipelineTarget -Identity $identity -RepositoryRoot $RepositoryRoot -Config $config
        $sourcePath = Join-Path (Get-ContentPipelinePaths -RepositoryRoot $RepositoryRoot).Inbox $entry.Source
        $blocks = Split-BilingualDocx (Read-DocxDocument -Path $sourcePath)
        $outputs = [ordered]@{}
        $summary = $null
        switch ($identity.Type) {
            'about' {
                $esPath = Join-Path $RepositoryRoot 'content\about\es.html'
                $enPath = Join-Path $RepositoryRoot 'content\about\en.html'
                $es = Convert-AboutLanguage -Paragraphs $blocks.es -Language 'es' -CurrentHtmlPath $esPath -Schema $config.importSchemas.about
                $en = Convert-AboutLanguage -Paragraphs $blocks.en -Language 'en' -CurrentHtmlPath $enPath -Schema $config.importSchemas.about
                if ($es.Structure -cne $en.Structure) { throw 'About ES/EN semantic structures are not equivalent.' }
                $outputs['content/about/es.html'] = $es.Html
                $outputs['content/about/en.html'] = $en.Html
                $summary = [pscustomobject]@{ esParagraphs = $es.ParagraphCount; enParagraphs = $en.ParagraphCount; structure = $es.Structure }
            }
            'cv' {
                $esPath = Join-Path $RepositoryRoot 'content\cv\es.html'
                $enPath = Join-Path $RepositoryRoot 'content\cv\en.html'
                $es = Convert-CvLanguage -Paragraphs $blocks.es -Language 'es' -CurrentHtmlPath $esPath -Schema $config.importSchemas.cv
                $en = Convert-CvLanguage -Paragraphs $blocks.en -Language 'en' -CurrentHtmlPath $enPath -Schema $config.importSchemas.cv
                Assert-CvParity -Spanish $es -English $en
                $outputs['content/cv/es.html'] = $es.Html
                $outputs['content/cv/en.html'] = $en.Html
                $summary = [pscustomobject]@{
                    esEducation = $es.EducationCount; enEducation = $en.EducationCount
                    esExperience = $es.ExperienceCount; enExperience = $en.ExperienceCount
                    ludographyGroups = @($es.Ludography).Count; download = 'cv'; structure = $es.Structure
                }
            }
            'game' {
                $es = Convert-GameLanguage -Paragraphs $blocks.es -Language 'es' -GameId $identity.Id -Schema $config.importSchemas.game
                $en = Convert-GameLanguage -Paragraphs $blocks.en -Language 'en' -GameId $identity.Id -Schema $config.importSchemas.game
                Assert-GameParity -Spanish $es -English $en
                $outputs["content/games/$($identity.Id)/es.html"] = $es.Html
                $outputs["content/games/$($identity.Id)/en.html"] = $en.Html
                $summary = [pscustomobject]@{ es = $es; en = $en }
            }
            default { throw "Import Engine #02 does not yet implement content type: $($identity.Type)" }
        }
        $item = [pscustomobject][ordered]@{
            TargetKey = $target.TargetKey
            Type = $target.Type
            Id = $target.Id
            Status = $entry.Status
            Source = $entry.Source
            SourcePath = $sourcePath
            Sha256 = $entry.Sha256
            CanonicalFile = $target.CanonicalFile
            MirrorFile = $target.MirrorFile
            Outputs = $outputs
            ProtectedFields = @($target.ProtectedFields)
            Summary = $summary
        }
        $items += $item
        if ($identity.Type -eq 'game') { $gameItems += $item }
    }

    $registryUpdate = $null
    $warnings = @()
    if ($gameItems.Count -gt 0) {
        $registryUpdate = New-UpdatedGameRegistry -RepositoryRoot $RepositoryRoot -GameItems $gameItems -Config $config
        $warnings += @($registryUpdate.Warnings)
    }
    return [pscustomobject][ordered]@{
        SchemaVersion = 1
        ImporterVersion = [int]$config.importerVersion
        Scan = $scan
        Items = $items
        GameRegistry = $registryUpdate
        Warnings = $warnings
        BatchValid = $true
    }
}

function Format-ContentImportPlan {
    param([Parameter(Mandatory = $true)]$Plan)
    $lines = @(
        '============================================================',
        'CONTENT IMPORT - DRY RUN',
        '============================================================',
        "TOTAL DOCX: $($Plan.Scan.TotalDocx)",
        "NEW: $($Plan.Scan.Counts.NEW)",
        "CHANGED: $($Plan.Scan.Counts.CHANGED)",
        "UNCHANGED: $($Plan.Scan.Counts.UNCHANGED)",
        "INVALID: $($Plan.Scan.Counts.INVALID)"
    )
    foreach ($item in $Plan.Items) {
        $lines += '------------------------------------------------------------'
        $lines += "TARGET: $($item.TargetKey)"
        $lines += "STATUS: $($item.Status)"
        $lines += "SOURCE: $($item.Source)"
        $lines += "SHA256: $($item.Sha256)"
        $lines += 'OUTPUTS:'
        $lines += @($item.Outputs.Keys | ForEach-Object { "  $_" })
        if ($item.Type -eq 'about') {
            $lines += "SPANISH: $($item.Summary.esParagraphs) paragraphs"
            $lines += "ENGLISH: $($item.Summary.enParagraphs) paragraphs"
            $lines += 'STRUCTURAL DATA: NONE'
        } elseif ($item.Type -eq 'cv') {
            $lines += "EDUCATION: ES $($item.Summary.esEducation) / EN $($item.Summary.enEducation)"
            $lines += "PROFESSIONAL EXPERIENCE: ES $($item.Summary.esExperience) / EN $($item.Summary.enExperience)"
            $lines += "LUDOGRAPHY GROUPS: $($item.Summary.ludographyGroups) (runtime registry-owned)"
            $lines += 'DOWNLOADS: CV only (publication-gated)'
        } else {
            $metadata = $item.Summary.en.Metadata
            $lines += 'DOCX METADATA:'
            $lines += "  Year: $($metadata.year.Value)"
            $lines += "  Company: $($metadata.company.Value)"
            $lines += "  Platform: $($metadata.platform.Value)"
            $lines += "  Access: $($metadata.access.Url)"
            $lines += "  Engine: $($metadata.engine.Value)"
            $lines += "EDITORIAL SECTIONS: $($item.Summary.en.Sections -join ', ')"
            $lines += "CONTRIBUTION SUBSECTIONS: $($item.Summary.en.Subsections -join ', ')"
        }
        $lines += "PROTECTED SYSTEM FIELDS: $($item.ProtectedFields -join ', ')"
    }
    $lines += '------------------------------------------------------------'
    $lines += 'BATCH VALID: YES'
    if ($Plan.Warnings.Count) { $lines += "WARNINGS: $($Plan.Warnings -join '; ')" } else { $lines += 'WARNINGS: NONE' }
    $lines += 'No mutation performed by this dry-run plan.'
    return $lines -join "`n"
}

function Copy-ContentFileAtomically {
    param([string]$Source, [string]$Destination)
    $directory = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $temporary = Join-Path $directory ('.content-pipeline-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $replaceBackup = $temporary + '.replace-backup'
    try {
        Copy-Item -LiteralPath $Source -Destination $temporary
        if (Test-Path -LiteralPath $Destination -PathType Leaf) {
            [System.IO.File]::Replace($temporary, $Destination, $replaceBackup)
        } else {
            [System.IO.File]::Move($temporary, $Destination)
        }
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
        if (Test-Path -LiteralPath $replaceBackup) { Remove-Item -LiteralPath $replaceBackup -Force }
    }
}

function Remove-ContentTransactionDirectory {
    param([string]$Path, [string]$StateRoot)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $transactionsRoot = [System.IO.Path]::GetFullPath((Join-Path $StateRoot 'transactions'))
    $prefix = $transactionsRoot.TrimEnd('\') + '\'
    if (-not $resolvedPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe transaction cleanup path: $resolvedPath" }
    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

function New-UpdatedManifestText {
    param($Plan, [string]$ImportedUtc, [string]$RepositoryRoot)
    $paths = Get-ContentPipelinePaths -RepositoryRoot $RepositoryRoot
    $manifest = Read-ContentPipelineManifest -Path $paths.Manifest
    $entries = [ordered]@{}
    foreach ($property in $manifest.entries.PSObject.Properties) { $entries[$property.Name] = $property.Value }
    foreach ($item in $Plan.Items) {
        $archivePath = Join-Path $RepositoryRoot "local-content\archive\$($item.Type)\$($item.Id)"
        $archiveCount = if (Test-Path -LiteralPath $archivePath) { @(Get-ChildItem -LiteralPath $archivePath -File -Filter '*.docx').Count } else { 0 }
        $entries[$item.TargetKey] = [ordered]@{
            targetKey = $item.TargetKey
            sourceFile = $item.Source
            sha256 = $item.Sha256
            lastImportedUtc = $ImportedUtc
            canonicalFile = $item.CanonicalFile
            mirrorFile = $item.MirrorFile
            archiveCount = $archiveCount
            outputs = @($item.Outputs.Keys)
            importerVersion = $Plan.ImporterVersion
        }
    }
    return (ConvertTo-StableJson ([ordered]@{ schemaVersion = 1; entries = $entries })) + "`n"
}

function Invoke-ContentImportApply {
    param([Parameter(Mandatory = $true)]$Plan, [string]$RepositoryRoot = (Get-ContentPipelineRepositoryRoot))
    if (-not $Plan.BatchValid) { throw 'Cannot apply an invalid import plan.' }
    if ($Plan.Items.Count -eq 0) { return [pscustomobject]@{ Applied = $false; Qa = 'NOT REQUIRED'; Archives = @(); ImportedUtc = $null } }

    $paths = Get-ContentPipelinePaths -RepositoryRoot $RepositoryRoot
    $transactionRoot = Join-Path $paths.State ("transactions\" + [Guid]::NewGuid().ToString('N'))
    $stageRoot = Join-Path $transactionRoot 'stage'
    $backupRoot = Join-Path $transactionRoot 'backup'
    New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $destinations = @()
    $stageMap = [ordered]@{}
    foreach ($item in $Plan.Items) {
        foreach ($relative in $item.Outputs.Keys) {
            $stage = Join-Path $stageRoot ($relative.Replace('/', '\'))
            New-Item -ItemType Directory -Path (Split-Path -Parent $stage) -Force | Out-Null
            Write-Utf8NoBom -Path $stage -Content $item.Outputs[$relative]
            try { [void][xml](Get-Content -LiteralPath $stage -Raw -Encoding UTF8) } catch { throw "Generated HTML is invalid: $relative" }
            $destination = Join-Path $RepositoryRoot ($relative.Replace('/', '\'))
            $stageMap[$destination] = $stage
            $destinations += $destination
        }
    }
    if ($null -ne $Plan.GameRegistry) {
        $stage = Join-Path $stageRoot 'data\games.json'
        New-Item -ItemType Directory -Path (Split-Path -Parent $stage) -Force | Out-Null
        Write-Utf8NoBom -Path $stage -Content $Plan.GameRegistry.Json
        try { Get-Content -LiteralPath $stage -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null } catch { throw 'Generated data/games.json is invalid.' }
        $destination = Join-Path $RepositoryRoot 'data\games.json'
        $stageMap[$destination] = $stage
        $destinations += $destination
    }
    foreach ($item in $Plan.Items) {
        $destinations += Join-Path $RepositoryRoot ($item.CanonicalFile.Replace('/', '\'))
        $destinations += Join-Path $RepositoryRoot ($item.MirrorFile.Replace('/', '\'))
    }
    $destinations += $paths.Manifest
    $destinations = @($destinations | Select-Object -Unique)
    $backups = @()
    for ($index = 0; $index -lt $destinations.Count; $index++) {
        $destination = $destinations[$index]
        $exists = Test-Path -LiteralPath $destination -PathType Leaf
        $backup = Join-Path $backupRoot ("$index.bin")
        if ($exists) { Copy-Item -LiteralPath $destination -Destination $backup }
        $backups += [pscustomobject]@{ Destination = $destination; Existed = $exists; Backup = $backup }
    }

    $archives = @()
    $qaOutput = @()
    $importedUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $archiveTimestamp = [DateTime]::Parse($importedUtc).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    try {
        foreach ($destination in $stageMap.Keys) { Copy-ContentFileAtomically -Source $stageMap[$destination] -Destination $destination }

        if (Get-Command node -ErrorAction SilentlyContinue) {
            $qaOutput = @(& node (Join-Path $RepositoryRoot 'tools\qa-frontend.mjs') 2>&1)
            if ($LASTEXITCODE -ne 0) { throw "Frontend QA failed: $($qaOutput -join ' ')" }
            $qaStatus = 'PASS'
        } else {
            $qaStatus = 'SKIPPED - Node unavailable'
        }

        foreach ($item in $Plan.Items) {
            $canonical = Join-Path $RepositoryRoot ($item.CanonicalFile.Replace('/', '\'))
            if ((Test-Path -LiteralPath $canonical -PathType Leaf) -and (Get-ContentFileSha256 -Path $canonical) -cne $item.Sha256) {
                $oldHash = Get-ContentFileSha256 -Path $canonical
                $archiveDirectory = Join-Path $RepositoryRoot "local-content\archive\$($item.Type)\$($item.Id)"
                if (-not (Test-Path -LiteralPath $archiveDirectory)) { New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null }
                $archive = Join-Path $archiveDirectory ("${archiveTimestamp}__$($oldHash.Substring(0, 12)).docx")
                if (Test-Path -LiteralPath $archive) { throw "Archive collision: $archive" }
                Copy-Item -LiteralPath $canonical -Destination $archive
                $archives += $archive
            }
            Copy-ContentFileAtomically -Source $item.SourcePath -Destination $canonical
            $mirror = Join-Path $RepositoryRoot ($item.MirrorFile.Replace('/', '\'))
            Copy-ContentFileAtomically -Source $item.SourcePath -Destination $mirror
            if ((Get-ContentFileSha256 $canonical) -cne $item.Sha256 -or (Get-ContentFileSha256 $mirror) -cne $item.Sha256) {
                throw "Canonical or mirror hash mismatch for $($item.TargetKey)."
            }
        }

        $manifestStage = Join-Path $stageRoot 'manifest.json'
        Write-Utf8NoBom -Path $manifestStage -Content (New-UpdatedManifestText -Plan $Plan -ImportedUtc $importedUtc -RepositoryRoot $RepositoryRoot)
        Read-ContentPipelineManifest -Path $manifestStage | Out-Null
        Copy-ContentFileAtomically -Source $manifestStage -Destination $paths.Manifest
        Remove-ContentTransactionDirectory -Path $transactionRoot -StateRoot $paths.State
        return [pscustomobject]@{ Applied = $true; Qa = $qaStatus; QaOutput = $qaOutput; Archives = $archives; ImportedUtc = $importedUtc }
    } catch {
        $originalError = $_
        $rollbackErrors = @()
        for ($index = $backups.Count - 1; $index -ge 0; $index--) {
            $record = $backups[$index]
            try {
                if ($record.Existed) { Copy-ContentFileAtomically -Source $record.Backup -Destination $record.Destination }
                elseif (Test-Path -LiteralPath $record.Destination -PathType Leaf) { Remove-Item -LiteralPath $record.Destination -Force }
            } catch { $rollbackErrors += $_.Exception.Message }
        }
        foreach ($archive in $archives) {
            try { if (Test-Path -LiteralPath $archive -PathType Leaf) { Remove-Item -LiteralPath $archive -Force } } catch { $rollbackErrors += $_.Exception.Message }
        }
        try { Remove-ContentTransactionDirectory -Path $transactionRoot -StateRoot $paths.State } catch { $rollbackErrors += $_.Exception.Message }
        if ($rollbackErrors.Count) { throw "$($originalError.Exception.Message) Rollback errors: $($rollbackErrors -join '; ')" }
        throw $originalError
    }
}

function Format-ContentImportReport {
    param($Plan, $Result)
    $lines = @(
        '============================================================',
        'CONTENT IMPORT - RESULT',
        '============================================================',
        "IMPORTED UTC: $($Result.ImportedUtc)",
        "FILES DISCOVERED: $($Plan.Scan.TotalDocx)",
        "NEW: $($Plan.Scan.Counts.NEW)",
        "CHANGED: $($Plan.Scan.Counts.CHANGED)",
        "UNCHANGED: $($Plan.Scan.Counts.UNCHANGED)",
        "INVALID: $($Plan.Scan.Counts.INVALID)",
        'VALIDATION: PASS',
        'ES/EN PARITY: PASS',
        'BATCH ATOMICITY: PASS'
    )
    foreach ($item in $Plan.Items) {
        $lines += '------------------------------------------------------------'
        $lines += "TARGET: $($item.TargetKey)"
        $lines += "SOURCE: $($item.Source)"
        $lines += "SHA256: $($item.Sha256)"
        $lines += "OUTPUTS: $($item.Outputs.Keys -join ', ')"
        $lines += "PROTECTED: $($item.ProtectedFields -join ', ')"
        $lines += "CANONICAL: $($item.CanonicalFile)"
        $lines += "MIRROR: $($item.MirrorFile)"
    }
    $lines += '------------------------------------------------------------'
    $lines += "ARCHIVE ACTIONS: $(if ($Result.Archives.Count) { $Result.Archives -join ', ' } else { 'NONE - first accepted versions' })"
    $lines += 'MANIFEST ACTION: accepted hashes written after QA'
    $lines += "QA: $($Result.Qa)"
    if ($Result.QaOutput.Count) { $lines += @($Result.QaOutput) }
    $lines += "WARNINGS: $(if ($Plan.Warnings.Count) { $Plan.Warnings -join '; ' } else { 'NONE' })"
    return $lines -join "`n"
}
