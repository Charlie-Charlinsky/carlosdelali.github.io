import { loadJson, loadSemanticFragment } from "../core/loaders.js";
import { createElement, setPageTitle } from "../core/dom.js";
import { createBackLink, createMediaImage, localizedValue } from "../core/components.js";
import { resolveRoute } from "../core/paths.js";

const SECTION_IDS = ["brief", "conceptual-process", "gdd", "prototype"];

function buildLocalNavigation(article, language) {
    const nav = createElement("nav", {
        className: "local-nav",
        attributes: { "aria-label": language === "es" ? "Secciones del proyecto" : "Project sections" }
    });
    SECTION_IDS.forEach((id) => {
        const section = article.querySelector(`#${id}`);
        if (!section) return;
        const label = section.querySelector(":scope > h2")?.textContent.trim() || id;
        nav.append(createElement("a", { text: label, attributes: { href: `#${id}` } }));
    });
    return nav;
}

function decorateGdd(article, language) {
    const gdd = article.querySelector("#gdd");
    if (!gdd) return;
    const headings = [...gdd.querySelectorAll(":scope > section[id] > h3")];
    if (!headings.length) return;
    const layout = createElement("div", { className: "gdd-layout" });
    const toc = createElement("nav", {
        className: "gdd-toc",
        attributes: { "aria-label": language === "es" ? "Índice del GDD" : "GDD contents" }
    });
    headings.forEach((heading) => {
        toc.append(createElement("a", {
            text: heading.textContent.trim(),
            attributes: { href: `#${heading.parentElement.id}` }
        }));
    });
    const content = createElement("div", { className: "gdd-document" });
    [...gdd.children].filter((child) => child.tagName === "SECTION").forEach((section) => content.append(section));
    layout.append(toc, content);
    gdd.append(layout);
}

function appendProjectMedia(article, project, language) {
    const conceptual = article.querySelector("#conceptual-process");
    if (conceptual && project.assets.conceptualProcess.length) {
        const gallery = createElement("div", { className: "concept-gallery" });
        project.assets.conceptualProcess.forEach((path, index) => {
            const figure = createElement("figure");
            figure.append(createMediaImage(path, `${language === "es" ? "Proceso conceptual" : "Conceptual process"} ${index + 1}`));
            gallery.append(figure);
        });
        conceptual.append(gallery);
    }

    const prototype = article.querySelector("#prototype");
    if (prototype && project.prototypeVideos.length) {
        const videos = createElement("div", { className: "prototype-grid" });
        project.prototypeVideos.slice(0, 4).forEach((video) => {
            const element = createElement("video", {
                attributes: { controls: "", preload: "metadata", src: video.path || video.src, poster: video.poster }
            });
            videos.append(element);
        });
        prototype.append(videos);
    }
}

export async function render({ language, target }) {
    const registry = await loadJson("data/projects.json");
    const id = new URLSearchParams(window.location.search).get("id");
    const project = registry.projects.find((item) => item.id === id);
    if (!project) {
        const state = createElement("section", { className: "not-found" });
        state.append(
            createElement("h1", { text: language === "es" ? "Proyecto no encontrado" : "Project not found" }),
            createBackLink(resolveRoute(language, "projects"), language === "es" ? "Proyectos" : "Projects")
        );
        target.replaceChildren(state);
        return;
    }

    const fragment = await loadSemanticFragment(project.content[language]);
    const article = fragment.querySelector("article");
    article.classList.add("semantic-content", "project-content");
    const authoredTitle = article.querySelector("header h1, header h2")?.textContent.trim();
    const title = localizedValue(project.title, language, authoredTitle || project.id);
    decorateGdd(article, language);
    appendProjectMedia(article, project, language);

    const page = createElement("div", { className: "detail-page project-detail" });
    const heading = createElement("header", { className: "project-detail__header" });
    heading.append(
        createBackLink(resolveRoute(language, "projects"), language === "es" ? "Proyectos" : "Projects"),
        createElement("p", { className: "eyebrow", text: "I+D+I / R&D" }),
        createElement("h1", { text: title })
    );
    const identity = article.querySelector("#project-identity");
    if (identity) identity.hidden = true;
    page.append(heading, buildLocalNavigation(article, language), article);
    setPageTitle(title);
    target.replaceChildren(page);
}
