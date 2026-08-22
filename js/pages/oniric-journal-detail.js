import { loadJson, loadSemanticFragment } from "../core/loaders.js";
import { createElement, setPageTitle } from "../core/dom.js";
import { createBackLink, localizedValue } from "../core/components.js";
import { detailUrl } from "../core/routes.js";
import { resolveRoute } from "../core/paths.js";

function deriveConcepts(article, language) {
    const table = article.querySelector("#analysis table");
    if (!table) return null;
    const concepts = [...table.querySelectorAll("tbody tr")]
        .map((row) => row.querySelector("td")?.textContent.trim())
        .filter(Boolean)
        .slice(0, 4);
    if (!concepts.length) return null;
    const section = createElement("section", { className: "journal-concepts", attributes: { id: "concepts" } });
    section.append(createElement("h2", { text: language === "es" ? "Conceptos" : "Concepts" }));
    const list = createElement("ul");
    concepts.forEach((concept) => list.append(createElement("li", { text: concept })));
    section.append(list);
    return section;
}

function createEntryNavigation(entries, index, language) {
    const nav = createElement("nav", {
        className: "entry-navigation",
        attributes: { "aria-label": language === "es" ? "Navegación entre entradas" : "Entry navigation" }
    });
    const previous = entries[index - 1];
    const next = entries[index + 1];
    const previousSlot = createElement("div");
    const nextSlot = createElement("div");
    if (previous) previousSlot.append(createElement("a", {
        text: `← ${language === "es" ? "Anterior" : "Previous"}`,
        attributes: { href: detailUrl(language, "oniric-journal", previous.id) }
    }));
    if (next) nextSlot.append(createElement("a", {
        text: `${language === "es" ? "Siguiente" : "Next"} →`,
        attributes: { href: detailUrl(language, "oniric-journal", next.id) }
    }));
    nav.append(previousSlot, nextSlot);
    return nav;
}

export async function render({ language, target }) {
    const registry = await loadJson("data/oniric-journal.json");
    const entries = [...registry.entries].sort((a, b) => a.order - b.order);
    const id = new URLSearchParams(window.location.search).get("id");
    const index = entries.findIndex((entry) => entry.id === id);
    if (index < 0) {
        const state = createElement("section", { className: "not-found" });
        state.append(
            createElement("h1", { text: language === "es" ? "Entrada no encontrada" : "Entry not found" }),
            createBackLink(resolveRoute(language, "oniric-journal"), language === "es" ? "Diario Onírico" : "Oniric Journal")
        );
        target.replaceChildren(state);
        return;
    }

    const entry = entries[index];
    const fragment = await loadSemanticFragment(entry.content[language]);
    const article = fragment.querySelector("article");
    article.classList.add("semantic-content", "journal-content");
    const sourceHeader = article.querySelector(":scope > header");
    if (sourceHeader) sourceHeader.hidden = true;
    const concepts = deriveConcepts(article, language);
    if (concepts) article.append(concepts);

    const page = createElement("div", { className: "detail-page journal-detail" });
    const heading = createElement("header", { className: "journal-detail__header" });
    heading.append(
        createBackLink(resolveRoute(language, "oniric-journal"), language === "es" ? "Diario Onírico" : "Oniric Journal"),
        createElement("p", { className: "eyebrow", text: `${language === "es" ? "ENTRADA" : "ENTRY"} ${String(index + 1).padStart(3, "0")}` }),
        createElement("h1", { text: localizedValue(entry.title, language, entry.date) })
    );
    page.append(heading, article, createEntryNavigation(entries, index, language));
    setPageTitle(localizedValue(entry.title, language, entry.date));
    target.replaceChildren(page);
}
