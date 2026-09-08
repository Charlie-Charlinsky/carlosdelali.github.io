export const AUTHORITATIVE_GAME_ORDER = Object.freeze([
    Object.freeze({
        studioId: "ea-sports",
        gameIds: Object.freeze([
            "madden-nfl-27",
            "madden-nfl-26",
            "madden-nfl-25",
            "ea-sports-pga-tour"
        ])
    }),
    Object.freeze({
        studioId: "tws-inventors-of-play",
        gameIds: Object.freeze([
            "gods-of-luxor",
            "teen-patti",
            "wheel-of-fortune",
            "mystic-elements",
            "gold-rush-gus",
            "777-deluxe",
            "cyberpunk-city",
            "a-night-with-cleo",
            "cricket-legends",
            "zombie-soccer",
            "andar-bahar"
        ])
    }),
    Object.freeze({
        studioId: "genera-games",
        gameIds: Object.freeze([
            "xtreme-racing-2",
            "skull-towers",
            "the-little-prince",
            "runbot"
        ])
    })
]);

const ORDER_BY_STUDIO = new Map(
    AUTHORITATIVE_GAME_ORDER.map((entry, index) => [entry.studioId, { ...entry, index }])
);

export function getOrderedGameStudios(ludography) {
    return [...ludography.studios]
        .sort((first, second) => {
            const firstOrder = ORDER_BY_STUDIO.get(first.id)?.index ?? Number.MAX_SAFE_INTEGER;
            const secondOrder = ORDER_BY_STUDIO.get(second.id)?.index ?? Number.MAX_SAFE_INTEGER;
            return firstOrder - secondOrder;
        })
        .map((studio) => {
            const canonical = ORDER_BY_STUDIO.get(studio.id);
            if (!canonical) return { ...studio, games: [...studio.games] };
            const members = new Set(studio.games);
            const ordered = canonical.gameIds.filter((id) => members.has(id));
            const unlisted = studio.games.filter((id) => !canonical.gameIds.includes(id));
            return { ...studio, games: [...ordered, ...unlisted] };
        });
}

export function getOrderedPublishedGames(registry, ludography) {
    const gamesById = new Map(
        registry.games.filter((game) => game.published).map((game) => [game.id, game])
    );

    return getOrderedGameStudios(ludography)
        .flatMap((studio) => studio.games.map((id) => gamesById.get(id)).filter(Boolean));
}
