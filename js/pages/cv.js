import { loadJson, loadSemanticFragment } from "../core/loaders.js";
import { createElement, setPageTitle } from "../core/dom.js";
import { detailUrl } from "../core/routes.js";

const LUDOGRAPHY_STUDIO_ORDER = new Map([
    ["ea-sports", 0],
    ["tws-inventors-of-play", 1],
    ["genera-games", 2]
]);

export async function render({ language, target }) {
    const [fragment, gamesRegistry, ludography] = await Promise.all([
        loadSemanticFragment(`content/cv/${language}.html`),
        loadJson("data/games.json"),
        loadJson("data/ludography.json")
    ]);
    const article = fragment.querySelector("article");
    article.classList.add("semantic-content", "cv-content");
    const ludographySection = article.querySelector("#ludography");
    const gameMap = new Map(gamesRegistry.games.map((game) => [game.id, game]));
    const catalogue = createElement("div", { className: "ludography" });
    const orderedStudios = [...ludography.studios].sort((first, second) => {
        const firstOrder = LUDOGRAPHY_STUDIO_ORDER.get(first.id) ?? Number.MAX_SAFE_INTEGER;
        const secondOrder = LUDOGRAPHY_STUDIO_ORDER.get(second.id) ?? Number.MAX_SAFE_INTEGER;
        return firstOrder - secondOrder;
    });

    orderedStudios.forEach((studio) => {
        const group = createElement("section", { className: "ludography-group" });
        group.append(createElement("h3", { text: studio.name }));
        const list = createElement("ol", { className: "ludography-list" });
        studio.games.forEach((gameId) => {
            const game = gameMap.get(gameId);
            if (!game) return;
            const item = createElement("li");
            item.append(createElement("a", {
                text: game.title,
                attributes: { href: detailUrl(language, "games", game.id) }
            }));
            list.append(item);
        });
        group.append(list);
        catalogue.append(group);
    });
    ludographySection.append(catalogue);
    setPageTitle("CV");
    target.replaceChildren(article);
}
