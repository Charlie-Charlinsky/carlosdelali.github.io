import { loadSemanticFragment } from "../core/loaders.js";
import { createElement, setPageTitle } from "../core/dom.js";
import { createMediaImage } from "../core/components.js";

export async function render({ language, target }) {
    const fragment = await loadSemanticFragment(`content/about/${language}.html`);
    const article = fragment.querySelector("article");
    article.classList.add("semantic-content", "about-content");

    const identity = article.querySelector("#identity");
    const authoredName = identity?.querySelector("h2")?.textContent.trim() || "Carlos J. L. Sánchez";
    setPageTitle(language === "es" ? `Sobre mí | ${authoredName}` : `About | ${authoredName}`);

    if (identity) identity.hidden = true;
    ["#about-copy > h2", "#contact > h2"].forEach((selector) => {
        const heading = article.querySelector(selector);
        if (heading) heading.hidden = true;
    });

    const page = createElement("div", { className: "about-layout" });
    const portrait = createElement("figure", { className: "about-portrait" });
    portrait.append(createMediaImage(
        "assets/about/profile/carlos-lopez-profile.png",
        language === "es" ? "Retrato de Carlos J. L. Sánchez" : "Portrait of Carlos J. L. Sánchez",
        "about-portrait__image"
    ));
    page.append(portrait, article);
    target.replaceChildren(page);
}
