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

The CV DOCX owns editable Education, Work Experience, and bilingual section / download-action copy. Ludography is populated from `data/ludography.json` and `data/games.json` and must not be duplicated in the CV authoring source. Downloadable CV and Portfolio PDFs remain separate public assets under `assets/downloads/cv/` and `assets/downloads/portfolio/`.

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

Project and Game images/videos are public media assets referenced through the same ordered registry item contract and rendered by one shared engine. Each viewer may display at most 12 images and four videos, with 16 items total. Project files use `assets/projects/<project-id>/media/images/` and `media/videos/`; new Game files use `assets/games/<game-id>/media/images/` and `media/videos/`. Metadata identifies media type, source, optional video poster, localized labels or alternative text, ordering, formats, and accessibility requirements independently from page templates. Legacy Project `prototype/videos/`, Game `gallery/`, and their registered paths remain preserved without creating separate viewer implementations.

## Synchronisation Expectations

- Source-to-web transformation should be repeatable.
- Bilingual documents should preserve a stable relationship between equivalent entries.
- Structured indexes should own titles, slugs, dates, order, language availability, and cross-entry navigation.
- Generated HTML should remain reviewable and accessible.
- Public content and assets may be versioned; private authoring sources in the ignored `local-content/` directory remain outside public version control.
