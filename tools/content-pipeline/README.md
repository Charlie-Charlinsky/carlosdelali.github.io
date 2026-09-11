# Content Pipeline Tooling

This directory contains the tracked automation foundation for deterministic bilingual DOCX ingestion. It does not contain authoring documents or pipeline runtime state.

## Human workflow

The only normal manual entry point is `local-content/inbox/`. A source filename must match:

```text
<content-type>__<content-id>__ES-EN.docx
```

Supported types are `about`, `cv`, `contact`, `game`, `project`, `writing`, and `oniric-journal`. The marker and lowercase filename contract are exact. Target IDs must already exist in their registry, except the fixed targets `about:main`, `cv:main`, and `contact:main`.

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/content-pipeline/bootstrap-content-workspace.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/content-pipeline/scan-inbox.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/content-pipeline/test-foundation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/content-pipeline/import-content.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/content-pipeline/import-content.ps1 -Apply
powershell -NoProfile -ExecutionPolicy Bypass -File tools/content-pipeline/import-content.ps1 -Rebuild -Apply
powershell -NoProfile -ExecutionPolicy Bypass -File tools/content-pipeline/test-import-engine.ps1
```

Bootstrap is idempotent and never overwrites the manifest. Scan computes SHA-256 over raw DOCX bytes, compares candidates with the last successful manifest entry, writes `local-content/_content-pipeline/reports/latest-scan.json`, and never mutates public website content, canonical sources, or archives.

Manifest schema version 1 uses stable `<type>:<id>` entry keys. A future accepted entry records `sourceFile`, raw-byte `sha256`, `lastImportedUtc`, `canonicalFile`, `archiveCount`, and the exact generated `outputs`. The initial manifest has an empty `entries` object; existing website files are not treated as pipeline imports.

Accepted sources use the stable canonical path `local-content/canonical/<type>/<id>/content.docx`. Established `local-content/<family>/<id>/content.docx` files are compatibility mirrors refreshed by the pipeline, not additional human inputs.

`content-git-flow.ps1` defines four explicitly invoked modes: `PREPARE`, `SAVE-CONTENT`, `INTEGRATE-DEVELOP`, and `PUBLISH-MAIN`. Without `-Execute`, it performs local read-only gates and prints the intended plan. Write-capable execution requires `-Execute`; SAVE-CONTENT additionally requires an exact `-ApprovedPath` set and never uses broad staging. PUBLISH-MAIN is a separate release operation and stops if local `main` differs from `origin/main`.

## Exit codes

| Code | Meaning |
| ---: | --- |
| 0 | Success |
| 1 | Success with warning |
| 2 | User action required |
| 3 | Consult Cortana |
| 4 | Regression or validation failure |
| 5 | Fatal tooling/environment failure |

## Transaction boundary

The future importer must scan, preflight every NEW/CHANGED document, validate the complete batch, and build a complete plan before any mutation. One invalid candidate stops the batch: no website outputs, canonical sources, archives, or accepted manifest hashes may change.

On acceptance, an existing canonical source is archived under `local-content/archive/<type>/<id>/<yyyyMMddTHHmmssZ>__<short-old-hash>.docx` before the new source is promoted. Inbox deletion never triggers website deletion or unpublication.

Import Engine #02 parses DOCX directly through the Open XML ZIP/XML contract. About, CV, and Game schemas validate the complete ES/EN trees, compile semantic HTML, and update only DOCX-owned structured Game values. A dry run is the default; `-Apply` stages and validates the complete batch, replaces public outputs transactionally, runs frontend QA, then archives/promotes canonical sources, refreshes compatibility mirrors, and writes accepted manifest hashes last. Apply failures restore every touched destination.

Importer version 3 supports deterministic nested ordered and unordered lists. Hierarchy comes only from WordprocessingML numbering metadata (`w:numId`, `w:ilvl`, and `w:numFmt`): list levels become nested `<ul>`/`<ol>` elements inside their owning `<li>`, numbering-ID or list-type changes create semantic list boundaries, and normal paragraphs, headings, and language boundaries close the active list sequence. A level increase may advance by exactly one; skipped levels fail preflight with `INVALID_LIST_HIERARCHY`. ES/EN structural parity includes list type, depth, item order, and topology without comparing translated item text or requiring the languages to reuse the same Word numbering IDs.

Importer version 4 preserves Game editorial heading hierarchy directly from Word paragraph styles. Game main sections must be `Heading2` and compile to semantic `<h2>` elements; authored child subsections must be `Heading3` and compile to semantic `<h3>` elements. Subsection titles are unrestricted editorial text and receive deterministic HTML fragment IDs without title-specific mappings. ES/EN parity compares heading and content-block topology rather than translated heading text. A batch may update any number of Game registry entries transactionally while preserving every protected field.

Importer version 5 permits the Game schema to require a prefix of the declared main sections, so an overview-only Game and an overview-plus-contribution Game use the same compiler. It also declares `Main Features` as the `mainFeatures` Game field beneath `overview`: when that exact schema label is authored as a normal, non-list paragraph, it compiles to semantic `<h3>` and owns the authored content that follows. Genuine Word `Heading3` paragraphs continue to compile as `<h3>` independently. No font, size, boldness, short-text heuristic, or other presentation inference promotes arbitrary normal paragraphs.

Importer version 6 extends the same explicit Game subsection schema to known Contribution child fields, including localized ES/EN labels. These normal, non-list field labels compile as sibling `<h3>` sections only beneath `contribution`; unrelated normal prose is unchanged. Access metadata parity compares the effective authored destination, preferring a DOCX hyperlink relationship and otherwise accepting the identical safe URL text used by registry compilation.

Importer version 7 adds the fixed `contact:main` target for `contact__main__ES-EN.docx`. Its initial contract consumed a document-level `Heading1` before compiling the visible `Heading2` and fixed Email/LinkedIn `Heading3` fields to `content/contact/{es,en}.html`. Missing fields render as plain `?` values. Email links must use `mailto:`, LinkedIn links must use HTTPS, and ES/EN field presence, values, and targets must match. About compilation no longer preserves or emits a contact block.

Importer version 8 declares the Contact source as intentionally H2-first, with no document-level `Heading1`. Hyperlink display text remains source-authored and is emitted unchanged, while the independent Word relationship target is validated for a safe scheme and ES/EN destination parity. Other content schemas retain their existing heading contracts.

`-Rebuild` explicitly recompiles accepted UNCHANGED sources after a compiler/tooling change. Normal imports continue to skip unchanged hashes. Rebuilding an identical canonical source does not create a redundant archive version.

## Media budget gate

Foundation baseline: develop 90.09 MB; main 133.46 KB; difference 89.96 MB; Git objects approximately 86.20 MiB; local repository approximately 177.40 MB; approximate GitHub Pages budget use 9% of 1 GB.

Content architecture and required images take priority. Video is final-stage content, gameplay clips should generally remain around one minute or less, slots should not be populated automatically, and storage must be audited again before final video population.
