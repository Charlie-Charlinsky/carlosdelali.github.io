# Portfolio Website Development Log

This file is the permanent, versioned development diary for the portfolio website. The v0.1.0 record below is based on the repository files inspected on 18 August 2026. Version-control status is recorded from the project brief; no Git operation was used during this documentation task.

## v0.1.0 — Initial Sci-Fi Portfolio Prototype

**Date:** 18 August 2026  
**Status:** Archived baseline / tagged in Git as v0.1.0.

### Typography

The global type rules are defined in `css/style.css`:

- The root font stack is `Arial, Helvetica, sans-serif`.
- The root font size is `16px`; `body` does not override it.
- The body line height is `1.55`.
- Major headings use the sans-serif stack, generally with `font-weight: 500`, `letter-spacing: 0`, uppercase text, and compressed line heights between `0.78` and `1`.
- Desktop display sizes vary by context: the homepage hero and project-entry headings are `6.5rem`; general section headings are `7.5rem`; the contact heading is `10rem`; project and archive hero headings are `8rem`; and chapter headings are `6.5rem`.
- Heading sizes reduce at the existing `70rem`, `56.25rem`, and `40rem` responsive breakpoints where relevant. At `40rem`, major headings generally fall between `2.65rem` and `3.7rem`, depending on their component.
- Shared labels and metadata such as section labels, eyebrows, project kickers, disciplines, chapter labels, and archive kickers use `0.67rem`, `700`, `0.16em` letter spacing, `1.4` line height, and uppercase text.
- The Short Stories hero is an intentional exception: it uses `Georgia, "Times New Roman", serif`, `font-weight: 400`, and preserves mixed case.
- Native GDD body copy and lists use `Georgia, "Times New Roman", serif`. GDD paragraphs use `1.15rem` with `1.75` line height.
- GDD formula blocks and implementation notes use `"Courier New", monospace`; formula blocks are `1.25rem`, while implementation notes are `0.78rem`.

### Colour System

The current design tokens are:

| Role | CSS token | Actual value |
| --- | --- | --- |
| Main page background / darkest ink | `--ink` | `#090a0a` |
| Dark surface | `--ink-soft` | `#101212` |
| Charcoal surface token | `--charcoal` | `#191b1a` |
| Steel neutral token | `--steel` | `#333735` |
| Standard dark-theme border | `--line` | `rgba(233, 234, 226, 0.18)` |
| Strong dark-theme border | `--line-strong` | `rgba(233, 234, 226, 0.38)` |
| Primary text / light GDD surface | `--paper` | `#e9eae2` |
| Secondary light text | `--paper-dark` | `#c7c8c0` |
| Muted text | `--muted` | `#949992` |
| Dark red accent | `--signal` | `#a84635` |
| Bright red accent | `--signal-bright` | `#c45b46` |
| Concept-book page surface | `--page` | `#d4d1c7` |
| Concept-book page ink | `--page-ink` | `#242625` |

The body combines `#090a0a` with a subtle radial highlight of `rgba(255, 255, 255, 0.035)`. Selection text is `#fff` on `#a84635`.

Component-specific dark surfaces include `#111313` for the homepage hero visual, `#111312` for the Concept Book chapter, `#0b0c0c` for the book stage and prototype media, and `#0d0e0e` for the Short Stories hero copy. Component-specific neutral copy includes `#676b67`, `#686d68`, `#5a5e5a`, `#656a65`, `#656863`, `#777a74`, `#5f645f`, `#60645f`, `#666a65`, `#3f433f`, `#5b605b`, `#4f544f`, and `#555a55`. Light document rules and shadows use alpha variants derived mainly from `#090a0a` and `#242625`.

### Existing Pages

The repository contains seven HTML pages:

| Route | File | Current purpose |
| --- | --- | --- |
| `/` | `index.html` | Main scrolling portfolio homepage |
| `/projects/project-1/` | `projects/project-1/index.html` | Project 1 detail prototype |
| `/projects/project-2/` | `projects/project-2/index.html` | Project 2 detail prototype |
| `/projects/project-3/` | `projects/project-3/index.html` | Project 3 detail prototype |
| `/projects/project-4/` | `projects/project-4/index.html` | Project 4 detail prototype |
| `/narrative/narrative-design/` | `narrative/narrative-design/index.html` | Narrative Design archive placeholder |
| `/narrative/stories/` | `narrative/stories/index.html` | Short Stories archive placeholder |

The homepage exposes the in-page routes `#index`, `#projects`, `#narrative`, `#about`, `#experience`, and `#contact`. Each project page exposes `#intro`, `#concepts`, `#gdd`, and `#prototype`, with further anchors inside the native GDD demonstration.

### Architecture

v0.1.0 is a static HTML, CSS, and vanilla JavaScript site. The homepage is primarily a single-page scrolling experience with a fixed global header and anchor navigation. Project cards open four independent project pages. Each project page combines a project hero, sticky local chapter navigation, a Concept Book prototype, a native HTML GDD presentation experiment, a prototype-media placeholder, and previous/next project navigation.

Narrative is an active homepage section in v0.1.0 and links to two independent placeholder pages: Narrative Design and Short Stories. All pages share `css/style.css` and `js/main.js`. The script manages fixed-header state, the responsive navigation menu, active-section tracking, reveal-on-scroll behavior, the current footer year, and keyboard/touch controls for the Concept Book.

At widths up to `56.25rem` (900px), the main navigation becomes a full-screen menu controlled by the menu button. At `40rem` (640px), layouts and display type reduce further for mobile.

### Visual Direction

The v0.1.0 visual direction is dark, technological, science-fiction oriented, psychologically tense, and cinematic. Its reference field includes Kojima Productions, Playdead / INSIDE, SpaceX Human Spaceflight, and Bloober Team. The implementation expresses this direction through near-black surfaces, technical grids, restrained red signals, large compressed typography, interface-like metadata, geometric media placeholders, and controlled motion.

### Changelog

v0.1.0 established the first complete visual prototype and the initial visual language. It introduced the scrolling homepage, four project-page experiments, the Concept Book prototype, native GDD presentation experiments, Narrative placeholders, responsive navigation, scroll-based interaction, and placeholder structures for future visual and prototype media.

## v0.2.0 — Personal Archive Architecture

**Date:** 18 August 2026  
**Status:** Architecture in development.

### Infrastructure

The root `.gitattributes` file normalises repository text files to LF while excluding binary portfolio and media files from text normalisation; SVG remains text. This prevents inconsistent Windows CRLF / LF behaviour as the portfolio grows.

### Professional Data Layer

Professional data layer introduced:

- Canonical game registry.
- Reference-based ludography.
- Structured CV metadata.
- Incomplete historical game lists can be explicitly flagged rather than guessed.

### Game Detail Architecture

Game Detail architecture introduced:

- Canonical metadata remains in `games.json`.
- Long-form contribution content is separated into semantic HTML.
- Game media is separated into dedicated asset structures.
- The shared Game Detail model supports multiple feature/system contribution sections.
- The visible gallery is capped at six images.

### First Professional Game Detail Content

First professional Game Detail content introduced:

- The Little Prince.
- Bilingual EN / ES semantic case study.
- Overview.
- Level Design.
- Game Mode Design.
- `games.json` content references connected.
- Dedicated asset structure created.
- First Game Detail visual asset set integrated.
- One dedicated cover image.
- Three gallery images.
- Asset filenames normalised to lowercase kebab-case.
- `games.json` asset references connected.
- `assetsStatus` changed to `ready`.

### Typography

Planned body typography:

```css
font-family: Courier, "Courier New", monospace;
font-size: 12pt;
line-height: approximately 1;
```

The intended rhythm is single line spacing. Headings and major titles may use larger sizes, bold, italic, or a combination of those treatments.

### Colour Direction

The design will be based primarily on pure black, near-black, dark neutral surfaces, pure white, off-white, and neutral greys. The central visual principle is black / white duality.

Exact v0.2.0 colour tokens are **TBD until implemented**. No final HEX palette has been assigned at this stage.

### Main Pages

The active main pages planned for v0.2.0 are:

- ABOUT
- CV
- GAMES
- PROJECTS (I+D+I)
- WRITING
- DREAM JOURNAL

Narrative and Drawings are not part of the active v0.2.0 navigation.

### Architecture Changes

- Move from a primarily single-page scrolling homepage to independent main pages.
- Make About the default landing page.
- Introduce a fixed global header.
- Keep the designer name permanently visible.
- Keep the main navigation permanently accessible on desktop.
- Provide responsive mobile navigation.
- Place the ESP / ENG language selector above the designer name at the upper-left.
- Create independent Spanish and English page trees.
- Support responsive layouts across desktop, tablet, and mobile.
- Separate content from presentation.
- Treat professional work, R&D projects, writing, and the dream archive as different content systems.

### Reference Structure

Frank Lantz's personal website is the primary structural reference for simplicity, solidity, and clearly separated pages. The visual language will continue the existing science-fiction and technological direction rather than replacing it with the reference site's visual identity.
