import { resolveRoute } from "./paths.js";

export function getPageContext() {
    return {
        language: document.body.dataset.lang || document.documentElement.lang || "en",
        page: document.body.dataset.page || "about"
    };
}

export function getCurrentItemQuery(page) {
    const params = new URLSearchParams(window.location.search);
    if (page === "game-detail" || page === "project-detail" || page === "oniric-journal-detail") {
        return { id: params.get("id") };
    }
    if (page === "writing") return { story: params.get("story") };
    return {};
}

export function getEquivalentLanguageUrl(language, page) {
    return resolveRoute(language, page, {
        query: getCurrentItemQuery(page),
        hash: window.location.hash
    });
}

export function detailUrl(language, family, id) {
    const page = family === "games"
        ? "game-detail"
        : family === "projects"
            ? "project-detail"
            : "oniric-journal-detail";
    return resolveRoute(language, page, { query: { id } });
}
