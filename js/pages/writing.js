import { loadJson, loadSemanticFragment } from "../core/loaders.js";
import { createElement, padIndex, setPageTitle } from "../core/dom.js";
import { localizedValue } from "../core/components.js";
import { resolveRoute } from "../core/paths.js";

function storyUrl(language, id) {
    return resolveRoute(language, "writing", { query: { story: id } });
}

export async function render({ language, target }) {
    const registry = await loadJson("data/stories.json");
    const stories = [...registry.stories].sort((a, b) => a.order - b.order);
    const requestedId = new URLSearchParams(window.location.search).get("story");
    let current = stories.find((story) => story.id === requestedId) || stories[0];

    const page = createElement("div", { className: "writing-page" });
    const layout = createElement("div", { className: "reader-layout" });
    const sidebar = createElement("aside", { className: "story-navigation" });
    const list = createElement("nav", { attributes: { "aria-label": language === "es" ? "Relatos" : "Stories" } });
    const reader = createElement("section", { className: "story-reader", attributes: { "aria-live": "polite" } });

    stories.forEach((story, index) => {
        const link = createElement("a", {
            className: "story-link",
            attributes: { href: storyUrl(language, story.id), "data-story-id": story.id }
        });
        link.append(
            createElement("span", { text: padIndex(index) }),
            createElement("strong", { text: localizedValue(story.title, language, story.id) })
        );
        list.append(link);
    });
    sidebar.append(list);
    layout.append(sidebar, reader);
    page.append(layout);
    target.replaceChildren(page);

    async function selectStory(story, pushState = false) {
        current = story;
        list.querySelectorAll("a").forEach((link) => {
            const active = link.dataset.storyId === story.id;
            link.classList.toggle("is-active", active);
            if (active) link.setAttribute("aria-current", "true");
            else link.removeAttribute("aria-current");
        });
        reader.replaceChildren(createElement("p", { className: "system-message", text: language === "es" ? "Cargando relato..." : "Loading story..." }));
        const fragment = await loadSemanticFragment(story.content[language]);
        const article = fragment.querySelector("article");
        article.classList.add("semantic-content", "story-content");
        const viewport = createElement("div", { className: "reader-viewport", attributes: { tabindex: "0" } });
        viewport.append(article);
        reader.replaceChildren(viewport);
        if (pushState) window.history.pushState({ story: story.id }, "", storyUrl(language, story.id));
        setPageTitle(localizedValue(story.title, language, story.id));
    }

    list.addEventListener("click", (event) => {
        const link = event.target.closest("a[data-story-id]");
        if (!link) return;
        event.preventDefault();
        const story = stories.find((item) => item.id === link.dataset.storyId);
        if (story && story !== current) selectStory(story, true);
    });
    window.addEventListener("popstate", () => {
        const id = new URLSearchParams(window.location.search).get("story");
        const story = stories.find((item) => item.id === id) || stories[0];
        selectStory(story, false);
    });
    await selectStory(current, false);
}
