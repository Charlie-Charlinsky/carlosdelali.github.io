import { loadJson, loadSemanticFragment } from "../core/loaders.js";
import { createElement, setPageTitle } from "../core/dom.js";
import { createBackLink, createMediaImage } from "../core/components.js";
import { resolveRoute } from "../core/paths.js";

function createGallery(game, language) {
    const galleryPaths = game.assets.gallery.slice(0, 6);
    const region = createElement("section", {
        className: "media-gallery",
        attributes: { "aria-label": language === "es" ? "Galería" : "Gallery" }
    });
    const stage = createElement("figure", { className: "media-gallery__stage" });
    const stageImage = createMediaImage(galleryPaths[0], `${game.title} — 1`, "media-gallery__image");
    stageImage.loading = "eager";
    stage.append(stageImage);
    const controls = createElement("div", { className: "media-gallery__controls" });
    galleryPaths.forEach((path, index) => {
        const button = createElement("button", {
            className: "media-gallery__thumb",
            attributes: {
                type: "button",
                "aria-label": `${language === "es" ? "Ver imagen" : "View image"} ${index + 1}`,
                "aria-pressed": index === 0 ? "true" : "false"
            }
        });
        button.append(createMediaImage(path, "", "media-gallery__thumbnail"));
        button.addEventListener("click", () => {
            stageImage.src = button.querySelector("img").src;
            stageImage.alt = `${game.title} — ${index + 1}`;
            controls.querySelectorAll("button").forEach((item) => item.setAttribute("aria-pressed", String(item === button)));
        });
        controls.append(button);
    });
    region.append(stage, controls);
    return region;
}

function renderNotFound(target, language) {
    const section = createElement("section", { className: "not-found" });
    section.append(
        createElement("p", { className: "eyebrow", text: "404 / GAME" }),
        createElement("h1", { text: language === "es" ? "Juego no encontrado" : "Game not found" }),
        createBackLink(resolveRoute(language, "games"), language === "es" ? "Volver a Juegos" : "Back to Games")
    );
    target.replaceChildren(section);
}

export async function render({ language, target }) {
    const registry = await loadJson("data/games.json");
    const id = new URLSearchParams(window.location.search).get("id");
    const game = registry.games.find((item) => item.id === id && item.published);
    if (!game) {
        setPageTitle(language === "es" ? "Juego no encontrado" : "Game not found");
        renderNotFound(target, language);
        return;
    }

    const fragment = await loadSemanticFragment(game.content[language]);
    const article = fragment.querySelector("article");
    article.classList.add("semantic-content", "game-content");
    const page = createElement("div", { className: "detail-page game-detail" });
    const hero = createElement("header", { className: "detail-hero" });
    const heroCopy = createElement("div", { className: "detail-hero__copy" });
    heroCopy.append(
        createBackLink(resolveRoute(language, "games"), language === "es" ? "Juegos" : "Games"),
        createElement("p", { className: "eyebrow", text: game.studio }),
        createElement("h1", { text: game.title })
    );
    const cover = createElement("figure", { className: "detail-hero__cover" });
    cover.append(createMediaImage(game.assets.cover, game.title, "detail-hero__image"));
    hero.append(heroCopy, cover);

    const body = createElement("div", { className: "game-detail__body" });
    body.append(createGallery(game, language), article);
    page.append(hero, body);
    setPageTitle(game.title);
    target.replaceChildren(page);
}
