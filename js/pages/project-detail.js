import { loadJson, loadSemanticFragment } from "../core/loaders.js";
import { createElement, setPageTitle } from "../core/dom.js";
import { createBackLink, createMediaImage, localizedValue } from "../core/components.js";
import { resolveRoute } from "../core/paths.js";
import { createProjectMediaGallery } from "./project-media-gallery.js";

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

function appendConceptualProcessMedia(article, project, language) {
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
}

function createBriefPanel(project, brief, title, language) {
    const heading = brief.querySelector(":scope > h2");
    const panel = createElement("aside", {
        className: "project-showcase__panel",
        attributes: { "aria-label": heading?.textContent.trim() || "Brief" }
    });
    heading?.remove();
    if (project.assets.icon) {
        const icon = createElement("figure", { className: "project-showcase__icon" });
        icon.append(createMediaImage(
            project.assets.icon,
            language === "es" ? `Icono de ${title}` : `${title} icon`,
            "project-showcase__icon-image"
        ));
        panel.append(icon);
    }
    brief.classList.add("project-showcase__brief");
    panel.append(brief);

    if (project.playPrototypeUrl) {
        const play = createElement("p", { className: "project-showcase__play" });
        play.append(
            createElement("span", { text: language === "es" ? "Jugar prototipo: " : "Play Prototype: " }),
            createElement("a", {
                text: language === "es" ? "Abrir ↗" : "Open ↗",
                attributes: {
                    href: project.playPrototypeUrl,
                    target: "_blank",
                    rel: "noopener noreferrer"
                }
            })
        );
        panel.append(play);
    }
    return panel;
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
    const brief = article.querySelector("#brief");
    if (!brief) throw new Error(`Project ${project.id} has no Brief section.`);
    article.querySelector("#project-identity")?.remove();
    article.querySelector("#prototype")?.remove();
    decorateGdd(article, language);
    appendConceptualProcessMedia(article, project, language);

    const page = createElement("div", { className: "detail-page project-detail" });
    const showcase = createElement("section", {
        className: "project-showcase",
        attributes: { "aria-label": language === "es" ? "Presentación del proyecto" : "Project showcase" }
    });
    showcase.append(
        createProjectMediaGallery(project.media, { language, title }),
        createBriefPanel(project, brief, title, language)
    );
    page.append(showcase, article);
    setPageTitle(title);
    target.replaceChildren(page);
}
