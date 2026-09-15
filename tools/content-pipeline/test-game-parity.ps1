# Included by test-import-engine.ps1; fixtures never mutate repository state.
function New-GameParityFixture {
    param([string]$EsLabel, [string]$EnLabel, [string]$EsStyle = 'Normal', [string]$EnStyle = 'Normal', [switch]$Contribution)
    $blocks = [pscustomobject]@{ es = @(); en = @() }
    foreach ($language in @('es', 'en')) {
        $label = if ($language -eq 'es') { $EsLabel } else { $EnLabel }
        $style = if ($language -eq 'es') { $EsStyle } else { $EnStyle }
        $paragraphs = @((New-TestParagraph 'Fixture Game' -Style Heading1), (New-TestParagraph 'Overview' -Style Heading2), (New-TestParagraph 'Overview body'))
        if ($Contribution) { $paragraphs += New-TestParagraph 'Contribution' -Style Heading2 }
        $paragraphs += @((New-TestParagraph $label -Style $style), (New-TestParagraph 'Subsection body'))
        for ($index = 0; $index -lt $paragraphs.Count; $index++) { $paragraphs[$index].ParagraphIndex = $index }
        $blocks.$language = $paragraphs
    }
    return $blocks
}

function Invoke-GameParityMatrix {
    $schema = (Get-ContentPipelineConfig -RepositoryRoot $root).importSchemas.game
    $spanish = "Mec$([char]0x00e1)nicas principales"
    $beforeSchema = ConvertTo-StableJson $schema
    $cases = @(
        @($spanish, 'Main features'),
        @('Main Features', 'Main Features'),
        @($spanish.ToUpperInvariant(), 'mAiN fEaTuReS'),
        @("  $($spanish.Replace(' ', "`t  "))  ", "Main$([char]0x00a0)features"),
        @($spanish.Normalize([Text.NormalizationForm]::FormD), 'Main features')
    )
    $caseIndex = 0
    foreach ($case in $cases) {
        $caseIndex++
        $blocks = New-GameParityFixture $case[0] $case[1]
        $result = Convert-GameBilingual -Blocks $blocks -GameId matrix -Schema $schema
        foreach ($language in @('es', 'en')) {
            $heading = @($result.$language.SemanticNodes | Where-Object Kind -eq h3)
            $source = $blocks.$language[3]
            Assert-ImportEngine ($heading.Count -eq 1 -and $heading[0].SemanticId -ceq 'main-features' -and $heading[0].ParentId -ceq 'overview' -and $heading[0].SemanticLevel -eq 3) "parity matrix $caseIndex $language canonical ID, parent and H3"
            Assert-ImportEngine ($heading[0].Text -ceq $source.Text -and ([xml]$result.$language.Html).SelectSingleNode('//h3').InnerText -ceq $source.Text) "parity matrix $caseIndex $language exact authored display preserved"
        }
        Assert-ImportEngine ($result.RepairPasses -eq 0) "parity matrix $caseIndex configured aliases need no repair"
    }

    foreach ($label in @('Unknown subsection', 'Main features extra', 'Prefix Main features', 'Mecanicas principales', 'Ordinary prose.')) {
        $blocks = New-GameParityFixture $label $label
        $result = Convert-GameBilingual $blocks matrix $schema
        Assert-ImportEngine (@($result.en.SemanticNodes | Where-Object Kind -eq h3).Count -eq 0 -and $result.RepairPasses -eq 0) "parity matrix unknown Normal remains prose: $label"
    }

    $missingEs = $schema | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $missingEs.schemaSubsections.es.PSObject.Properties.Remove('Main Features')
    $blocks = New-GameParityFixture 'Main features' 'Main features'
    $es = Convert-GameLanguage $blocks.es es matrix $missingEs
    $en = Convert-GameLanguage $blocks.en en matrix $missingEs
    $diagnostic = Get-GameAliasRepair $es $en $missingEs $blocks
    Assert-ImportEngine ($diagnostic.Classification -ceq 'SAFE_REPAIRABLE' -and $diagnostic.Repair.Language -ceq 'es') 'parity matrix mirrored missing ES known alias is SAFE_REPAIRABLE'
    $result = Convert-GameBilingual $blocks matrix $missingEs
    Assert-ImportEngine ($result.RepairPasses -eq 1 -and $result.Repairs.Count -eq 1 -and $result.Repairs[0].Repair.RepairPass -eq 1 -and $null -eq $missingEs.schemaSubsections.es.PSObject.Properties['Main features']) 'parity matrix repair runs once without mutating caller schema'
    $unrelated = Convert-GameLanguage -Paragraphs (New-GameParityFixture 'Main features' 'Unknown prose').es -Language es -GameId unrelated -Schema $missingEs
    Assert-ImportEngine (@($unrelated.SemanticNodes | Where-Object Kind -eq h3).Count -eq 0) 'parity matrix document-local overlay does not leak into another document'

    $blocks = New-GameParityFixture 'Main features' $spanish
    $beforeSource = ConvertTo-StableJson $blocks
    $result = Convert-GameBilingual $blocks matrix $schema
    Assert-ImportEngine ($result.RepairPasses -eq 1 -and $result.en.Subsections[0] -ceq $spanish -and $result.es.Subsections[0] -ceq 'Main features') 'parity matrix crossed known locale labels repair without translation'
    Assert-ImportEngine ((ConvertTo-StableJson $blocks) -ceq $beforeSource -and (ConvertTo-StableJson $schema) -ceq $beforeSchema) 'parity matrix source and global schema are immutable'
    $report = Format-GameParityDiagnostic $result.Repairs[0]
    foreach ($field in @('TARGET:', 'LANGUAGE:', 'NODE INDEX:', 'SOURCE TEXT:', 'WORD STYLE:', 'WORD LEVEL:', 'SEMANTIC ID:', 'SEMANTIC LEVEL:', 'PARENT ID:', 'EXPECTED COUNTERPART:', 'ACTUAL COUNTERPART:', 'CLASSIFICATION:', 'REASON:', 'REPAIR PASS:', 'SOURCE LOCALE:', 'TARGET LOCALE:', 'KNOWN SEMANTIC ID:', 'LOCAL ALIAS ADDED:', 'SCOPE: DOCUMENT LOCAL')) {
        Assert-ImportEngine ($report.Contains($field)) "parity matrix actionable diagnostic includes $field"
    }

    $word = Convert-GameBilingual (New-GameParityFixture $spanish 'Main features' -EsStyle Heading3) matrix $schema
    Assert-ImportEngine ($word.RepairPasses -eq 0 -and $word.es.SemanticNodes[3].WordLevel -eq 3 -and $word.en.SemanticNodes[3].WordLevel -eq $null) 'parity matrix genuine Word H3 and known Normal alias share semantic identity'

    $badCases = @(
        [pscustomobject]@{ Name = 'H2 versus H3 conflict'; Blocks = (New-GameParityFixture $spanish 'Main features' -EsStyle Heading2 -EnStyle Heading3); Schema = $schema },
        [pscustomobject]@{ Name = 'arbitrary mirrored prose'; Blocks = (New-GameParityFixture 'An unknown editorial sentence' 'Main features'); Schema = $schema },
        [pscustomobject]@{ Name = 'different known IDs with identical topology'; Blocks = (New-GameParityFixture 'La tienda' 'The Races' -Contribution); Schema = $schema }
    )
    $missing = New-GameParityFixture $spanish 'Main features'
    $missing.en = @($missing.en[0..2]) + @($missing.en[4])
    $badCases += [pscustomobject]@{ Name = 'missing section'; Blocks = $missing; Schema = $schema }
    $conflicting = $schema | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $conflicting.schemaSubsections.en | Add-Member -MemberType NoteProperty -Name 'Collision Key' -Value mainFeatures
    $conflicting.schemaSubsections.en | Add-Member -MemberType NoteProperty -Name 'Collision  Key' -Value shop
    $badCases += [pscustomobject]@{ Name = 'competing normalized semantic IDs'; Blocks = (New-GameParityFixture $spanish 'Collision Key'); Schema = $conflicting }
    $globalConflict = $schema | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $globalConflict.schemaSubsections | Add-Member -MemberType NoteProperty -Name other -Value ([pscustomobject]@{ $spanish = 'shop' })
    $badCases += [pscustomobject]@{ Name = 'competing cross-locale semantic IDs'; Blocks = (New-GameParityFixture 'Main features' $spanish); Schema = $globalConflict }
    $differentBody = New-GameParityFixture 'Main features' $spanish
    $differentBody.en[4] = New-TestParagraph 'Body' -NumberId 1 -ListLevel 0 -ListFormat bullet
    $badCases += [pscustomobject]@{ Name = 'different child boundaries'; Blocks = $differentBody; Schema = $schema }
    $duplicate = New-GameParityFixture 'Main features' $spanish
    $duplicate.en += @((New-TestParagraph $spanish), (New-TestParagraph 'Second occurrence'))
    $badCases += [pscustomobject]@{ Name = 'duplicate repair candidate'; Blocks = $duplicate; Schema = $schema }
    foreach ($case in $badCases) {
        $rejected = $false
        try { Convert-GameBilingual $case.Blocks matrix $case.Schema | Out-Null } catch {
            $rejected = $_.Exception.Data.Contains('GameParityDiagnostic') -and $_.Exception.Data['GameParityDiagnostic'].Classification -ceq 'AMBIGUOUS'
        }
        Assert-ImportEngine $rejected "parity matrix rejects $($case.Name) with diagnostics"
    }

    $ordered = New-GameParityFixture 'La tienda' 'The Shop' -Contribution
    $ordered.es += @((New-TestParagraph 'Las carreras'), (New-TestParagraph 'Second body'))
    $ordered.en += @((New-TestParagraph 'The Races'), (New-TestParagraph 'Second body'))
    $ordered.en[4].Text = 'The Races'
    $ordered.en[6].Text = 'The Shop'
    $rejected = $false
    try { Convert-GameBilingual $ordered matrix $schema | Out-Null } catch { $rejected = $_.Exception.Data.Contains('GameParityDiagnostic') }
    Assert-ImportEngine $rejected 'parity matrix rejects reordered semantic siblings'

    $multiple = New-GameParityFixture 'La tienda' 'La tienda' -Contribution
    $multiple.es += @((New-TestParagraph 'Las carreras'), (New-TestParagraph 'Second body'))
    $multiple.en += @((New-TestParagraph 'Las carreras'), (New-TestParagraph 'Second body'))
    $result = Convert-GameBilingual $multiple matrix $schema
    Assert-ImportEngine ($result.RepairPasses -eq 2 -and @($result.en.SemanticNodes | Where-Object Kind -eq h3).Count -eq 2) 'parity matrix two independent known alias gaps repair within bounded loop'

    $limited = $schema | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $limited.semanticRepair.maxPasses = 0
    $rejected = $false
    try { Convert-GameBilingual (New-GameParityFixture 'Main features' $spanish) matrix $limited | Out-Null } catch { $rejected = $_.Exception.Data['ContentPipelineExitCode'] -eq 4 }
    Assert-ImportEngine $rejected 'parity matrix repair budget exhaustion is tooling regression, not user source action'
}
