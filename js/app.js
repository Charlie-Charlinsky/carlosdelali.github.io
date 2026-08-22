import { buildShell } from "./core/shell.js";
import { getPageContext } from "./core/routes.js";
import { renderError, renderLoading } from "./core/dom.js";
import { storeLanguage } from "./core/language.js";

const PAGE_MODULES = {
    about: () => import("./pages/about.js"),
    cv: () => import("./pages/cv.js"),
    games: () => import("./pages/games.js"),
    "game-detail": () => import("./pages/game-detail.js"),
    projects: () => import("./pages/projects.js"),
    "project-detail": () => import("./pages/project-detail.js"),
    writing: () => import("./pages/writing.js"),
    "oniric-journal": () => import("./pages/oniric-journal.js"),
    "oniric-journal-detail": () => import("./pages/oniric-journal-detail.js")
};

async function initialize() {
    const context = getPageContext();
    const target = document.querySelector("#app-content");
    document.documentElement.lang = context.language;
    storeLanguage(context.language);
    buildShell(context.language, context.page);
    renderLoading(target, context.language === "es" ? "Cargando..." : "Loading...");

    try {
        const loadModule = PAGE_MODULES[context.page];
        if (!loadModule) throw new Error(`Unknown page module: ${context.page}`);
        const pageModule = await loadModule();
        await pageModule.render({ ...context, target });
        document.body.classList.add("is-ready");
    } catch (error) {
        console.error(error);
        renderError(target, error, context.language);
    }
}

initialize();
