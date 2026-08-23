import { loadJson } from "../core/loaders.js";
import { createElement, setPageTitle } from "../core/dom.js";
import { createMediaImage } from "../core/components.js";
import { detailUrl } from "../core/routes.js";

const GAMES_STUDIO_ORDER = new Map([
    ["ea-sports", 0],
    ["tws-inventors-of-play", 1],
    ["genera-games", 2]
]);

function renderGameCard(game, language) {
    const article = createElement("article", { className: "game-card" });
    const link = createElement("a", {
        className: "game-card__link",
        attributes: { href: detailUrl(language, "games", game.id) }
    });
    const figure = createElement("figure", { className: "game-card__media" });
    figure.append(createMediaImage(game.assets.cover, game.title, "game-card__cover"));
    const title = createElement("h3", { text: game.title });
    link.append(figure, title);
    article.append(link);
    return article;
}

export async function render({ language, target }) {
    const [registry, ludography] = await Promise.all([
        loadJson("data/games.json"),
        loadJson("data/ludography.json")
    ]);
    const gameMap = new Map(registry.games.filter((game) => game.published).map((game) => [game.id, game]));
    const page = createElement("div", { className: "collection-page games-page" });
    const orderedStudios = [...ludography.studios].sort((first, second) => {
        const firstOrder = GAMES_STUDIO_ORDER.get(first.id) ?? Number.MAX_SAFE_INTEGER;
        const secondOrder = GAMES_STUDIO_ORDER.get(second.id) ?? Number.MAX_SAFE_INTEGER;
        return firstOrder - secondOrder;
    });

    orderedStudios.forEach((studio) => {
        const section = createElement("section", { className: "studio-section" });
        const heading = createElement("header", { className: "section-heading" });
        const count = studio.games.filter((id) => gameMap.has(id)).length;
        heading.append(
            createElement("h2", { text: studio.name }),
            createElement("span", { text: String(count).padStart(2, "0") })
        );
        const grid = createElement("div", { className: "games-grid" });
        studio.games.forEach((id) => {
            const game = gameMap.get(id);
            if (game) grid.append(renderGameCard(game, language));
        });
        section.append(heading, grid);
        page.append(section);
    });

    setPageTitle(language === "es" ? "Juegos" : "Games");
    target.replaceChildren(page);
}
