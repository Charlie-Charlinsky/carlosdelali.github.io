import { loadCopyrightArticle } from "./copyright-content.js";
import { createElement } from "./dom.js";
import { resolveRoute } from "./paths.js";

async function hydrateFooter(footer, language) {
    try {
        const { summary } = await loadCopyrightArticle(language);
        const link = createElement("a", {
            className: "site-footer__copyright",
            text: summary.textContent.trim(),
            attributes: { href: resolveRoute(language, "copyright") }
        });
        footer.replaceChildren(link);
        footer.hidden = false;
    } catch {
        footer.hidden = true;
    }
}

export function buildFooter(language) {
    document.querySelector("#site-footer")?.remove();
    const footer = createElement("footer", {
        className: "site-footer",
        attributes: { id: "site-footer", hidden: "" }
    });
    const main = document.querySelector("#main-content");
    if (main) main.insertAdjacentElement("afterend", footer);
    void hydrateFooter(footer, language);
    return footer;
}
