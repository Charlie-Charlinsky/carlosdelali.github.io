# Portfolio Website Architecture

This document defines the planned information architecture for v0.2.0. The bilingual `/en/` and `/es/` route trees listed below already exist in the current repository as placeholder HTML pages and form the current physical scaffold. Their final layouts, components, content integration, navigation behaviour, and visual design are not implemented yet.

## Active Main Navigation

- ABOUT
- CV
- GAMES
- PROJECTS
- WRITING
- DREAM JOURNAL

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
/en/dream-journal/

/es/
  About

/es/cv/
/es/games/
/es/projects/
/es/writing/
/es/dream-journal/
```

English is intended to be the primary professional version. Spanish will be a full equivalent version, not a reduced secondary site. The exact default-language behavior at `/` remains an implementation decision, but it must lead to the About landing experience and provide a clear path to both language trees.

Detail-page route patterns will be defined when content identifiers and URL conventions are established. They must remain descendants of their corresponding language and page family.

## Global Header

The intended desktop header is fixed while page content scrolls.

```text
Upper left:  ESP / ENG
Below:       CARLOS J. L. SÁNCHEZ
Right:       About / CV / Games / Projects / Writing / Dream Journal
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

### CV

- Education
- Work Experience
- Ludography
- Download CV
- Download Portfolio

The webpage is the native presentation. Downloadable files are supporting resources.

### GAMES

- Organised by company or studio.
- Maximum of four game columns on desktop.
- Responsive reduction in columns for tablet and mobile.
- Each game links to its own detail page.

### GAME DETAIL

- Game overview
- Metadata
- Explanation of role and contribution
- Maximum of six gallery images
- Previous/next gallery navigation

#### Content Architecture

A Game Detail page presents:

1. Game identity / overview
2. Professional contribution
3. Systems, features, or design areas worked on
4. Supporting image gallery

A single game may contain multiple professional contribution subsections. The conceptual content structure is:

```text
Game
├── Overview
├── My Contribution
│   ├── Feature / System A
│   ├── Feature / System B
│   └── Feature / System C
└── Gallery
```

On desktop, the visual gallery is positioned alongside the written content. A maximum of six gallery images may be available for the visible page, while game metadata and professional contribution remain the primary information. The layout becomes responsive on tablet and mobile. Final CSS dimensions are intentionally undefined at this architecture stage.

### PROJECTS (I+D+I)

- Current personal games and prototypes.
- Large horizontal project entries.
- Scale response on hover.
- Black/white palette inversion on hover.
- Clicking an entry opens its project detail page.

### PROJECT DETAIL

- Brief
- Conceptual Process
- GDD
- Prototype
- Vertical reading structure
- Local project submenu
- Concept Book
- Native HTML GDD
- Maximum of four prototype videos

### WRITING

- Story bibliography or list on the left.
- Independent scrolling for the story list.
- Clickable story entries.
- Paginated reading area on the right.
- Source formatting preserved from the original document as far as practical in semantic HTML.

### DREAM JOURNAL

- Introductory description.
- List of dream entries.
- Compact rows derived from the Projects interaction model.
- Scale response and colour inversion on hover.
- Entry number.
- Dream date.

### DREAM DETAIL

- Date heading
- Dream text
- Analysis heading
- Analysis text
- Concepts
- Maximum of four concept images
- Previous/next dream navigation

## Responsive Intentions

### Desktop

The full fixed header and permanently accessible main navigation are visible. Games may use up to four columns. Writing uses its side-by-side bibliography and reading layout. Project and dream rows retain their full horizontal form.

### Tablet

At approximately `900px`, layouts reduce columns, spacing, and display scale. Navigation may transition toward its compact mode where needed, while language and identity remain visible and accessible.

### Mobile

At approximately `640px`, content becomes predominantly single-column. The main navigation uses an accessible collapsed menu. Game grids, galleries, Writing, project entries, and dream entries adapt without removing content or language controls.

These widths are architectural targets, not final token values. Breakpoints may be refined during implementation based on content behavior.
