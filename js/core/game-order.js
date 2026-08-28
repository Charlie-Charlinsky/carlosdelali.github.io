const GAMES_STUDIO_ORDER = new Map([
    ["ea-sports", 0],
    ["tws-inventors-of-play", 1],
    ["genera-games", 2]
]);

export function getOrderedGameStudios(ludography) {
    return [...ludography.studios].sort((first, second) => {
        const firstOrder = GAMES_STUDIO_ORDER.get(first.id) ?? Number.MAX_SAFE_INTEGER;
        const secondOrder = GAMES_STUDIO_ORDER.get(second.id) ?? Number.MAX_SAFE_INTEGER;
        return firstOrder - secondOrder;
    });
}

export function getOrderedPublishedGames(registry, ludography) {
    const gamesById = new Map(
        registry.games.filter((game) => game.published).map((game) => [game.id, game])
    );

    return getOrderedGameStudios(ludography)
        .flatMap((studio) => studio.games.map((id) => gamesById.get(id)).filter(Boolean));
}
