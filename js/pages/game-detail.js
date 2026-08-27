import { loadJson, loadSemanticFragment } from "../core/loaders.js";
import { createElement, setPageTitle } from "../core/dom.js";
import { createBackLink, createMediaImage } from "../core/components.js";
import { createMediaGallery } from "../core/media-gallery.js";
import { resolveRoute } from "../core/paths.js";

const METADATA_LABELS = {
    en: { year: "Year", company: "Company", platform: "Platform" },
    es: { year: "Año", company: "Compañía", platform: "Plataforma" }
};

function appendMetadataRow(metadata, label, items) {
    const row = createElement("div", { className: "game-detail__meta-row" });
    const value = createElement("dd", { className: "game-detail__meta-value" });
    items.forEach((item) => value.append(item instanceof Node ? item : createElement("span", { text: item })));
    row.append(createElement("dt", { text: label }), value);
    metadata.append(row);
}

function createGameMetadata(game, language) {
    const labels = METADATA_LABELS[language];
    const metadata = createElement("dl", { className: "game-detail__meta" });

    appendMetadataRow(metadata, labels.year, ["?"]);
    appendMetadataRow(metadata, labels.company, [game.studio || "?"]);
    appendMetadataRow(metadata, labels.platform, ["?"]);
    return metadata;
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
        createElement("h1", { text: game.title }),
        createGameMetadata(game, language),
        createBackLink(resolveRoute(language, "games"), language === "es" ? "Juegos" : "Games")
    );
    const cover = createElement("figure", { className: "detail-hero__cover" });
    cover.append(createMediaImage(game.assets.cover, game.title, "detail-hero__image"));
    hero.append(cover, heroCopy);

    const body = createElement("div", { className: "game-detail__body" });
    body.append(createMediaGallery(game.media, { language, title: game.title, context: "game" }), article);
    page.append(hero, body);
    setPageTitle(game.title);
    target.replaceChildren(page);
}
