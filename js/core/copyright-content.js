import { loadSemanticFragment } from "./loaders.js";

export async function loadCopyrightArticle(language) {
    const fragment = await loadSemanticFragment(`content/copyright/${language}.html`);
    const article = fragment.querySelector('article[data-page-id="copyright"]');
    const title = article?.querySelector("header > h1");
    const summary = article?.querySelector('header > [data-copyright-summary="true"]');
    const legalContent = article?.querySelector("#legal-content");

    if (!article || !title || !summary || !legalContent) {
        throw new Error(`Invalid copyright:${language} semantic fragment.`);
    }

    return { article, title, summary, legalContent };
}
