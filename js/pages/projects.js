import { loadJson, loadSemanticFragment } from "../core/loaders.js";
import { createElement, setPageTitle } from "../core/dom.js";
import { createMediaImage, localizedValue } from "../core/components.js";
import { detailUrl } from "../core/routes.js";

const PROJECT_METADATA_LABELS = {
    en: { genre: "Genre", platform: "Platform", creationDate: "Creation Date" },
    es: { genre: "Género", platform: "Plataforma", creationDate: "Fecha de creación" }
};

async function getProjectTitle(project, language) {
    const registryTitle = localizedValue(project.title, language);
    if (registryTitle) return registryTitle;
    try {
        const fragment = await loadSemanticFragment(project.content[language]);
        return fragment.querySelector("h1, h2")?.textContent.trim() || project.id;
    } catch {
        return project.id;
    }
}

function createMetadataRow(label, value) {
    const row = createElement("div", { className: "project-card__metadata-row" });
    row.append(
        createElement("dt", { text: label }),
        createElement("dd", { text: value || "?" })
    );
    return row;
}

function createProjectCard(project, title, language) {
    const labels = PROJECT_METADATA_LABELS[language];
    const card = createElement("article", { className: "project-card" });
    const link = createElement("a", {
        className: "project-card__link",
        attributes: { href: detailUrl(language, "projects", project.id) }
    });
    const icon = createElement("div", { className: "project-card__icon" });
    if (project.assets.icon) {
        icon.append(createMediaImage(project.assets.icon, "", "project-card__icon-image"));
    }

    const panel = createElement("div", { className: "project-card__panel" });
    if (project.assets.background) {
        panel.append(createMediaImage(project.assets.background, "", "project-card__background"));
    }
    const copy = createElement("div", { className: "project-card__copy" });
    const metadata = createElement("dl", { className: "project-card__metadata" });
    metadata.append(
        createMetadataRow(labels.genre, localizedValue(project.genre, language, "?")),
        createMetadataRow(labels.platform, localizedValue(project.platform, language, "?")),
        createMetadataRow(labels.creationDate, localizedValue(project.creationDate, language, "?"))
    );
    copy.append(createElement("h2", { text: title }), metadata);
    panel.append(
        copy,
        createElement("span", {
            className: "project-card__arrow",
            text: "→",
            attributes: { "aria-hidden": "true" }
        })
    );
    link.append(icon, panel);
    card.append(link);
    return card;
}

export async function render({ language, target }) {
    const registry = await loadJson("data/projects.json");
    const projects = [...registry.projects].sort((a, b) => a.order - b.order);
    const titles = await Promise.all(projects.map((project) => getProjectTitle(project, language)));
    const page = createElement("div", { className: "collection-page projects-page" });
    const list = createElement("div", { className: "project-list" });

    projects.forEach((project, index) => {
        list.append(createProjectCard(project, titles[index], language));
    });
    page.append(list);
    setPageTitle(language === "es" ? "Proyectos" : "Projects");
    target.replaceChildren(page);
}
