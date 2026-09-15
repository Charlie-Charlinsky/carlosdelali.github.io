Set-StrictMode -Version Latest

function ConvertTo-GameAliasKey {
    param([string]$Text)
    return ([regex]::Replace($Text.Normalize([Text.NormalizationForm]::FormC).Trim(), '\s+', ' ')).ToUpperInvariant()
}

function Get-GameAliasMatches {
    param($Schema, [string]$Language, [string]$Text, [switch]$AllLocales)
    $key = ConvertTo-GameAliasKey $Text
    $locales = if ($AllLocales) { @($Schema.schemaSubsections.PSObject.Properties.Name) } else { @($Language) }
    foreach ($locale in $locales) {
        foreach ($alias in $Schema.schemaSubsections.$locale.PSObject.Properties) {
            if ((ConvertTo-GameAliasKey $alias.Name) -ceq $key) {
                [pscustomobject]@{ Language = $locale; Text = $alias.Name; Field = [string]$alias.Value }
            }
        }
    }
}

function New-GameSemanticNode {
    param($Paragraph, [int]$Index, [string]$Language, $Schema)
    $aliases = @(Get-GameAliasMatches -Schema $Schema -Language $Language -Text $Paragraph.Text)
    $fields = @($aliases | ForEach-Object Field | Select-Object -Unique)
    $wordLevel = if ($Paragraph.Style -match '^Heading([1-9])$') { [int]$Matches[1] } else { $null }
    return [pscustomobject]@{
        NodeIndex = $Index
        ParagraphIndex = $Paragraph.ParagraphIndex
        Language = $Language
        Text = $Paragraph.Text
        WordStyle = $Paragraph.Style
        WordLevel = $wordLevel
        AliasMatches = $aliases
        AliasField = if ($fields.Count -eq 1) { $fields[0] } else { $null }
        AmbiguousAlias = $fields.Count -gt 1
        SemanticId = $null
        SemanticLevel = $null
        ParentId = $null
        SectionId = $null
        Kind = 'p'
        ListLevel = $Paragraph.ListLevel
        ListFormat = $Paragraph.ListFormat
        IsList = $null -ne $Paragraph.NumberId
    }
}

function Set-GameNodeRole {
    param($Node, [string]$Kind, [string]$SemanticId, $Level, [string]$ParentId, [string]$SectionId = '')
    $Node.Kind = $Kind
    $Node.SemanticId = $SemanticId
    $Node.SemanticLevel = $Level
    $Node.ParentId = $ParentId
    $Node.SectionId = $SectionId
}

function Get-GameNodeKey {
    param($Node)
    if ($null -eq $Node) { return '<missing>' }
    return @($Node.Kind, $Node.SemanticId, $Node.SemanticLevel, $Node.ParentId, $Node.IsList, $Node.ListLevel, $Node.ListFormat) -join '|'
}

function New-GameParityDiagnostic {
    param($Spanish, $English, [int]$Index, [string]$Reason, [string]$Cause = 'TRUE_AUTHORING_TOPOLOGY_MISMATCH')
    return [pscustomobject]@{
        Target = $Spanish.TargetKey
        Success = $false
        Classification = 'AMBIGUOUS'
        Cause = $Cause
        Reason = $Reason
        NodeIndex = $Index
        Expected = if ($Index -lt $Spanish.SemanticNodes.Count) { $Spanish.SemanticNodes[$Index] } else { $null }
        Actual = if ($Index -lt $English.SemanticNodes.Count) { $English.SemanticNodes[$Index] } else { $null }
        Repair = $null
    }
}

function Get-GameParityDiagnostic {
    param($Spanish, $English)
    try { Assert-GameSharedData -Spanish $Spanish -English $English } catch {
        $message = $_.Exception.Message
        $index = 0
        foreach ($node in $English.SemanticNodes) {
            if ($node.Kind -eq 'metadata-value' -and $message -match [regex]::Escape($node.SemanticId)) { $index = $node.NodeIndex; break }
        }
        return New-GameParityDiagnostic $Spanish $English $index $message
    }
    $count = [Math]::Max($Spanish.SemanticNodes.Count, $English.SemanticNodes.Count)
    for ($index = 0; $index -lt $count; $index++) {
        $es = if ($index -lt $Spanish.SemanticNodes.Count) { $Spanish.SemanticNodes[$index] } else { $null }
        $en = if ($index -lt $English.SemanticNodes.Count) { $English.SemanticNodes[$index] } else { $null }
        if (($null -ne $es -and $es.AmbiguousAlias) -or ($null -ne $en -and $en.AmbiguousAlias)) {
            return New-GameParityDiagnostic $Spanish $English $index 'An exact normalized alias identifies competing semantic fields.' 'SEMANTIC_ID_RESOLUTION_BUG'
        }
        if ((Get-GameNodeKey $es) -cne (Get-GameNodeKey $en)) {
            return New-GameParityDiagnostic $Spanish $English $index 'Semantic ID, level, parent, sibling order or body/list boundaries differ.'
        }
    }
    if ($Spanish.Structure -cne $English.Structure) {
        return New-GameParityDiagnostic $Spanish $English 0 'Compiled paragraph/list grouping differs despite equivalent node roles.' 'PARITY_ENGINE_BUG'
    }
    return [pscustomobject]@{ Target = $Spanish.TargetKey; Success = $true; Classification = 'SUCCESS'; Cause = $null; Reason = 'Equivalent semantic trees and shared data.'; NodeIndex = -1; Expected = $null; Actual = $null; Repair = $null }
}

function Format-GameParityDiagnostic {
    param($Diagnostic)
    $lines = @("TARGET: $($Diagnostic.Target)", "CLASSIFICATION: $($Diagnostic.Classification)", "CAUSE: $($Diagnostic.Cause)", "REASON: $($Diagnostic.Reason)")
    foreach ($side in @('Expected', 'Actual')) {
        $lines += "$($side.ToUpperInvariant()) COUNTERPART:"
        $node = $Diagnostic.$side
        if ($null -eq $node) { $lines += 'NODE: MISSING'; continue }
        $lines += @("LANGUAGE: $($node.Language)", "NODE INDEX: $($node.NodeIndex)", "SOURCE PARAGRAPH INDEX: $($node.ParagraphIndex)", "SOURCE TEXT: $($node.Text)", "WORD STYLE: $($node.WordStyle)", "WORD LEVEL: $($node.WordLevel)", "SCHEMA ALIAS: $($node.AliasField)", "SEMANTIC ID: $($node.SemanticId)", "SEMANTIC LEVEL: $($node.SemanticLevel)", "PARENT ID: $($node.ParentId)", "SECTION ID: $($node.SectionId)", "TYPE: $($node.Kind)")
    }
    if ($null -ne $Diagnostic.Repair) {
        $lines += @(
            "REPAIR PASS: $($Diagnostic.Repair.RepairPass)",
            "SOURCE LOCALE: $($Diagnostic.Repair.SourceLocale)",
            "TARGET LOCALE: $($Diagnostic.Repair.TargetLocale)",
            "KNOWN SEMANTIC ID: $($Diagnostic.Repair.KnownSemanticId)",
            "LOCAL ALIAS ADDED: $($Diagnostic.Repair.LocalAlias)",
            "SCOPE: $($Diagnostic.Repair.Scope)"
        )
    }
    return $lines -join "`n"
}

function Throw-GameParityDiagnostic {
    param($Diagnostic)
    $exception = New-Object System.IO.InvalidDataException (Format-GameParityDiagnostic $Diagnostic)
    $exception.Data['ContentPipelineExitCode'] = if ($Diagnostic.Classification -eq 'SAFE_REPAIRABLE' -or $Diagnostic.Cause -eq 'PARITY_ENGINE_BUG' -or $Diagnostic.Cause -eq 'SEMANTIC_ID_RESOLUTION_BUG') { 4 } else { 2 }
    $exception.Data['GameParityDiagnostic'] = $Diagnostic
    throw $exception
}

function Assert-GameParity {
    param($Spanish, $English)
    $diagnostic = Get-GameParityDiagnostic -Spanish $Spanish -English $English
    if (-not $diagnostic.Success) { Throw-GameParityDiagnostic $diagnostic }
}

function Get-GameAliasRepair {
    param($Spanish, $English, $Schema, $Blocks, [int]$ValidationBudget = 3)
    $diagnostic = Get-GameParityDiagnostic $Spanish $English
    if ($diagnostic.Success) { return $diagnostic }
    $es = $diagnostic.Expected
    $en = $diagnostic.Actual
    if ($null -eq $es -or $null -eq $en -or $Spanish.SemanticNodes.Count -ne $English.SemanticNodes.Count) { return $diagnostic }
    $known = $null
    $unknown = $null
    if ($es.Kind -eq 'h3' -and $en.Kind -eq 'p') { $known = $es; $unknown = $en }
    if ($en.Kind -eq 'h3' -and $es.Kind -eq 'p') { $known = $en; $unknown = $es }
    if ($null -eq $known -or -not $known.AliasField -or $unknown.WordStyle -cne 'Normal' -or $unknown.IsList -or $unknown.AliasField -or $unknown.AmbiguousAlias) { return $diagnostic }
    if ($known.ParentId -cne $unknown.SectionId) { return $diagnostic }

    # Position alone never teaches a new label. Require independent exact registry evidence.
    $matches = @(Get-GameAliasMatches -Schema $Schema -Text $unknown.Text -AllLocales)
    $fields = @($matches | ForEach-Object Field | Select-Object -Unique)
    if ($fields.Count -ne 1 -or $fields[0] -cne $known.AliasField) {
        $diagnostic.Reason = 'No unique, already-known exact alias supports the mirrored node; prose cannot be learned from position alone.'
        return $diagnostic
    }
    $definition = $Schema.subsectionFields.($fields[0])
    if ($definition.id -cne $known.SemanticId -or $definition.parentSectionId -cne $known.ParentId) { return $diagnostic }
    $occurrences = @($Blocks.($unknown.Language) | Where-Object { (ConvertTo-GameAliasKey $_.Text) -ceq (ConvertTo-GameAliasKey $unknown.Text) })
    if ($occurrences.Count -ne 1) { $diagnostic.Reason = 'The candidate alias occurs more than once; correspondence is not unique.'; return $diagnostic }

    $candidateSchema = $Schema | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $candidateSchema.schemaSubsections.($unknown.Language) | Add-Member -MemberType NoteProperty -Name $unknown.Text -Value $known.AliasField
    try {
        $candidateEs = Convert-GameLanguage -Paragraphs $Blocks.es -Language es -GameId $Spanish.GameId -Schema $candidateSchema
        $candidateEn = Convert-GameLanguage -Paragraphs $Blocks.en -Language en -GameId $English.GameId -Schema $candidateSchema
        $candidate = Get-GameParityDiagnostic $candidateEs $candidateEn
        if (-not $candidate.Success) {
            $next = if ($ValidationBudget -gt 1 -and $candidate.NodeIndex -gt $diagnostic.NodeIndex) {
                Get-GameAliasRepair $candidateEs $candidateEn $candidateSchema $Blocks ($ValidationBudget - 1)
            } else { $null }
            if ($null -eq $next -or $next.Classification -cne 'SAFE_REPAIRABLE') {
                $diagnostic.Reason = 'Candidate repair does not establish complete semantic/body-boundary/shared-data parity within the repair budget.'
                return $diagnostic
            }
        }
    } catch { $diagnostic.Reason = "Candidate repair fails schema validation: $($_.Exception.Message)"; return $diagnostic }
    $diagnostic.Classification = 'SAFE_REPAIRABLE'
    $diagnostic.Cause = 'LOCALE_ALIAS_GAP'
    $diagnostic.Reason = 'Unique exact known alias, identical mirrored parent/order, and complete reparsed body-boundary/shared-data parity.'
    $diagnostic.Repair = [pscustomobject]@{
        RepairPass = 0
        SourceLocale = $known.Language
        TargetLocale = $unknown.Language
        Language = $unknown.Language
        Text = $unknown.Text
        LocalAlias = $unknown.Text
        Field = $known.AliasField
        SemanticId = $known.SemanticId
        KnownSemanticId = $known.SemanticId
        NodeIndex = $unknown.NodeIndex
        Scope = 'DOCUMENT LOCAL'
    }
    return $diagnostic
}

function Convert-GameBilingual {
    param($Blocks, [string]$GameId, $Schema)
    # Repairs are source-local overlays, never persistent learning from arbitrary editorial text.
    $workingSchema = $Schema | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    if (-not $Schema.semanticRepair.knownAliasesOnly) { throw 'Game self-repair requires exact known-alias evidence.' }
    $repairs = @()
    $attempted = @{}
    $limit = [Math]::Min(3, [Math]::Max(0, [int]$Schema.semanticRepair.maxPasses))
    for ($pass = 0; $pass -le $limit; $pass++) {
        $es = Convert-GameLanguage -Paragraphs $Blocks.es -Language es -GameId $GameId -Schema $workingSchema
        $en = Convert-GameLanguage -Paragraphs $Blocks.en -Language en -GameId $GameId -Schema $workingSchema
        $diagnostic = Get-GameAliasRepair -Spanish $es -English $en -Schema $workingSchema -Blocks $Blocks
        if ($diagnostic.Success) { return [pscustomobject]@{ es = $es; en = $en; Repairs = $repairs; RepairPasses = $pass } }
        if ($diagnostic.Classification -cne 'SAFE_REPAIRABLE' -or $pass -eq $limit) { Throw-GameParityDiagnostic $diagnostic }
        $repair = $diagnostic.Repair
        $signature = "$($repair.TargetLocale)|$(ConvertTo-GameAliasKey $repair.LocalAlias)|$($repair.Field)"
        if ($attempted.ContainsKey($signature)) {
            $diagnostic.Classification = 'AMBIGUOUS'
            $diagnostic.Cause = 'PARITY_ENGINE_BUG'
            $diagnostic.Reason = 'The same document-local repair was proposed more than once.'
            Throw-GameParityDiagnostic $diagnostic
        }
        $attempted[$signature] = $true
        $repair.RepairPass = $pass + 1
        $workingSchema.schemaSubsections.($repair.Language) | Add-Member -MemberType NoteProperty -Name $repair.Text -Value $repair.Field
        $repairs += $diagnostic
    }
}
