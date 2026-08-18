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

### Example Story

```text
local-content/writing/story-name/story.es.docx
        ↓
Codex reads source
        ↓
content/writing/story-name/es.html
        ↓
data/stories.json indexes the entry
        ↓
Writing Reader displays it
```

The index should contain the public metadata needed to locate, order, label, and present each story without extracting metadata from rendered markup at runtime.

### Example Dream

```text
local-content/dreams/YYYY-MM-DD/
    dream.es.docx
    dream.en.docx
    analysis.es.docx
    analysis.en.docx

        ↓

semantic HTML + metadata + optional concept assets
```

The transformed output must keep dream text and analysis as distinct semantic fields. Metadata should identify the date, entry number, language, available concepts, and previous/next relationships.

### Example Project

```text
local-content/projects/project-name/
    brief.*
    gdd.*

assets/projects/project-name/
    hero/
    concepts/
    prototype/

        ↓

Project detail website
```

The project pipeline combines transformed textual content, structured project metadata, and public media assets. The resulting page must remain a native website rather than a wrapper around source documents.

## Content Rules

### Game Design Documents

GDDs must ultimately be presented as native semantic HTML, not as embedded PDFs. Source documents may be imported, but their headings, navigation, sections, tables, callouts, and media references should become accessible web structures.

### Conceptual Process

Conceptual Process scans are public visual assets. Project pages display them through the Concept Book component, with semantic captions, ordering metadata, alternative text, and keyboard/touch navigation where appropriate.

### Prototype Media

Prototype videos are public media assets. A project page may display a maximum of four highlighted prototype videos. Metadata should identify poster images, captions, formats, and accessibility requirements independently from the page template.

## Synchronisation Expectations

- Source-to-web transformation should be repeatable.
- Bilingual documents should preserve a stable relationship between equivalent entries.
- Structured indexes should own titles, slugs, dates, order, language availability, and cross-entry navigation.
- Generated HTML should remain reviewable and accessible.
- Public content and assets may be versioned; private authoring sources in the ignored `local-content/` directory remain outside public version control.
