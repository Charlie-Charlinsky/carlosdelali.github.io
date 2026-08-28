import { loadJson, loadSemanticFragment } from "../core/loaders.js";
import { createElement, setPageTitle } from "../core/dom.js";
import { createBackLink, createMediaImage } from "../core/components.js";
import { getOrderedPublishedGames } from "../core/game-order.js";
import { createMediaGallery } from "../core/media-gallery.js";
import { resolveAsset, resolveRoute, resolveSiteUrl } from "../core/paths.js";
import { detailUrl } from "../core/routes.js";

const METADATA_LABELS = {
    en: {
        year: "Year",
        company: "Company",
        platform: "Platform",
        engine: "Development Engine",
        access: "Access"
    },
    es: {
        year: "Año",
        company: "Compañía",
        platform: "Plataforma",
        engine: "Motor de desarrollo",
        access: "Acceso"
    }
};

function appendMetadataRow(metadata, label, items) {
    const row = createElement("div", { className: "game-detail__meta-row" });
    const value = createElement("dd", { className: "game-detail__meta-value" });
    items.forEach((item) => value.append(item instanceof Node ? item : createElement("span", { text: item })));
    row.append(createElement("dt", { text: label }), value);
    metadata.append(row);
}

function metadataValue(value) {
    if (Array.isArray(value)) return value.length ? value.join(", ") : "?";
    return value === undefined || value === null || value === "" ? "?" : String(value);
}

function createGameMetadata(game, language) {
    const labels = METADATA_LABELS[language];
    const metadata = createElement("dl", { className: "game-detail__meta" });
    const access = game.accessUrl
        ? createElement("a", {
            text: game.accessUrl,
            attributes: {
                href: resolveSiteUrl(game.accessUrl),
                target: "_blank",
                rel: "noopener noreferrer"
            }
        })
        : "?";

    appendMetadataRow(metadata, labels.year, [metadataValue(game.year)]);
    appendMetadataRow(metadata, labels.company, [metadataValue(game.studio)]);
    appendMetadataRow(metadata, labels.platform, [metadataValue(game.platform)]);
    appendMetadataRow(metadata, labels.engine, [metadataValue(game.engineName)]);
    appendMetadataRow(metadata, labels.access, [access]);
    return metadata;
}

async function createEngineLogo(game) {
    if (!game.engineId) return null;

    const path = `assets/engines/${game.engineId}.png`;
    const image = createElement("img", {
        className: "game-detail__engine-image",
        attributes: {
            alt: `${game.engineName || game.engineId} logo`,
            decoding: "async"
        }
    });
    const loaded = await new Promise((resolve) => {
        image.addEventListener("load", () => resolve(true), { once: true });
        image.addEventListener("error", () => resolve(false), { once: true });
        image.src = resolveAsset(path);
    });

    if (!loaded) {
        console.warn(`[Game Detail] Missing engine icon: ${path}`);
        return null;
    }

    const figure = createElement("figure", { className: "game-detail__engine-logo" });
    figure.append(image);
    return figure;
}

function createGameNavigation(games, currentIndex, language) {
    const previous = games[(currentIndex - 1 + games.length) % games.length];
    const next = games[(currentIndex + 1) % games.length];
    const navigation = createElement("nav", {
        className: "game-detail__navigation",
        attributes: { "aria-label": language === "es" ? "Navegación de juegos" : "Game navigation" }
    });
    navigation.append(
        createElement("a", {
            className: "back-link game-detail__navigation-link",
            text: language === "es" ? "Anterior" : "Previous",
            attributes: { href: detailUrl(language, "games", previous.id) }
        }),
        createElement("a", {
            className: "back-link game-detail__navigation-link",
            text: language === "es" ? "Siguiente" : "Next",
            attributes: { href: detailUrl(language, "games", next.id) }
        })
    );
    return navigation;
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
    const [registry, ludography] = await Promise.all([
        loadJson("data/games.json"),
        loadJson("data/ludography.json")
    ]);
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
    const orderedGames = getOrderedPublishedGames(registry, ludography);
    const currentIndex = orderedGames.findIndex((item) => item.id === game.id);
    const engineLogo = await createEngineLogo(game);
    heroCopy.append(
        createElement("h1", { text: game.title }),
        createGameMetadata(game, language)
    );
    if (engineLogo) heroCopy.append(engineLogo);
    if (currentIndex >= 0) heroCopy.append(createGameNavigation(orderedGames, currentIndex, language));
    const cover = createElement("figure", { className: "detail-hero__cover" });
    cover.append(createMediaImage(game.assets.cover, game.title, "detail-hero__image"));
    hero.append(cover, heroCopy);

    const body = createElement("div", { className: "game-detail__body" });
    body.append(createMediaGallery(game.media, { language, title: game.title, context: "game" }), article);
    page.append(hero, body);
    setPageTitle(game.title);
    target.replaceChildren(page);
}
