# Portfolio Content Pipeline

## Principle

```text
SOURCE CONTENT
      ↓
STRUCTURED WEB CONTENT
      ↓
WEBSITE PRESENTATION
```

The public website must separate authoring formats from browser-ready content. Original documents may be maintained locally as DOCX files, but legacy `.doc` is not recommended for the pipeline.

Browsers do not natively render DOCX as semantic portfolio content. DOCX files should therefore act as authoring and source documents, not as the public reading interface. Codex can read, transform, and synchronise their content into semantic HTML while preserving headings, paragraphs, emphasis, lists, tables, and other meaningful source structure as far as practical.

The public website should consume semantic HTML and structured metadata. It should not attempt to display Word documents directly.

## Content Separation

The v0.2 scaffolding phase established these directory layers. `local-content/` exists locally and is ignored by Git. `content/`, `data/`, and `assets/` exist as the public semantic-content, structured metadata/index, and media/download layers respectively.

| Path | Responsibility |
| --- | --- |
| `local-content/` | Private/local Word files, drafts, and other authoring sources. This directory is ignored by Git. |
| `content/` | Public, transformed semantic HTML content. |
| `data/` | Public structured metadata, indexes, ordering, and relationships. |
| `assets/` | Public images, videos, and downloadable files. |

Source documents and published output must remain distinct even when Codex is used to keep them synchronised.

### Automated Ingestion Workspace

The editorial source is a complete bilingual ES+EN master DOCX created by the user, normally exported from Google Drive. The only normal manual entry point is `local-content/inbox/`; existing per-item `content.docx` files are pipeline-managed mirrors after a successful import and are not separate manual inputs.

```text
local-content/inbox/                  candidate master DOCX files
local-content/canonical/              last successfully accepted sources
local-content/archive/<type>/<id>/    older accepted canonical versions
local-content/_content-pipeline/      manifest, logs, and reports

content/**/*.html                     generated browser-ready prose
data/*.json                           structured registries
assets/                               public media and downloads
js/ + css/                            presentation and runtime behaviour
```

All `local-content/` paths are ignored local state. A successful future import archives the previous canonical file as `<yyyyMMddTHHmmssZ>__<short-old-hash>.docx`, promotes the accepted inbox file to canonical, and refreshes the established `local-content/<family>/<id>/content.docx` mirror where one exists. Foundation #01 does not populate canonical or rewrite any mirror.

Master filenames use the exact contract `<content-type>__<content-id>__ES-EN.docx`. Supported initial types are `about`, `cv`, `game`, `project`, `writing`, and `oniric-journal`; fixed pages resolve as `about:main` and `cv:main`, while collection IDs must resolve exactly against their current registry. There is no fuzzy target matching. SHA-256 of the raw DOCX bytes determines NEW, CHANGED, and UNCHANGED state; invalid names, unknown targets, and duplicate target keys are INVALID. Removing a file from inbox never deletes or unpublishes its website entity.

Each master DOCX is the complete current editorial state. A future import replaces old authored prose and DOCX-owned structured values in full; prose absent from the new document disappears. The importer does not translate, rewrite, paraphrase, summarise, correct, improve, or invent copy. Spanish and English section trees must have structural parity, and a mismatch stops the batch rather than generating or translating a missing section.

Schema existence remains system-owned. When an established structured field has no value in the new DOCX, the field remains and its visible value becomes `?`; deleting a structural field requires explicit development work on `develop`. DOCX-owned values are distinguished from protected system data in `tools/content-pipeline/config/content-types.json`. Protected data includes stable IDs, route/content paths, registry order, statuses, publication, studio/group relationships, assets and ordered media, cover focal positions, GDD relationships, download/publication configuration, and other presentation or navigation concerns represented by the current registries.

Imports are batch-atomic:

```text
SCAN -> PREFLIGHT ALL NEW/CHANGED -> VALIDATE ALL -> BUILD PLAN -> APPLY
```

No public output, canonical file, archive, mirror, or accepted manifest hash may change before the entire candidate batch passes preflight. One invalid changed/new document stops the batch without mutation. The versioned manifest records only successfully accepted imports; current website content is not backfilled with fabricated hashes.

Manifest schema version 1 keys accepted entries by stable `<type>:<id>` identity and records the source filename, raw-byte SHA-256, last successful import time in UTC, canonical location, archive count, and exact generated output list. Foundation starts with an empty `entries` object.

Tracked automation lives under `tools/content-pipeline/`. Bootstrap creates missing ignored state without overwriting existing files, scan is read-only with respect to the website and canonical/archive sources, and Git orchestration is split into explicit PREPARE, SAVE-CONTENT, INTEGRATE-DEVELOP, and PUBLISH-MAIN modes. Publishing `main` is never an automatic consequence of import and must stop when local and remote release history differ.

Import Engine #02 implements deterministic Open XML parsing for the initial About, CV, and Game schemas without external DOCX dependencies. It uses Word paragraph styles, numbering definitions, inline emphasis, and hyperlink relationships; the exact `ENGLISH VERSION` paragraph is the bilingual boundary and is never emitted. About compiles only the authored About copy while preserving the established identity/contact structure. CV compiles Education and Professional Experience, validates the authored Ludography tree while leaving its runtime list registry-owned, and emits only publication-gated authored downloads. Game compiles editorial sections and updates only DOCX-owned values on the existing registry object.

Importer version 3 supports nested ordered and unordered DOCX lists generically. The importer reads `w:numPr`, `w:numId`, `w:ilvl`, and the resolved `w:numFmt`; it never infers list depth from prose, punctuation, or visual indentation. Generated child `<ul>` and `<ol>` elements are nested inside the preceding parent `<li>`, while numbering-ID changes, list-type changes, normal paragraphs, headings, and language boundaries end the applicable list sequence. A hierarchy may increase only one level at a time; a skipped level stops preflight with `INVALID_LIST_HIERARCHY` and source context. Bilingual parity compares semantic list type, depth, item order, and topology independently of translated wording and Word numbering-ID values.

`import-content.ps1` defaults to a dry run. `-Apply` stages all generated HTML and JSON in ignored transaction state, validates the complete batch, replaces all public outputs with rollback backups, and runs frontend QA. Only after QA passes does it archive prior canonical files, promote the current inbox files to canonical, refresh compatibility mirrors, and write manifest acceptance hashes. Failed application restores every touched destination; successful first imports create no archive because no prior canonical version exists.

### Publication And Deployment

`js/core/publication.js` defines an allowlist of published top-level sections and published items within named UI groups. Renderers omit marked unpublished controls before mounting content, the global shell omits unpublished navigation entries, and the application bootstrap rejects an unpublished page family before importing its page module or loading authored content. CSS hiding, hidden placeholders, and disabled dead links are not publication mechanisms.

Publication policy controls the runtime interface, not static-host confidentiality. Any resource deployed under `content/`, `data/`, or `assets/` remains directly fetchable when its URL is known even if no rendered UI links to it. Truly private or unpublished source material must stay outside the deployed public tree, such as under the ignored `local-content/` authoring directory.

## Expected Workflow

### Page Authoring Sources

About uses one private bilingual authoring source:

```text
local-content/about/content.docx
        ↓
future content/about/en.html
future content/about/es.html
```

The DOCX owns the editable identity, biography / About copy, and contact text. Its profile photograph is a separately supplied public asset under `assets/about/profile/`, not part of the DOCX content layer.

CV uses one private bilingual authoring source:

```text
local-content/cv/content.docx
        ↓
future content/cv/en.html
future content/cv/es.html
```

The CV DOCX owns editable Education, Work Experience, and bilingual section / download-action copy. Ludography is populated from `data/ludography.json` and `data/games.json` and must not be duplicated in the CV authoring source. Downloadable CV and Portfolio PDFs remain separate public assets under `assets/downloads/cv/` and `assets/downloads/portfolio/`. Only the CV download is currently allowlisted for rendered UI; the Portfolio PDF remains publicly addressable until it is deliberately removed from deployment.

As with game authoring, DOCX metadata, research notes, and integration instructions must never appear in public semantic content. `local-content/` remains private/local and ignored by Git. Carlos manually supplies profile and download binaries; a later integration pass normalises their public filenames without modifying binary contents or changing extensions.

### Game Authoring Source

```text
LOCAL AUTHORING
local-content/games/<game-id>/content.docx

PUBLIC ASSETS
assets/games/<game-id>/cover/
assets/games/<game-id>/media/images/
assets/games/<game-id>/media/videos/

        ↓
Codex transforms the authored language sections
        ↓

PUBLIC GENERATED CONTENT
content/games/<game-id>/en.html
content/games/<game-id>/es.html
```

Local authoring and public asset directories are prepared ahead of integration. Carlos manually supplies `content.docx` and the visual assets; no placeholder DOCX or media files are generated. The DOCX file is the authoritative literary source for a game's public copy and remains local because `local-content/` is ignored by Git. Codex later transforms the authored language sections into public semantic HTML during the corresponding content-integration batch.

Codex must preserve the approved wording: source metadata and integration instructions guide the transformation but must not appear in the public content. The generated output is semantic HTML, not a public copy of the authoring document. Empty public media directories may contain `.gitkeep` solely so the scaffold can be versioned; markers are never registered as media. Existing `gallery/` paths remain valid legacy sources until an intentional migration.

Visual assets are supplied manually under `assets/games/<game-id>/` and connected through `data/games.json`. Public asset filenames are normalised to lowercase kebab-case without changing their formats or binary contents. Each ordered Game `media` collection may reference at most 12 images, four videos, and 16 total items.

The registry also owns optional presentation and metadata fields. `coverPosition` adjusts an individual cover focal point inside the shared `1112 / 628` frame and defaults to `50% 50%`; Games Index and Game Detail consume the same value. `accessUrl` stores a legitimate purchase, play, or access URL; omit it when no verified local source exists. `engineId` and `engineName` identify an explicitly documented development engine; omit them when the engine is unknown rather than inferring a value.

Engine logos are supplied once under the global `assets/engines/` directory using the canonical `assets/engines/<engine-id>.png` contract. Game Detail derives this path from `engineId`, allowing every Game with the same engine to reuse one transparent PNG. Do not add engine icon paths to individual Game records or duplicate engine assets under `assets/games/`.

### Professional Game

```text
GAME REGISTRY
data/games.json

        ↓

GAME CASE-STUDY CONTENT
content/games/<game-id>/en.html
content/games/<game-id>/es.html

        +

GAME MEDIA
assets/games/<game-id>/

        ↓

GAME DETAIL PAGE
```

`data/games.json` stores canonical game identity, metadata, and ordered mixed-media references. Semantic HTML stores the long-form professional contribution content, while `assets/games/<game-id>/` stores the supporting visual evidence. The Game Detail presentation consumes all three layers. Long-form professional text must not be duplicated inside `games.json`. Games and Projects use the same `js/core/media-gallery.js` interaction engine and the same 12-image, four-video, 16-item limits; their page CSS independently owns viewer geometry.

The Games Index and Game Detail share one canonical ordering helper. Game Detail flattens the visible company groups and game lists from that source for circular Previous/Next navigation, including last-to-first and first-to-last wrapping.

### Project Authoring Sources

```text
local-content/projects/<project-id>/content.docx
        ↓
content/projects/<project-id>/en.html
content/projects/<project-id>/es.html

local-content/projects/<project-id>/gdds/<gdd-id>/content.docx
        ↓
content/projects/<project-id>/gdds/<gdd-id>/en.html
content/projects/<project-id>/gdds/<gdd-id>/es.html
```

The project-level DOCX is the authoritative source for the overall Project Detail. A project may own zero, one, or many child GDD DOCX sources. Once child sources exist, their full prose must not also be maintained in the master document. `data/projects.json` stores metadata, paths, status, asset references, ordered showcase media, optional playable-prototype URLs, and child relationships only; structured genre, platform, and creation-date values belong there rather than in GDD prose. Project-index icons and backgrounds are manually supplied under `assets/projects/<project-id>/icon/` and `assets/projects/<project-id>/background/` and referenced by `assets.icon` and `assets.background`. The Project Detail showcase reads up to 12 image references from `assets/projects/<project-id>/media/images/` and four video references from `assets/projects/<project-id>/media/videos/`, preserving registry order and a 16-item total limit. The authored Brief is moved into the showcase side panel without duplication; the standalone Prototype section is retired from presentation while legacy `prototype/videos/` source files remain preserved. Cover, conceptual-process, GDD, and other manually supplied binaries remain separate from authored prose. Public semantic content is generated in a later integration task.

### Writing Authoring Sources

```text
local-content/writing/<story-id>/content.docx
        ↓
content/writing/<story-id>/en.html
content/writing/<story-id>/es.html
```

Writing uses one independent bilingual DOCX per story and never one monolithic source for the section. `data/stories.json` indexes identity, order, labels, status, content paths, and optional assets without storing story prose. Transformation must preserve source paragraph boundaries, intentional spacing, order, emphasis, literary pacing, and authored headings as far as practical; it must not invent headings. Public semantic content is generated in a later integration task.

### Oniric Journal Authoring Sources

```text
local-content/oniric-journal/<entry-id>/content.docx
        ↓
content/oniric-journal/<entry-id>/en.html
content/oniric-journal/<entry-id>/es.html
```

Oniric Journal uses one independent bilingual DOCX per entry, normally keyed by its ISO date, and never one monolithic source for the journal. The single journal registry stores identity, date, order, bilingual labels, status, content paths, and optional assets without storing dream or analysis prose. Display numbering and previous/next relationships derive from registry order. Public semantic content is generated in a later integration task.

For all three families, DOCX is the authoritative source for authored prose, JSON is registry metadata only, and manually supplied assets remain separate. Authoring metadata and integration-contract instructions guide transformation but must never appear in public output. `local-content/` remains ignored by Git.

## Content Rules

### Game Design Documents

GDDs must ultimately be presented as native semantic HTML, not as embedded PDFs. Source documents may be imported, but their headings, navigation, sections, tables, callouts, and media references should become accessible web structures.

### Conceptual Process

Conceptual Process scans are public visual assets. Project pages display them through the Concept Book component, with semantic captions, ordering metadata, alternative text, and keyboard/touch navigation where appropriate.

### Shared Detail Media

Project and Game images/videos are public media assets referenced through the same ordered registry item contract and rendered by one shared engine. Each viewer may display at most 12 images and four videos, with 16 items total. Project files use `assets/projects/<project-id>/media/images/` and `media/videos/`; new Game files use `assets/games/<game-id>/media/images/` and `media/videos/`. Metadata identifies media type, source, optional video poster, localized labels or alternative text, ordering, formats, and accessibility requirements independently from page templates. Consumer CSS owns geometry: the Game stage uses `1112 / 628` and fills screenshot images with proportional cover cropping, while video playback uses containment and Project geometry remains independent. Legacy Project `prototype/videos/`, Game `gallery/`, and their registered paths remain preserved without creating separate viewer implementations.

## Synchronisation Expectations

- Source-to-web transformation should be repeatable.
- Bilingual documents should preserve a stable relationship between equivalent entries.
- Structured indexes should own titles, slugs, dates, order, language availability, and cross-entry navigation.
- Generated HTML should remain reviewable and accessible.
- Public content and assets may be versioned; private authoring sources in the ignored `local-content/` directory remain outside public version control.
- Inbox deletion is not a content deletion API; removal and unpublication remain explicit structural/publication operations.
- The importer preserves system-owned registry and presentation metadata while replacing DOCX-owned editorial state.
- Before final video population, rerun the storage audit and calculate the remaining deployment budget. The Foundation baseline is 90.09 MB on `develop`, approximately 86.20 MiB of Git objects, approximately 177.40 MB locally, and approximately 9% of the 1 GB GitHub Pages budget. Gameplay videos should generally remain around one minute or less and available slots must not be filled automatically.
