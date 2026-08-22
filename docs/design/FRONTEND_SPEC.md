# FRONTEND SPECIFICATION — Portfolio v0.2

**Status:** Authoritative frontend design contract
**Project:** Carlos Lopez — Personal Portfolio
**Version target:** v0.2
**Source design brief:** 18 August 2026
**Purpose:** Give Codex, ChatGPT, and any future developer a persistent source of truth for the visual hierarchy, page structure, interaction intent, and frontend behaviour of the portfolio.

---

## 0. How to use this specification

This document is the authoritative **presentation/design contract** for the v0.2 frontend.

When implementing the website, read this together with:

- `docs/development/ARCHITECTURE.md`
- `docs/development/CONTENT_PIPELINE.md`
- `docs/development/WEB_DEVLOG.md`
- `docs/development/ROADMAP.md`

The responsibilities are separated deliberately:

- **This file** controls frontend hierarchy, visual intent, page composition and interaction behaviour.
- **ARCHITECTURE.md** controls repository and technical architecture.
- **CONTENT_PIPELINE.md** controls authoring/content transformation.
- **JSON registries** control metadata, paths, order and relationships.
- **Semantic HTML fragments** contain public long-form content.
- **Assets** contain images, scans, PDFs and video.
- **Frontend code** controls presentation and interaction.

Do not move long-form copy into JavaScript or JSON to make layout implementation easier.

The sketches are **structural references**, not pixel-perfect mock-ups. Preserve their hierarchy, relative composition, navigation logic and interaction intent while applying the established dark sci-fi visual language of the existing portfolio.

---

# THE 16 DESIGN RULES

## Rule 1 — Structural design philosophy

The website follows the structural logic of Frank Lantz's personal site: simple, solid, readable and page-oriented.

Reference:
- https://www.franklantz.net/about-1

The current portfolio's darker technological / science-fiction direction should be preserved and refined rather than replaced.

Additional visual references:
- Kojima Productions News
- Playdead / INSIDE
- SpaceX Human Spaceflight
- Bloober Team Games

These are references for tone, atmosphere and visual language only. Do not copy their layouts or branding.

The primary structural sketch set lives in:

`docs/design/sketches/`

---

## Rule 2 — Content architecture is external to presentation

The frontend must consume the content architecture already built for:

- About
- CV
- Games
- Projects
- Writing
- Oniric Journal

General copy, professional material, stories, dreams, project documents and GDDs are authored outside the frontend.

The frontend must not become a second source of truth for content.

---

## Rule 3 — Frontend follows the existing repository architecture

Do not invent a parallel content system.

Use the established repository separation:

- `data/` → registries / metadata
- `content/` → semantic EN/ES HTML fragments
- `assets/` → public media
- `local-content/` → ignored authoring sources
- frontend files → presentation / interaction only

The frontend must be capable of consuming new entries added through the existing authoring pipeline without requiring bespoke page rewrites.

---

## Rule 4 — Responsive + bilingual website

The website must be responsive across desktop, tablet and mobile.

The user can switch between:

- `ESP`
- `ENG`

The language selector sits at the top-left area, above or immediately associated with the designer identity/name, according to the About/global-shell sketch.

Changing language should preserve the equivalent current page/item whenever possible.

---

## Rule 5 — Typography

Primary body typography:

- Courier / Courier-family monospace
- approximately 12 pt visual scale
- single-line-height character / compact leading as originally requested

Headings and major names may use:

- larger sizes
- bold
- italic

Do not introduce an unrelated corporate typography system.

Exact CSS values may be normalized for responsive web rendering, but the visual result must remain faithful to the requested Courier-based identity.

---

## Rule 6 — Colour language

Backgrounds:

- near-black through pure black

Text:

- near-white through pure white

The black/white duality is central to the visual identity.

Avoid introducing decorative colour systems that compete with this principle.

Colour may only appear when it belongs to authored visual assets or when a later explicit design decision adds it.

---

## Rule 7 — One main section per page

The old single-page behaviour, where scrolling moves through multiple main sections, must not remain.

Each main section has its own page / route.

Main navigation is the primary way to move between sections.

Canonical navigation for v0.2:

- ABOUT
- CV
- GAMES
- PROJECTS
- WRITING
- ONIRIC JOURNAL

Do not add Narrative or Drawings to the current navigation.

---

## Rule 8 — Main: About

Sketch:

`docs/design/sketches/00-main-about.jpg`

About is the default landing page.

The sketch contains a conceptual “main tree”; that tree is explanatory material only and must **not** be rendered on the website.

Persistent global identity/navigation:

- designer name remains visible/fixed
- main section navigation remains visible/fixed
- page scrolling must not make the global navigation disappear

About content presents:

- designer identity
- profile photograph
- About copy
- contact information

The content layer, not hardcoded frontend copy, provides the textual content.

---

## Rule 9 — Main: CV

Sketch:

`docs/design/sketches/01-main-cv.jpg`

The page follows the simple vertical structural logic of the reference site.

Required major regions:

1. Education
2. Work Experience
3. Ludography

Ludography must show the complete registered professional ludography.

At the bottom:

- Download CV
- Download Portfolio

Ludography remains data-driven from the existing registries. Do not duplicate it as manually authored frontend text.

---

## Rule 10 — Main: Games

Sketch:

`docs/design/sketches/02-main-games.jpg`

Games are grouped by company/studio.

The current professional catalogue contains the registered game data already prepared in the repository.

Desktop composition:

- maximum 4 game images/covers per row
- game title below the image

The exact number per row must reduce responsively on narrower screens.

Each game item is clickable and opens its Game Detail.

---

## Rule 11 — Game Detail

Sketch:

`docs/design/sketches/03-game-detail.jpg`

Game Detail explains:

- general overview of the game
- the designer's contribution
- systems/features designed
- relevant development/design context

The structural reading style is inspired by the reference site but adapted to this portfolio.

Media/content relationship:

- maximum 6 highlighted gallery images
- visual gallery associated with the written content
- layout should preserve the sketch's clear separation between media and text

Use:

- game metadata from registry
- EN/ES semantic content fragment
- registered cover/gallery assets

Do not hardcode per-game copy into page templates.

---

## Rule 12 — Main: Projects (I+D+I)

Sketch:

`docs/design/sketches/04-main-projects.jpg`

This page lists current personal R&D / prototype / experimental projects.

Project entries use the wide horizontal element shown in the sketch.

Hover-in behaviour:

- small scale-up
- invert black/white relationship
- dark backgrounds/icons become light
- text becomes dark

Hover-out:

- return smoothly to original scale
- return to normal colour palette

Each project entry opens Project Detail.

Hover effects must have an accessible non-hover equivalent on touch devices.

---

## Rule 13 — Project Detail

Sketch:

`docs/design/sketches/05-project-detail.jpg`

Project Detail contains four vertically read regions:

1. Brief
2. Conceptual Process
3. GDD
4. Prototype

### Brief

Short project summary / synopsis / design intent.

### Conceptual Process

Displays sketches, scans, diagrams and conceptual-development material.

The existing page/book-style navigation concept is valid and should be preserved or improved.

### GDD

Displays semantic GDD content.

The GDD keeps a left-side index/table of contents for navigation through its hierarchy.

The architecture supports multiple GDDs per project.

### Prototype

Maximum 4 highlighted videos showing prototype highlights.

### Local project navigation

A local submenu provides fast movement between:

- Brief
- Conceptual Process
- GDD
- Prototype

The four regions are still read vertically from top to bottom.

---

## Rule 14 — Main: Writing

Sketch:

`docs/design/sketches/06-main-writing.jpg`

Writing presents all authored short stories.

Desktop composition:

### Left side

Independent story list/navigation.

Each item displays the story title.

The list:

- is clickable
- may have its own scroll
- may expose explicit up/down navigation controls when useful

Selecting a story loads it in the reader on the right.

### Right side

Literary reader / page-reading system.

Visual language:

- near-black/dark page
- white/near-white typography

The reader must preserve the semantic structure and literary pacing authored in the story source.

### Current technical implementation note

The original design brief described the frontend as reading the `.doc`/DOCX directly.

The v0.2 architecture deliberately improves this:

`DOCX → Codex transformation → semantic HTML → frontend reader`

The browser therefore reads the integrated semantic HTML, not raw Word files.

This technical change preserves the original design intent while keeping the authoring pipeline maintainable.

---

## Rule 15 — Main: Oniric Journal

Sketch:

`docs/design/sketches/07-main-oniric-journal.jpg`

Original brief name: **Dream Journal**.

Canonical v0.2 name:

- EN: **ONIRIC JOURNAL**
- ES: **DIARIO ONÍRICO**

The old term “Dream Journal” is legacy terminology only.

The main page contains:

- a short introductory description
- a compact list of journal-entry elements

Entry presentation conceptually contains:

- `ENTRY #`
- `DREAM — DATE`

Entry numbering derives from registry order rather than authored prose.

Rows use a related interaction language to Projects:

- subtle scale
- black/white inversion

but remain more compact than Project cards.

Each entry opens its Oniric Journal Detail.

---

## Rule 16 — Oniric Journal Detail

Sketch:

`docs/design/sketches/08-oniric-journal-detail.jpg`

Original brief name: **In — Dream Journal**.

Canonical v0.2 implementation: **Oniric Journal Detail**.

Required content sequence:

1. date / entry heading
2. full Dream text
3. Analysis section
4. full Analysis text
5. Concepts
6. Previous / Next navigation

Maximum highlighted concepts:

- 4

Previous/Next derives from registry order.

Do not hardcode previous/next relationships inside authored semantic prose.

Dream and analysis are distinct semantic regions.

---

# GLOBAL FRONTEND CONTRACT

## Fixed global shell

The website maintains a persistent shell containing the designer identity and main navigation.

The page content scrolls independently beneath/alongside this persistent navigation according to responsive layout requirements.

On narrow devices the implementation may adapt the exact fixed arrangement, but access to navigation and language switching must remain immediate and usable.

---

## Canonical v0.2 navigation

English:

- ABOUT
- CV
- GAMES
- PROJECTS
- WRITING
- ONIRIC JOURNAL

Spanish display strings may be localized where appropriate, with:

- DIARIO ONÍRICO as the canonical journal label

Do not expose legacy “Dream Journal” terminology in the new frontend.

---

## Content-driven implementation

Collection pages must derive entries from their registries.

Detail pages must derive item identity from route/data and load the corresponding semantic fragment.

Expected pattern:

`registry → item metadata → semantic EN/ES content → assets → frontend presentation`

The frontend must not require a unique handwritten page for every future story, dream, game or project.

---

## Sketch interpretation rule

Sketches define:

- hierarchy
- page regions
- relative placement
- navigation intent
- media/text relationships
- interaction concepts

They do **not** define:

- exact pixel dimensions
- exact CSS breakpoints
- exact animation duration
- final production spacing
- browser-specific implementation details

Those should be implemented consistently with the current site visual language and refined during visual QA.

---

## Responsive intent

Desktop should preserve the full compositions shown in the sketches.

Tablet/mobile should prioritize:

1. readability
2. navigation access
3. content hierarchy
4. media legibility
5. touch usability

Do not preserve a desktop composition at the cost of horizontal overflow or unreadable text.

Desktop-only hover behaviours must have sensible touch/focus equivalents.

---

## Visual continuity with v0.1

Before replacing existing global styling, inspect the v0.1 implementation.

Retain useful parts of its:

- dark sci-fi atmosphere
- black/white visual identity
- typography character
- interaction tone

Replace structures that conflict with this specification, especially the previous single-page section flow.

Do not preserve legacy code merely because it already exists.

---

## Current v0.2 terminology overrides

These decisions supersede legacy wording in the original sketches/brief:

- `Dream Journal` → `Oniric Journal`
- Spanish → `Diario onírico`
- Writing browser source → semantic HTML generated from DOCX, not raw DOCX
- Project GDD browser source → semantic HTML generated from authoring DOCX
- Narrative is not in current navigation
- Drawings is not in current navigation

---

# SKETCH INDEX

| File | Purpose |
|---|---|
| `00-main-about.jpg` | Global shell + About landing |
| `01-main-cv.jpg` | CV page |
| `02-main-games.jpg` | Games grouped catalogue |
| `03-game-detail.jpg` | Game Detail |
| `04-main-projects.jpg` | Projects list |
| `05-project-detail.jpg` | Project Detail |
| `06-main-writing.jpg` | Writing reader |
| `07-main-oniric-journal.jpg` | Oniric Journal list |
| `08-oniric-journal-detail.jpg` | Oniric Journal Detail |

---

# IMPLEMENTATION PRIORITY

When implementation choices conflict, use this order:

1. Do not break existing content/data architecture.
2. Preserve the 16 design rules and sketch hierarchy.
3. Preserve accessibility and responsive usability.
4. Preserve the existing dark sci-fi visual identity.
5. Reuse legacy frontend code only when it still serves rules 1–4.
6. Prefer maintainable shared frontend systems over page-specific hacks.

---

# FRONTEND VISUAL QA

Automated validation can verify structure, routing, assets, loading and regression.

The following remain subject to human visual QA:

- perceived spacing
- visual balance
- scale
- typography feel
- hover/animation feel
- cinematic / sci-fi atmosphere
- similarity to sketch hierarchy
- desktop/tablet/mobile visual composition

A technically valid implementation is not considered visually final until this human QA pass is completed.
