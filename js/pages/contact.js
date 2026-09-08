import { loadSemanticFragment } from "../core/loaders.js";
import { setPageTitle } from "../core/dom.js";

export async function render({ language, target }) {
    const fragment = await loadSemanticFragment(`content/contact/${language}.html`);
    const article = fragment.querySelector("article");
    article.classList.add("semantic-content", "contact-content");
    setPageTitle(language === "es" ? "Contacto" : "Contact");
    target.replaceChildren(article);
}
