import { loadJson } from "../core/loaders.js";
import { createElement, padIndex, setPageTitle } from "../core/dom.js";
import { localizedValue } from "../core/components.js";
import { detailUrl } from "../core/routes.js";

export async function render({ language, target }) {
    const registry = await loadJson("data/oniric-journal.json");
    const entries = [...registry.entries].sort((a, b) => a.order - b.order);
    const page = createElement("div", { className: "collection-page journal-page" });
    const list = createElement("ol", { className: "journal-list" });
    entries.forEach((entry, index) => {
        const item = createElement("li", { className: "journal-entry" });
        const link = createElement("a", { attributes: { href: detailUrl(language, "oniric-journal", entry.id) } });
        link.append(
            createElement("span", { className: "journal-entry__number", text: `${language === "es" ? "ENTRADA" : "ENTRY"} ${padIndex(index)}` }),
            createElement("strong", { text: localizedValue(entry.title, language, entry.date) }),
            createElement("span", { className: "journal-entry__arrow", text: "→", attributes: { "aria-hidden": "true" } })
        );
        item.append(link);
        list.append(item);
    });
    page.append(list);
    setPageTitle(language === "es" ? "Diario Onírico" : "Oniric Journal");
    target.replaceChildren(page);
}
