import { loadJson, loadSemanticFragment } from "../core/loaders.js";
import { createElement, padIndex, setPageTitle } from "../core/dom.js";
import { createMediaImage, createPageHeader, localizedValue } from "../core/components.js";
import { detailUrl } from "../core/routes.js";

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

export async function render({ language, target }) {
    const registry = await loadJson("data/projects.json");
    const projects = [...registry.projects].sort((a, b) => a.order - b.order);
    const titles = await Promise.all(projects.map((project) => getProjectTitle(project, language)));
    const page = createElement("div", { className: "collection-page projects-page" });
    page.append(createPageHeader(
        "I+D+I / R&D",
        language === "es" ? "Proyectos" : "Projects",
        language === "es" ? "Investigación, diseño y prototipado." : "Research, design and prototyping."
    ));
    const list = createElement("div", { className: "project-list" });

    projects.forEach((project, index) => {
        const card = createElement("article", { className: "project-card" });
        const link = createElement("a", {
            className: "project-card__link",
            attributes: { href: detailUrl(language, "projects", project.id) }
        });
        const media = createElement("div", { className: "project-card__media" });
        if (project.assets.cover) {
            media.append(createMediaImage(project.assets.cover, titles[index], "project-card__image"));
        } else {
            media.append(createElement("span", { className: "project-card__number", text: padIndex(index) }));
        }
        const copy = createElement("div", { className: "project-card__copy" });
        copy.append(
            createElement("p", { className: "eyebrow", text: `${language === "es" ? "PROYECTO" : "PROJECT"} ${padIndex(index)}` }),
            createElement("h2", { text: titles[index] }),
            createElement("span", { className: "text-command", text: language === "es" ? "ABRIR PROYECTO →" : "OPEN PROJECT →" })
        );
        link.append(media, copy);
        card.append(link);
        list.append(card);
    });
    page.append(list);
    setPageTitle(language === "es" ? "Proyectos" : "Projects");
    target.replaceChildren(page);
}
