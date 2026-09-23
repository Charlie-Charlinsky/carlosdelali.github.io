import { loadCopyrightArticle } from "../core/copyright-content.js";
import { setPageTitle } from "../core/dom.js";

export async function render({ language, target }) {
    const { article, title } = await loadCopyrightArticle(language);
    article.classList.add("semantic-content", "copyright-content");
    setPageTitle(title.textContent.trim());
    target.replaceChildren(article);
}
