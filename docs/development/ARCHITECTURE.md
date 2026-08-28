# Portfolio Website Architecture

This document defines the information architecture for v0.2.0. The bilingual `/en/` and `/es/` route trees are implemented as lightweight static shells backed by shared CSS and JavaScript modules. Presentation consumes the completed registries, semantic fragments, and public assets without duplicating authored content.

## v0.2 Frontend Runtime

The site remains a static GitHub Pages application with no build step or server runtime. `js/core/paths.js` derives the site root from `import.meta.url`, so route, data, content, and asset URLs work at a custom-domain root or below any GitHub Pages project path without embedding a repository name. Shared helpers cover route construction, language-context preservation, JSON loading, semantic-fragment loading, internal URL normalisation, error states, and the persistent global shell.

`js/app.js` dispatches each route shell to a page coordinator under `js/pages/`. Collection modules render from their canonical registries, while reusable detail shells resolve the selected item from a query parameter and then load its localized semantic fragment and registered assets. The English and Spanish trees share the same modules and preserve current game, project, story, or journal identity when switching language.

`css/frontend.css` owns the v0.2 design tokens, shared geometry, responsive layout, focus/touch states, reduced-motion behaviour, galleries, reader treatment, and collection patterns. Repeated Games, Projects, Writing, and Journal elements use common component classes rather than item-specific rules, keeping later Visual QA adjustments centralized.

## Active Main Navigation

- ABOUT
- CV
- GAMES
- PROJECTS
- WRITING
- ONIRIC JOURNAL / DIARIO ONÍRICO

Narrative and Drawings are future sections. They are not current routes and must not appear in the v0.2.0 main navigation.

## Bilingual Route System

```text
/
  -> default language landing behaviour

/en/
  About

/en/cv/
/en/games/
/en/projects/
/en/writing/
/en/oniric-journal/

/en/games/detail/?id=<game-id>
/en/projects/detail/?id=<project-id>
/en/oniric-journal/detail/?id=<entry-id>
/en/writing/?story=<story-id>

/es/
  About

/es/cv/
/es/games/
/es/projects/
/es/writing/
/es/oniric-journal/

/es/games/detail/?id=<game-id>
/es/projects/detail/?id=<project-id>
/es/oniric-journal/detail/?id=<entry-id>
/es/writing/?story=<story-id>
```

English is the default when no explicit language preference exists. The root shell preserves an explicit stored preference and redirects portably to the matching About route. Spanish is a full equivalent version, not a reduced secondary site.

The legacy `/en/dream-journal/` and `/es/dream-journal/` shells redirect to the canonical Oniric Journal routes while preserving query and hash context where present.

## Global Header

The intended desktop header is fixed while page content scrolls.

```text
Upper left:  ESP / ENG
Below:       CARLOS J. L. SÁNCHEZ
Right:       About / CV / Games / Projects / Writing / Oniric Journal
```

The language selector, designer name, and main navigation are global controls. The current language and page must be conveyed accessibly as well as visually.

On mobile, the header must:

- Preserve the ESP / ENG language selector.
- Preserve the designer name.
- Collapse the main navigation into an accessible menu.
- Remain accessible while the page content scrolls.

## Page Families

### ABOUT

- Profile
- Portrait
- Introduction
- Contact information

About is the default landing page for each language tree.

#### Authoring Architecture

`local-content/about/content.docx` is the authoritative editable source for the bilingual identity, biography / About copy, and contact text. A future content-integration pass will transform it into:

```text
local-content/about/content.docx
        ↓
content/about/en.html
content/about/es.html
```

The future semantic fragment follows this conceptual model:

```html
<article data-page-id="about">
    identity
    biography / about-copy
    contact
</article>
```

About owns one separately supplied profile image under `assets/about/profile/`. When integrated, its canonical public filename is `carlos-lopez-profile.<original-extension>`; the source binary and extension must be preserved. The profile image is composed by the future page renderer and is not embedded in the authoring DOCX. The semantic fragment does not duplicate the global page shell or navigation.

### CV

- Education
- Work Experience
- Ludography
- Download CV
- Download Portfolio

The webpage is the native presentation. Downloadable files are supporting resources.

#### Authoring Architecture

`local-content/cv/content.docx` is the authoritative editable source for bilingual Education, Work Experience, and section / download-action copy. A future content-integration pass will transform it into:

```text
local-content/cv/content.docx
        ↓
content/cv/en.html
content/cv/es.html
```

The CV has three permanent main content regions:

1. Education
2. Work Experience
3. Ludography

Education and Work Experience are DOCX-authored. Ludography remains data-driven from `data/ludography.json` and `data/games.json`; it must be mounted into the future semantic/page composition rather than duplicated as manually maintained CV copy.

The future semantic fragment follows this conceptual model:

```html
<article data-page-id="cv">
    education
    work-experience
    ludography data mount
    download actions
</article>
```

The public, versioned download assets live separately from the DOCX:

- `assets/downloads/cv/carlos-lopez-cv.pdf`
- `assets/downloads/portfolio/carlos-lopez-portfolio.pdf`

The future page renderer will compose the semantic content, data-driven Ludography, and download actions without duplicating the global page shell or navigation.

### GAMES

- Organised by company or studio.
- Maximum of four game columns on desktop.
- Responsive reduction in columns for tablet and mobile.
- Each game links to its own detail page.

Every Games Index media frame uses `aspect-ratio: 1112 / 628`. Cover images fill that shared frame with proportional `object-fit: cover` cropping. The optional `coverPosition` field in `data/games.json` provides a per-game focal position when the default `50% 50%` crop would obscure the game title or logo; grid columns, company grouping, and visible ordering remain unchanged.

### GAME DETAIL

- Game overview
- Metadata
- Explanation of role and contribution
- Shared mixed-media viewer with at most 12 images, four videos, and 16 total items
- Thumbnail carousel, previous/next, Theater, Fullscreen, and keyboard navigation

#### Content Architecture

A Game Detail page presents:

1. Game identity / overview
2. Professional contribution
3. Systems, features, or design areas worked on
4. Supporting mixed image/video evidence

A single game may contain multiple professional contribution subsections. The conceptual content structure is:

```text
Game
├── Overview
├── My Contribution
│   ├── Feature / System A
│   ├── Feature / System B
│   └── Feature / System C
└── Media
```

`data/games.json` owns one ordered `media` collection per Game using the same item contract as Projects. New Game media belongs under `assets/games/<game-id>/media/images/` and `assets/games/<game-id>/media/videos/`. Existing registered screenshots may remain in the legacy `gallery/` directory until a deliberate asset migration; registry paths, rather than folder discovery, determine what the viewer displays. Game Detail and Project Detail both consume the single interaction engine at `js/core/media-gallery.js`, while page-scoped CSS controls their independent size and placement.

Game metadata may include optional `year`, `platform`, `engineId`, `engineName`, and `accessUrl` values. Missing values render as `?`. `accessUrl` is the single structured purchase/play/access target and is rendered as a safe external link when present. Engine icons are global reusable assets, resolved automatically from `engineId` using `assets/engines/<engine-id>.png`; icon paths are never duplicated per Game. A known engine with a missing PNG keeps its metadata text, omits the broken image, and reports a warning.

Game Detail Previous/Next controls are circular. Both Games Index grouping and Game Detail navigation consume the same ordered studio/game helper, so the flattened navigation sequence always follows the visible Games Index order without a second ordering rule.

On desktop, the visual gallery is positioned alongside the written content. A maximum of six gallery images may be available for the visible page, while game metadata and professional contribution remain the primary information. The layout becomes responsive on tablet and mobile. Final CSS dimensions are intentionally undefined at this architecture stage.

### PROJECTS (I+D+I)

- Current personal games and prototypes.
- Large horizontal project entries.
- Scale response on hover.
- Black/white palette inversion on hover.
- Clicking an entry opens its project detail page.

#### Content Architecture

Each project owns one master authoring source at `local-content/projects/<project-id>/content.docx`. It defines the overall Project Detail hierarchy: Brief, Conceptual Process, GDD / Design Documentation, and Prototype. A project may also own zero, one, or many child GDD sources at `local-content/projects/<project-id>/gdds/<gdd-id>/content.docx`. When child GDDs exist, the master source acts as their overview or index and must not duplicate their complete authored copy.

Project and child-GDD sources are transformed independently into bilingual semantic fragments:

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

Public project assets remain separate from authored prose. Each project supports an optional index icon at `assets/projects/<project-id>/icon/` and an optional index background at `assets/projects/<project-id>/background/`; their paths are stored as `assets.icon` and `assets.background` in the project registry. The Project Detail showcase uses one ordered `media` registry collection backed by `assets/projects/<project-id>/media/images/` and `assets/projects/<project-id>/media/videos/`, with at most 12 registered images, four registered videos, and 16 total items. Existing assets remain independent: `cover/` owns an optional cover, `conceptual-process/` owns ordered sketches, scans, diagrams, process images, and concept sheets, `gdds/<gdd-id>/images/` provides optional child-GDD assets, and the retired `prototype/videos/` source directory is preserved without driving a standalone public section.

`data/projects.json` is the metadata-only project registry. It owns identity, order, bilingual labels, genre, platform, creation date, status, content and asset paths, ordered showcase media, child-GDD relationships, and the optional `playPrototypeUrl`. Genre, platform, creation date, media references, and the playable-prototype URL belong in this registry, not in GDD prose; the registry must not contain long Project or GDD prose.

#### Project Detail

- Mixed image/video showcase with a maximum of 12 images and four videos
- Project icon and authored Brief in the showcase side panel
- Optional registry-driven Play Prototype link
- Natural document flow from the showcase into Conceptual Process and GDD
- Concept Book and native HTML GDD
- No duplicated Brief or standalone Prototype section in the presentation

### WRITING

- Story bibliography or list on the left.
- Independent scrolling for the story list.
- Clickable story entries.
- Paginated reading area on the right.
- Reader presentation remains a frontend concern and must not introduce layout markup into semantic story content.

#### Content Architecture

Writing uses one independent authoritative source per story: `local-content/writing/<story-id>/content.docx`. Stories are individually editable, translatable, integratable, and versionable; no monolithic Writing DOCX is permitted. Each source is transformed into independent bilingual semantic targets at `content/writing/<story-id>/en.html` and `content/writing/<story-id>/es.html`.

The transformation preserves authored paragraph boundaries, intentional spacing, source order, emphasis, literary pacing, and headings that actually exist as far as practical. It must not invent literary headings. Optional story images live under `assets/writing/<story-id>/images/`; an image is not required.

`data/stories.json` remains the single metadata-only Writing registry. It owns story identity, order, bilingual display title, status, content paths, and optional asset references, never story prose.

### ONIRIC JOURNAL / DIARIO ONÍRICO

`ONIRIC JOURNAL` and `DIARIO ONÍRICO` are the canonical English and Spanish display names. Existing `/dream-journal/` routes are legacy paths and remain unchanged until the future frontend migration.

- Introductory description.
- List of dream entries.
- Compact rows derived from the Projects interaction model.
- Scale response and colour inversion on hover.
- Registry-derived entry number.
- Dream date.

#### Content Architecture

Each entry is one independent authoritative source at `local-content/oniric-journal/<entry-id>/content.docx`; known dates use an ISO date as the entry ID. No monolithic journal DOCX is permitted. Each source is transformed into bilingual semantic targets at `content/oniric-journal/<entry-id>/en.html` and `content/oniric-journal/<entry-id>/es.html`.

Entry content may contain a date or identity region, Dream, Analysis, optional authored subsections, tables or glossaries, and Concepts. The source remains authoritative and optional structures are not required. Public images are optional and live under `assets/oniric-journal/<entry-id>/images/`.

`data/oniric-journal.json` is the single metadata-only registry after migration from the unused `data/dreams.json` placeholder. Registry order drives display numbering and previous/next relationships; those values must not be hard-coded into DOCX prose. The future UI may highlight no more than four concepts per entry.

Legacy `data/dreams.json`, `assets/dreams/`, `local-content/dreams/`, and `content/dreams/` paths must be audited before migration. Unused placeholders may move to the canonical structure, but any path used by a runtime consumer must remain until the related frontend migration, and real content must never be deleted. Two active registries are not permitted.

#### Future Entry Detail

- Date heading
- Dream text
- Analysis heading
- Analysis text
- Concepts
- Maximum of four concept images
- Previous/next dream navigation

## Responsive Intentions

### Desktop

The full fixed header and permanently accessible main navigation are visible. Games may use up to four columns. Writing uses its side-by-side bibliography and reading layout. Project and journal rows retain their full horizontal form.

### Tablet

At approximately `900px`, layouts reduce columns, spacing, and display scale. Navigation may transition toward its compact mode where needed, while language and identity remain visible and accessible.

### Mobile

At approximately `640px`, content becomes predominantly single-column. The main navigation uses an accessible collapsed menu. Game grids, galleries, Writing, project entries, and journal entries adapt without removing content or language controls.

These widths are architectural targets, not final token values. Breakpoints may be refined during implementation based on content behavior.
