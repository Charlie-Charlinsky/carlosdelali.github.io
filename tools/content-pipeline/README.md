# Content Pipeline Tooling

This directory contains the tracked automation foundation for deterministic bilingual DOCX ingestion. It does not contain authoring documents or pipeline runtime state.

## Human workflow

The only normal manual entry point is `local-content/inbox/`. A source filename must match:

```text
<content-type>__<content-id>__ES-EN.docx
```

Supported types are `about`, `cv`, `game`, `project`, `writing`, and `oniric-journal`. The marker and lowercase filename contract are exact. Target IDs must already exist in their registry, except the fixed targets `about:main` and `cv:main`.

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

`-Rebuild` explicitly recompiles accepted UNCHANGED sources after a compiler/tooling change. Normal imports continue to skip unchanged hashes. Rebuilding an identical canonical source does not create a redundant archive version.

## Media budget gate

Foundation baseline: develop 90.09 MB; main 133.46 KB; difference 89.96 MB; Git objects approximately 86.20 MiB; local repository approximately 177.40 MB; approximate GitHub Pages budget use 9% of 1 GB.

Content architecture and required images take priority. Video is final-stage content, gameplay clips should generally remain around one minute or less, slots should not be populated automatically, and storage must be audited again before final video population.
