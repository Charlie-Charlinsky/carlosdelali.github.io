import { loadJson, loadSemanticFragment } from "../core/loaders.js";
import { createElement, setPageTitle } from "../core/dom.js";
import { getOrderedGameStudios } from "../core/game-order.js";
import { applyPublicationPolicy } from "../core/publication.js";

export async function render({ language, target }) {
    const [fragment, gamesRegistry, ludography] = await Promise.all([
        loadSemanticFragment(`content/cv/${language}.html`),
        loadJson("data/games.json"),
        loadJson("data/ludography.json")
    ]);
    const article = fragment.querySelector("article");
    article.classList.add("semantic-content", "cv-content");
    applyPublicationPolicy(article);
    const ludographySection = article.querySelector("#ludography");
    const gameMap = new Map(gamesRegistry.games.map((game) => [game.id, game]));
    const catalogue = createElement("div", { className: "ludography" });
    const orderedStudios = getOrderedGameStudios(ludography);

    orderedStudios.forEach((studio) => {
        const group = createElement("section", { className: "ludography-group" });
        group.append(createElement("h3", { text: studio.name }));
        const list = createElement("ol", { className: "ludography-list" });
        studio.games.forEach((gameId) => {
            const game = gameMap.get(gameId);
            if (!game) return;
            const item = createElement("li", { text: `${game.title} - ${game.year ?? "?"}` });
            list.append(item);
        });
        group.append(list);
        catalogue.append(group);
    });
    ludographySection.append(catalogue);
    setPageTitle("CV");
    target.replaceChildren(article);
}
