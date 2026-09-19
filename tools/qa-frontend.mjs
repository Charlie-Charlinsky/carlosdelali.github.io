import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function relative(filePath) {
    return path.relative(root, filePath).replaceAll("\\", "/");
}

function fail(message) {
    failures.push(message);
}

function read(filePath) {
    return fs.readFileSync(path.join(root, filePath), "utf8");
}

function readJson(filePath) {
    try {
        return JSON.parse(read(filePath));
    } catch (error) {
        fail(`${filePath}: JSON inválido (${error.message})`);
        return {};
    }
}

function assertFile(filePath, label = filePath) {
    if (!fs.existsSync(path.join(root, filePath))) fail(`${label}: archivo no encontrado (${filePath})`);
}

function walk(directory, extensions) {
    const absolute = path.join(root, directory);
    if (!fs.existsSync(absolute)) return [];
    return fs.readdirSync(absolute, { withFileTypes: true }).flatMap((entry) => {
        const target = path.join(absolute, entry.name);
        if (entry.isDirectory()) return walk(relative(target), extensions);
        return extensions.includes(path.extname(entry.name)) ? [target] : [];
    });
}

const canonicalRoutes = [
    "index.html", "en/index.html", "es/index.html",
    "en/about/index.html", "es/about/index.html",
    "en/cv/index.html", "es/cv/index.html",
    "en/contact/index.html", "es/contact/index.html",
    "en/games/index.html", "es/games/index.html",
    "en/games/detail/index.html", "es/games/detail/index.html",
    "en/projects/index.html", "es/projects/index.html",
    "en/projects/detail/index.html", "es/projects/detail/index.html",
    "en/writing/index.html", "es/writing/index.html",
    "en/oniric-journal/index.html", "es/oniric-journal/index.html",
    "en/oniric-journal/detail/index.html", "es/oniric-journal/detail/index.html",
    "en/dream-journal/index.html", "es/dream-journal/index.html"
];
canonicalRoutes.forEach((route) => assertFile(route, "Ruta"));

const gamesRegistry = readJson("data/games.json");
const ludography = readJson("data/ludography.json");
const projectsRegistry = readJson("data/projects.json");
const storiesRegistry = readJson("data/stories.json");
const journalRegistry = readJson("data/oniric-journal.json");

const games = gamesRegistry.games ?? [];
if (games.length !== 19) fail(`Games: se esperaban 19 y hay ${games.length}`);
if (new Set(games.map((game) => game.id)).size !== games.length) fail("Games: IDs duplicados");
const gameMap = new Map(games.map((game) => [game.id, game]));
const gameDetailSource = read("js/pages/game-detail.js");
const gameOrderSource = read("js/core/game-order.js");
const gamesPageSource = read("js/pages/games.js");
const cvPageSource = read("js/pages/cv.js");
const aboutPageSource = read("js/pages/about.js");
const appSource = read("js/app.js");
const pathsSource = read("js/core/paths.js");
const routesSource = read("js/core/routes.js");
const rootSource = read("js/root.js");
const publicationSource = read("js/core/publication.js");
const shellSource = read("js/core/shell.js");
const languageScrollSource = read("js/core/language-scroll.js");
const mediaGallerySource = read("js/core/media-gallery.js");
const frontendCss = read("css/frontend.css");
const obsoleteEngineKey = ["engine", "Id"].join("");
const obsoleteEnginePresentationTokens = [
    ["assets", "engines"].join("/"),
    ["engine", "logo"].join("-"),
    ["engine", "image"].join("-"),
    ["engine", "icon"].join("-"),
    ["engine", "Logo"].join(""),
    ["engine", "Image"].join(""),
    ["engine", "Icon"].join(""),
    ["create", "Engine", "Logo"].join("")
];

if (gameMap.get("ea-sports-pga-tour")?.engineName !== "Frostbite") {
    fail("Game Detail: PGA debe conservar el texto de motor Frostbite");
}
if (gameMap.get("skull-towers")?.engineName !== "Unity") {
    fail("Game Detail: Skull Towers debe conservar el texto de motor Unity");
}
if (!gameDetailSource.includes("metadataValue(game.engineName)")) {
    fail("Game Detail: el motor textual no se renderiza desde engineName");
}
if (!gameDetailSource.includes('return value === undefined || value === null || value === "" ? "?" : String(value);')) {
    fail("Game Detail: el fallback textual de metadatos desconocidos no es válido");
}
if (games.some((game) => Object.hasOwn(game, obsoleteEngineKey))) {
    fail("Games: el identificador visual de motor obsoleto sigue en el registro");
}
obsoleteEnginePresentationTokens.forEach((token) => {
    if (gameDetailSource.includes(token)) fail(`Game Detail: referencia visual de motor obsoleta (${token})`);
});
if (!gameDetailSource.includes("createGameNavigation(orderedGames, currentIndex, language)")) {
    fail("Game Detail: navegación Previous/Next no resuelta");
}
if (!gameDetailSource.includes("createMediaGallery(media")) {
    fail("Game Detail: galería de medios no resuelta");
}
const metadataOrderTokens = [
    "appendMetadataRow(metadata, labels.year",
    "appendMetadataRow(metadata, labels.company",
    "appendMetadataRow(metadata, labels.platform",
    "appendMetadataRow(metadata, labels.engine",
    "appendMetadataRow(metadata, labels.access"
];
const metadataOrderIndexes = metadataOrderTokens.map((token) => gameDetailSource.indexOf(token));
if (metadataOrderIndexes.some((index) => index < 0)
    || metadataOrderIndexes.some((index, position) => position > 0 && index <= metadataOrderIndexes[position - 1])) {
    fail("Game Detail: orden Year/Company/Platform/Engine/Access no resuelto");
}
if (!frontendCss.includes("--game-detail-h2-size: 1.75rem;")) {
    fail("Game Detail: H2 debe conservar el baseline de 28px");
}
if (!frontendCss.includes("--game-detail-title-step: 0.25rem;")) {
    fail("Game Detail: la diferencia tipográfica H1/H2 debe ser exactamente 4px");
}
if (!frontendCss.includes("--game-detail-heading-step: 0.375rem;")) {
    fail("Game Detail: la diferencia tipográfica H2/H3 debe ser exactamente 6px");
}
if (!frontendCss.includes("--game-detail-h1-size: calc(var(--game-detail-h2-size) + var(--game-detail-title-step));")) {
    fail("Game Detail: H1 no deriva su tamaño del H2");
}
if (!frontendCss.includes("--game-detail-h3-size: calc(var(--game-detail-h2-size) - var(--game-detail-heading-step));")) {
    fail("Game Detail: H3 no deriva su tamaño del H2");
}
if (!/\.game-detail \.detail-hero h1\s*\{[^}]*font-size:\s*var\(--game-detail-h1-size\)/s.test(frontendCss)
    || !/\.game-detail \.game-content h2\s*\{[^}]*font-size:\s*var\(--game-detail-h2-size\)/s.test(frontendCss)
    || !/\.game-detail \.game-content h3\s*\{[^}]*font-size:\s*var\(--game-detail-h3-size\)/s.test(frontendCss)) {
    fail("Game Detail: selectores semánticos H1/H2/H3 no resueltos");
}

games.forEach((game) => {
    if (game.detailStatus !== "content-ready") fail(`${game.id}: contenido no preparado`);
    if (game.assetsStatus !== "ready") fail(`${game.id}: assets no preparados`);
    assertFile(game.content.en, `${game.id}: contenido EN`);
    assertFile(game.content.es, `${game.id}: contenido ES`);
    assertFile(game.assets.cover, `${game.id}: cover`);
    if (!game.assets.gallery?.length || game.assets.gallery.length > 12) {
        fail(`${game.id}: galería fuera del rango 1-12`);
    }
    game.assets.gallery?.forEach((asset) => assertFile(asset, `${game.id}: galería`));
    (game.media ?? [])
        .filter((item) => item.type !== "youtube")
        .forEach((item) => assertFile(item.src, `${game.id}: medio local`));
});

const mediaGalleryModule = await import(pathToFileURL(path.join(root, "js/core/media-gallery.js")).href);
if (JSON.stringify(mediaGalleryModule.MEDIA_LIMITS) !== JSON.stringify({ images: 12, videos: 4, total: 16 })) {
    fail("Media Gallery: el contrato debe ser 12 imagenes, 4 videos y 16 elementos totales");
}
const priorityFixture = mediaGalleryModule.composeGameMedia(
    ["AAAAAAAAAAA", "BBBBBBBBBBB", "CCCCCCCCCCC"].map((videoId) => ({ provider: "youtube", videoId })),
    [
        { type: "image", src: "image-1.jpg" },
        { type: "video", src: "local-1.mp4" },
        { type: "video", src: "local-2.mp4" },
        ...Array.from({ length: 13 }, (_, index) => ({ type: "image", src: `image-${index + 2}.jpg` }))
    ]
);
if (priorityFixture.length !== 16
    || priorityFixture.slice(0, 3).some((item) => item.type !== "youtube")
    || priorityFixture[3]?.type !== "video"
    || priorityFixture.slice(4).some((item) => item.type !== "image")) {
    fail("Media Gallery: prioridad YouTube > video local > imagen no resuelta");
}
if (priorityFixture.filter((item) => item.type !== "image").length !== 4
    || priorityFixture.filter((item) => item.type === "image").length !== 12) {
    fail("Media Gallery: limites combinados 4/12/16 no resueltos");
}
const noYoutubeFixture = mediaGalleryModule.composeGameMedia([], [
    ...Array.from({ length: 5 }, (_, index) => ({ type: "video", src: `local-${index + 1}.mp4` })),
    { type: "image", src: "image-1.jpg" }
]);
if (noYoutubeFixture.filter((item) => item.type === "video").length !== 4
    || noYoutubeFixture[0]?.src !== "local-1.mp4"
    || noYoutubeFixture[4]?.src !== "image-1.jpg") {
    fail("Media Gallery: juegos sin YouTube deben conservar el comportamiento local");
}
const youtubeOnlyFixture = mediaGalleryModule.composeGameMedia(
    ["AAAAAAAAAAA", "BBBBBBBBBBB", "CCCCCCCCCCC", "DDDDDDDDDDD"].map((videoId) => ({ provider: "youtube", videoId })),
    [{ type: "video", src: "excluded-local.mp4" }, { type: "image", src: "image-1.jpg" }]
);
if (youtubeOnlyFixture.slice(0, 4).some((item) => item.type !== "youtube")
    || youtubeOnlyFixture.some((item) => item.src === "excluded-local.mp4")) {
    fail("Media Gallery: cuatro YouTube deben consumir todos los slots de video");
}
if (mediaGalleryModule.youtubeEmbedUrl("AAAAAAAAAAA") !== "https://www.youtube-nocookie.com/embed/AAAAAAAAAAA") {
    fail("Media Gallery: URL youtube-nocookie no resuelta");
}
const expectedYoutubeGameplays = new Map([
    ["andar-bahar", "aMd8EAMDYRk"],
    ["teen-patti", "mAL-eL7A8oc"],
    ["wheel-of-fortune", "LjQdas4Nq3A"]
]);
expectedYoutubeGameplays.forEach((videoId, gameId) => {
    const game = gameMap.get(gameId);
    const localVideos = (game?.media ?? []).filter((item) => item.type === "video");
    const composed = mediaGalleryModule.composeGameMedia(game?.youtubeVideos, game?.media);
    if ((game?.youtubeVideos ?? []).length !== 1
        || game.youtubeVideos[0]?.videoId !== videoId
        || localVideos.length !== 0
        || composed[0]?.type !== "youtube"
        || composed[0]?.videoId !== videoId) {
        fail(`${gameId}: el gameplay YouTube debe ser el primer medio sin duplicados`);
    }
});
games.forEach((game) => {
    const youtubeVideos = game.youtubeVideos ?? [];
    const ids = youtubeVideos.map((item) => item.videoId);
    if (youtubeVideos.some((item) => item.provider !== "youtube" || !/^[A-Za-z0-9_-]{11}$/.test(item.videoId ?? ""))) {
        fail(`${game.id}: metadatos YouTube invalidos`);
    }
    if (new Set(ids).size !== ids.length) fail(`${game.id}: IDs YouTube duplicados`);
    const composed = mediaGalleryModule.composeGameMedia(youtubeVideos, game.media ?? []);
    const videoCount = composed.filter((item) => item.type !== "image").length;
    const imageCount = composed.filter((item) => item.type === "image").length;
    if (videoCount > 4 || imageCount > 12 || composed.length > 16) {
        fail(`${game.id}: medios fuera de los limites 4/12/16`);
    }
    const firstImage = composed.findIndex((item) => item.type === "image");
    if (firstImage >= 0 && composed.slice(firstImage).some((item) => item.type !== "image")) {
        fail(`${game.id}: las imagenes deben aparecer despues de todos los videos`);
    }
});
if (!mediaGallerySource.includes('youtube.src = "about:blank"')
    || !mediaGallerySource.includes("viewport.replaceChildren(createPrimaryMedia")) {
    fail("Media Gallery: el iframe YouTube inactivo no se destruye de forma determinista");
}
if (!/\.media-viewer__image,\s*\.media-viewer__video\s*\{[^}]*object-fit:\s*contain;/s.test(frontendCss)
    || !/\.media-viewer__image-button\s*\{[^}]*display:\s*grid;[^}]*min-width:\s*0;[^}]*min-height:\s*0;[^}]*place-items:\s*center;[^}]*overflow:\s*hidden;/s.test(frontendCss)
    || !/\.media-viewer__image-button > \.media-viewer__image\s*\{[^}]*width:\s*auto;[^}]*height:\s*auto;[^}]*max-width:\s*100%;[^}]*max-height:\s*100%;[^}]*object-position:\s*center center;/s.test(frontendCss)) {
    fail("Media Gallery: la imagen principal debe encajar completa dentro de un wrapper centrado");
}
if (!/\.media-viewer__thumbnail-image\s*\{[^}]*object-fit:\s*cover;/s.test(frontendCss)) {
    fail("Media Gallery: el recorte de miniaturas debe permanecer independiente");
}
if (!/\.media-viewer-theater \.media-viewer__stage\s*\{[^}]*aspect-ratio:\s*auto;/s.test(frontendCss)
    || !/\.media-viewer:fullscreen \.media-viewer__stage\s*\{[^}]*height:\s*100%;[^}]*aspect-ratio:\s*auto;/s.test(frontendCss)
    || !frontendCss.includes(".media-viewer__youtube")) {
    fail("Media Gallery: Theater/fullscreen no conservan una etapa estable para imagen y video");
}
if (!mediaGallerySource.includes("https://www.youtube-nocookie.com/embed/")
    || /iframe[^\n]+(?:youtube\.com\/watch|youtu\.be)/.test(mediaGallerySource)) {
    fail("Media Gallery: el iframe debe usar exclusivamente youtube-nocookie embed");
}

(ludography.studios ?? []).forEach((studio) => {
    studio.games.forEach((id) => {
        if (!gameMap.has(id)) fail(`Ludografía: ${id} no resuelve`);
    });
});

const expectedGameOrder = [
    {
        studioId: "ea-sports",
        gameIds: ["madden-nfl-27", "madden-nfl-26", "madden-nfl-25", "ea-sports-pga-tour"]
    },
    {
        studioId: "tws-inventors-of-play",
        gameIds: ["gods-of-luxor", "teen-patti", "wheel-of-fortune", "mystic-elements", "gold-rush-gus", "777-deluxe", "cyberpunk-city", "a-night-with-cleo", "cricket-legends", "zombie-soccer", "andar-bahar"]
    },
    {
        studioId: "genera-games",
        gameIds: ["xtreme-racing-2", "skull-towers", "the-little-prince", "runbot"]
    }
];
const gameOrderModule = await import(pathToFileURL(path.join(root, "js/core/game-order.js")).href);
const declaredGameOrder = gameOrderModule.AUTHORITATIVE_GAME_ORDER.map(({ studioId, gameIds }) => ({
    studioId,
    gameIds: [...gameIds]
}));
if (JSON.stringify(declaredGameOrder) !== JSON.stringify(expectedGameOrder)) {
    fail("Game order: la secuencia autoritativa no coincide");
}
const orderedStudios = gameOrderModule.getOrderedGameStudios(ludography);
const visibleGameOrder = orderedStudios.map((studio) => ({ studioId: studio.id, gameIds: studio.games }));
if (JSON.stringify(visibleGameOrder) !== JSON.stringify(expectedGameOrder)) {
    fail("Game order: Games/CV no resuelven la secuencia compartida");
}
if (!gameOrderSource.includes("AUTHORITATIVE_GAME_ORDER")
    || !gamesPageSource.includes("getOrderedGameStudios(ludography)")
    || !cvPageSource.includes("getOrderedGameStudios(ludography)")) {
    fail("Game order: Games y CV no consumen el helper compartido");
}

const publicationModule = await import(pathToFileURL(path.join(root, "js/core/publication.js")).href);
const expectedSections = [
    { id: 1, key: "ABOUT", route: "about", navOrder: 3, published: true },
    { id: 2, key: "CV", route: "cv", navOrder: 2, published: true },
    { id: 3, key: "GAMES", route: "games", navOrder: 1, published: true },
    { id: 4, key: "PROJECTS", route: "projects", navOrder: 4, published: false },
    { id: 5, key: "WRITING", route: "writing", navOrder: 5, published: false },
    { id: 6, key: "ONIRIC_JOURNAL", route: "oniric-journal", navOrder: 6, published: false },
    { id: 7, key: "CONTACT", route: "contact", navOrder: 7, published: true }
];
const declaredSections = publicationModule.SECTION_REGISTRY.map(({ id, key, route, navOrder, published }) => ({
    id,
    key,
    route,
    navOrder,
    published
}));
if (JSON.stringify(declaredSections) !== JSON.stringify(expectedSections)) {
    fail("Publication: el registro estable 1-7 o su estado no coincide");
}
if (publicationModule.getPublishedSections().length !== 4) {
    fail("Publication: deben existir exactamente cuatro secciones publicadas");
}
if (publicationModule.getPublishedSections().map((section) => section.route).join("|") !== "games|cv|about|contact") {
    fail("Publication: el orden visible debe ser Games, CV, About, Contact");
}
if (publicationModule.getDefaultPublishedSection()?.route !== "games") {
    fail("Publication: la ruta inicial debe ser la primera seccion publicada por navOrder");
}
const futureSections = expectedSections.map((section) => ({
    ...section,
    navOrder: ({ projects: 1, games: 2, cv: 3, about: 4, contact: 5 })[section.route] ?? section.navOrder,
    published: section.route === "projects" ? true : section.published
}));
if (publicationModule.getDefaultPublishedSection(futureSections)?.route !== "projects") {
    fail("Publication: el resolver inicial no responde a una futura seccion publicada con navOrder prioritario");
}
const futureProjectsHidden = futureSections.map((section) => section.route === "projects"
    ? { ...section, published: false }
    : section);
if (publicationModule.getDefaultPublishedSection(futureProjectsHidden)?.route !== "games") {
    fail("Publication: el resolver inicial no omite una primera seccion no publicada");
}
expectedSections.forEach((section) => {
    if (publicationModule.getSectionById(section.id)?.route !== section.route) {
        fail(`Publication: la seccion ${section.id} no resuelve a ${section.route}`);
    }
    if (publicationModule.isPagePublished(section.route) !== section.published) {
        fail(`Publication: el acceso de ${section.route} no coincide con su estado`);
    }
});
[
    ["game-detail", true],
    ["project-detail", false],
    ["oniric-journal-detail", false]
].forEach(([page, published]) => {
    if (publicationModule.isPagePublished(page) !== published) {
        fail(`Publication: la ruta derivada ${page} no hereda el estado de su seccion`);
    }
});
if (!shellSource.includes("getPublishedSections().forEach(({ route })")
    || shellSource.includes("const NAVIGATION")) {
    fail("Publication: la navegacion no deriva exclusivamente del registro compartido");
}
if (!shellSource.includes('if (route === activePage) link.setAttribute("aria-current", "page")')) {
    fail("Publication: el estado activo debe resolverse por ruta y no por indice");
}
if (!shellSource.includes("getEquivalentLanguageUrl(targetLanguage, page)")) {
    fail("Publication: el cambio de idioma debe conservar la ruta actual");
}
if (!appSource.includes("if (!isPagePublished(context.page))")) {
    fail("Publication: el gate de rutas no se ejecuta antes de cargar la pagina");
}
if (!appSource.includes("getDefaultPublishedSection()")
    || !appSource.includes("resolveRoute(context.language, defaultSection.route)")) {
    fail("Publication: el fallback no publicado no consume el resolver inicial compartido");
}
if (!rootSource.includes("getDefaultPublishedSection()")
    || !rootSource.includes("resolveRoute(language, defaultSection.route)")
    || /resolveRoute\(language,\s*["'](?:about|games)["']/.test(rootSource)) {
    fail("Routes: la entrada raiz no deriva del primer elemento publicado por navOrder");
}
if (!routesSource.includes("document.body.dataset.page || defaultSection?.route")
    || routesSource.includes('document.body.dataset.page || "about"')) {
    fail("Routes: el contexto implicito conserva un default de About hardcodeado");
}
if (!shellSource.includes("resolveRoute(language, defaultSection.route)")) {
    fail("Routes: el enlace de identidad no consume el resolver inicial compartido");
}
if (!/about:\s*["']about\/["']/.test(pathsSource)) {
    fail("Routes: About no dispone de una ruta propia tras separar el landing localizado");
}
const enLandingSource = read("en/index.html");
const esLandingSource = read("es/index.html");
const enAboutRouteSource = read("en/about/index.html");
const esAboutRouteSource = read("es/about/index.html");
if (!enLandingSource.includes('data-lang="en"') || !enLandingSource.includes('../js/root.js')
    || enLandingSource.includes('data-page="about"')) {
    fail("Routes: /en/ no funciona como entrada localizada dinamica");
}
if (!esLandingSource.includes('data-lang="es"') || !esLandingSource.includes('../js/root.js')
    || esLandingSource.includes('data-page="about"')) {
    fail("Routes: /es/ no funciona como entrada localizada dinamica");
}
if (!enAboutRouteSource.includes('data-lang="en" data-page="about"')
    || !esAboutRouteSource.includes('data-lang="es" data-page="about"')) {
    fail("Routes: las rutas About explicitas no conservan su contexto semantico");
}

const languageScrollModule = await import(pathToFileURL(path.join(root, "js/core/language-scroll.js")).href);
if (languageScrollModule.clampScrollProgress(-0.5) !== 0
    || languageScrollModule.clampScrollProgress(1.5) !== 1
    || languageScrollModule.clampScrollProgress(0.4) !== 0.4) {
    fail("Language scroll: el progreso no se limita correctamente al intervalo 0..1");
}
if (languageScrollModule.getNormalizedScrollProgress({
    scrollY: 1_000,
    scrollHeight: 3_000,
    viewportHeight: 1_000
}) !== 0.5) {
    fail("Language scroll: el fallback no usa progreso vertical normalizado");
}
const languageScrollNow = 1_000_000;
const validLanguageScrollState = {
    version: languageScrollModule.LANGUAGE_SCROLL_STATE_VERSION,
    timestamp: languageScrollNow,
    sourceLanguage: "en",
    targetLanguage: "es",
    sourceRoute: "cv",
    targetRoute: "cv",
    sourceUrl: "/en/cv/",
    targetUrl: "/es/cv/",
    progress: 0.75,
    anchorId: "education",
    anchorOffset: 200,
    anchorProgress: 0.5,
    viewportReference: 0.35
};
const validLanguageScrollContext = {
    language: "es",
    page: "cv",
    currentUrl: "https://portfolio.test/es/cv/",
    now: languageScrollNow
};
if (!languageScrollModule.isLanguageSwitchScrollStateValid(
    validLanguageScrollState,
    validLanguageScrollContext
)) {
    fail("Language scroll: un estado valido para la ruta traducida se rechaza");
}
if (languageScrollModule.isLanguageSwitchScrollStateValid(validLanguageScrollState, {
    ...validLanguageScrollContext,
    page: "games"
})) {
    fail("Language scroll: un estado pendiente se aplica a una ruta semantica distinta");
}
const gameDetailLanguageScrollState = {
    ...validLanguageScrollState,
    sourceRoute: "game-detail",
    targetRoute: "game-detail",
    sourceUrl: "/en/games/detail/?id=the-little-prince",
    targetUrl: "/es/games/detail/?id=the-little-prince"
};
if (!languageScrollModule.isLanguageSwitchScrollStateValid(gameDetailLanguageScrollState, {
    ...validLanguageScrollContext,
    page: "game-detail",
    currentUrl: "https://portfolio.test/es/games/detail/?id=the-little-prince"
}) || languageScrollModule.isLanguageSwitchScrollStateValid(gameDetailLanguageScrollState, {
    ...validLanguageScrollContext,
    page: "game-detail",
    currentUrl: "https://portfolio.test/es/games/detail/?id=another-game"
})) {
    fail("Language scroll: Game Detail no conserva/verifica la identidad del juego");
}
if (languageScrollModule.isLanguageSwitchScrollStateValid(validLanguageScrollState, {
    ...validLanguageScrollContext,
    now: languageScrollNow + languageScrollModule.LANGUAGE_SCROLL_TTL_MS + 1
})) {
    fail("Language scroll: un estado caducado no se rechaza");
}
const anchoredScrollTop = languageScrollModule.calculateLanguageSwitchScrollTop(validLanguageScrollState, {
    maximumScroll: 4_000,
    viewportHeight: 1_000,
    anchorTop: 2_000,
    anchorHeight: 1_000
});
const fallbackScrollTop = languageScrollModule.calculateLanguageSwitchScrollTop(validLanguageScrollState, {
    maximumScroll: 4_000,
    viewportHeight: 1_000
});
if (anchoredScrollTop !== 2_150 || fallbackScrollTop !== 3_000) {
    fail("Language scroll: el ancla semantica no tiene prioridad sobre el fallback de progreso");
}
if (languageScrollModule.captureLanguageSwitchScrollState({
    sourceLanguage: "en",
    targetLanguage: "en",
    page: "cv",
    targetUrl: "https://portfolio.test/en/cv/"
}) !== false) {
    fail("Language scroll: un selector del idioma actual crea estado de restauracion");
}
const previousWindow = globalThis.window;
const previousDocument = globalThis.document;
const pendingLanguageScrollStorage = new Map();
let restoredLanguageScroll = null;
const sourceAnchor = {
    id: "education",
    dataset: {},
    getBoundingClientRect: () => ({ top: 100, bottom: 1_100, height: 1_000 })
};
const targetAnchor = {
    id: "education",
    dataset: {},
    getBoundingClientRect: () => ({ top: 800, bottom: 2_400, height: 1_600 })
};
globalThis.window = {
    location: { href: "https://portfolio.test/en/cv/" },
    innerHeight: 1_000,
    scrollY: 650,
    scrollX: 0,
    sessionStorage: {
        getItem: (key) => pendingLanguageScrollStorage.get(key) ?? null,
        setItem: (key, value) => pendingLanguageScrollStorage.set(key, value),
        removeItem: (key) => pendingLanguageScrollStorage.delete(key)
    },
    requestAnimationFrame: (callback) => callback(),
    scrollTo: (options) => { restoredLanguageScroll = options; }
};
globalThis.document = {
    documentElement: { scrollHeight: 5_000 },
    body: { scrollHeight: 5_000 },
    fonts: { ready: Promise.resolve() },
    querySelectorAll: () => [sourceAnchor]
};
const capturedLanguageScroll = languageScrollModule.captureLanguageSwitchScrollState({
    sourceLanguage: "en",
    targetLanguage: "es",
    page: "cv",
    targetUrl: "https://portfolio.test/es/cv/"
});
globalThis.window.location.href = "https://portfolio.test/es/cv/";
globalThis.window.scrollY = 0;
globalThis.document.querySelectorAll = () => [targetAnchor];
const restoredLanguageScrollOnce = await languageScrollModule.restoreLanguageSwitchScrollState({
    language: "es",
    page: "cv"
});
const restoredLanguageScrollTwice = await languageScrollModule.restoreLanguageSwitchScrollState({
    language: "es",
    page: "cv"
});
if (!capturedLanguageScroll
    || !restoredLanguageScrollOnce
    || restoredLanguageScrollTwice
    || restoredLanguageScroll?.top !== 850
    || restoredLanguageScroll?.behavior !== "auto"
    || pendingLanguageScrollStorage.size !== 0) {
    fail("Language scroll: la captura/restauracion real no es semantica, inmediata y one-shot");
}
if (previousWindow === undefined) delete globalThis.window;
else globalThis.window = previousWindow;
if (previousDocument === undefined) delete globalThis.document;
else globalThis.document = previousDocument;
const expectedCvAnchors = "work-experience|education|ludography|downloads";
for (const language of ["en", "es"]) {
    const cvAnchors = [...read(`content/cv/${language}.html`).matchAll(/<section id="([^"]+)"/g)]
        .map((match) => match[1])
        .join("|");
    if (cvAnchors !== expectedCvAnchors) {
        fail(`Language scroll: CV ${language.toUpperCase()} no expone anclas semanticas equivalentes`);
    }
}
if (!languageScrollSource.includes("window.sessionStorage.setItem")
    || !languageScrollSource.includes("window.sessionStorage.removeItem")
    || languageScrollSource.includes("window.localStorage")) {
    fail("Language scroll: el estado no es efimero y one-shot en sessionStorage");
}
if (!shellSource.includes("captureLanguageSwitchScrollState({")
    || !shellSource.includes("targetLanguage !== language")
    || (shellSource.match(/captureLanguageSwitchScrollState\(\{/g) ?? []).length !== 1) {
    fail("Language scroll: la captura no esta aislada al selector de idioma");
}
if (appSource.indexOf("await restoreLanguageSwitchScrollState(context)")
    < appSource.indexOf("await pageModule.render({ ...context, target })")) {
    fail("Language scroll: la restauracion ocurre antes de completar el render de pagina");
}
if (!languageScrollSource.includes("requestAnimationFrame")
    || !languageScrollSource.includes('behavior: "auto"')) {
    fail("Language scroll: la restauracion no espera layout estable o introduce scroll animado");
}
if (languageScrollSource.includes("history.scrollRestoration")
    || appSource.includes("history.scrollRestoration")
    || shellSource.includes("history.scrollRestoration")) {
    fail("Language scroll: se ha sobrescrito la restauracion nativa del historial");
}
if (cvPageSource.includes("detailUrl") || /createElement\("a"/.test(cvPageSource)) {
    fail("CV Ludography: los enlaces a Game Detail no se eliminaron");
}
if (/createElement\("(?:strong|b)"/.test(cvPageSource)
    || !cvPageSource.includes('createElement("li", { text: `${game.title} - ${game.year ?? "?"}` })')) {
    fail("CV Ludography: formato de texto normal Game Title - Year no resuelto");
}
if (!cvPageSource.includes('createElement("ol", { className: "ludography-list" })')) {
    fail("CV Ludography: la secuencia dejo de usar una lista ordenada semantica");
}
if (!/\.ludography-list\s*\{[^}]*padding:\s*0;[^}]*list-style:\s*none;/s.test(frontendCss)) {
    fail("CV Ludography: numeracion visible o sangria lateral no eliminada");
}

const aboutEnglish = read("content/about/en.html");
const aboutSpanish = read("content/about/es.html");
if (/id="contact"|mailto:|linkedin\.com/i.test(aboutEnglish + aboutSpanish)) {
    fail("About: el bloque de contacto sigue presente");
}
if (!aboutPageSource.includes('article.querySelector("#contact")?.remove()')) {
    fail("About: el renderer no protege la separacion About/Contact");
}
const portraitRule = frontendCss.match(/\.about-portrait\s*\{([^}]*)\}/s)?.[1] ?? "";
if (!portraitRule || /border\s*:|outline\s*:|box-shadow\s*:/.test(portraitRule)) {
    fail("About: el retrato conserva un borde, outline o sombra de marco");
}
if (!portraitRule.includes("aspect-ratio: 3 / 4") || !portraitRule.includes("width: 100%")) {
    fail("About: la geometria del retrato cambio");
}

[
    "content/contact/en.html", "content/contact/es.html",
    "js/pages/contact.js"
].forEach((filePath) => assertFile(filePath, "Contact"));
const contactEnglish = read("content/contact/en.html");
const contactSpanish = read("content/contact/es.html");
const contactLinks = new Map();
for (const [language, source, heading] of [["en", contactEnglish, "Contact"], ["es", contactSpanish, "Contacto"]]) {
    if (!source.includes(`<h2>${heading}</h2>`)
        || !source.includes("<h3>Email</h3>")
        || !source.includes("<h3>LinkedIn</h3>")
        || (source.match(/<h2\b/g) ?? []).length !== 1
        || (source.match(/<h3\b/g) ?? []).length !== 2
        || /<h1\b/i.test(source)) {
        fail(`Contact ${language}: jerarquia H2/H3 no resuelta`);
    }

    const emailSection = source.match(/<section id="email"[^>]*>[\s\S]*?<\/section>/)?.[0] ?? "";
    const linkedinSection = source.match(/<section id="linkedin"[^>]*>[\s\S]*?<\/section>/)?.[0] ?? "";
    const emailLink = emailSection.match(/<a\b[^>]*\bhref="([^"]+)"[^>]*>([^<]+)<\/a>/);
    const linkedinLink = linkedinSection.match(/<a\b[^>]*\bhref="([^"]+)"[^>]*>([^<]+)<\/a>/);
    if (/<p>\?<\/p>/.test(source)
        || !emailLink || !emailLink[1].toLowerCase().startsWith("mailto:") || !emailLink[2].trim()
        || !linkedinLink || !linkedinLink[1].toLowerCase().startsWith("https://") || !linkedinLink[2].trim()) {
        fail(`Contact ${language}: valores o enlaces semanticos invalidos`);
    } else {
        contactLinks.set(language, { email: emailLink[1], linkedin: linkedinLink[1] });
    }
}
if (contactLinks.size === 2
    && (contactLinks.get("en").email !== contactLinks.get("es").email
        || contactLinks.get("en").linkedin !== contactLinks.get("es").linkedin)) {
    fail("Contact: los destinos ES/EN no coinciden");
}
if (!appSource.includes('contact: () => import("./pages/contact.js")')
    || !pathsSource.includes('contact: "contact/"')
    || !publicationSource.includes('"contact"')) {
    fail("Contact: ruta, modulo o publicacion no resueltos");
}
if (publicationModule.SECTION_REGISTRY.at(-1)?.route !== "contact"
    || publicationModule.getSectionById(7)?.route !== "contact") {
    fail("Contact: no es el ultimo elemento de navegacion");
}
if (!/body\[data-page="contact"\] \.page-shell\s*\{[^}]*padding-top:\s*calc\(var\(--header-height\) \+ var\(--page-top-gap\)\)/s.test(frontendCss)
    || !frontendCss.includes("--page-top-gap: 1.25rem;")) {
    fail("Contact: separacion superior de 20px no resuelta");
}
if (!frontendCss.includes("--contact-heading-size: 1.75rem;")
    || !frontendCss.includes("--contact-subheading-size: 1.375rem;")) {
    fail("Contact: tipografia H2/H3 de 28px/22px no resuelta");
}
if (!/\.contact-field p\s*\{[^}]*overflow-wrap:\s*anywhere/s.test(frontendCss)) {
    fail("Contact: los valores largos no protegen el viewport");
}

(projectsRegistry.projects ?? []).forEach((project) => {
    if (project.contentStatus !== "content-ready") fail(`${project.id}: proyecto no preparado`);
    assertFile(project.content.en, `${project.id}: contenido EN`);
    assertFile(project.content.es, `${project.id}: contenido ES`);
    if ((project.prototypeVideos ?? []).length > 4) fail(`${project.id}: más de 4 vídeos destacados`);
});

(storiesRegistry.stories ?? []).forEach((story) => {
    if (story.contentStatus !== "content-ready") fail(`${story.id}: relato no preparado`);
    assertFile(story.content.en, `${story.id}: contenido EN`);
    assertFile(story.content.es, `${story.id}: contenido ES`);
});

const entries = [...(journalRegistry.entries ?? [])].sort((a, b) => a.order - b.order);
entries.forEach((entry, index) => {
    if (entry.contentStatus !== "content-ready") fail(`${entry.id}: entrada no preparada`);
    assertFile(entry.content.en, `${entry.id}: contenido EN`);
    assertFile(entry.content.es, `${entry.id}: contenido ES`);
    const previous = entries[index - 1]?.order;
    const next = entries[index + 1]?.order;
    if (previous !== undefined && previous >= entry.order) fail(`${entry.id}: orden previo inconsistente`);
    if (next !== undefined && next <= entry.order) fail(`${entry.id}: orden siguiente inconsistente`);
});

[
    "content/about/en.html", "content/about/es.html",
    "content/cv/en.html", "content/cv/es.html",
    "assets/about/profile/carlos-lopez-profile.jpg",
    "assets/downloads/cv/carlos-lopez-cv.pdf",
    "assets/downloads/portfolio/carlos-lopez-portfolio.pdf"
].forEach((filePath) => assertFile(filePath));

const applicationFiles = [
    ...walk("js", [".js"]),
    ...walk("css", [".css"]),
    ...canonicalRoutes.map((route) => path.join(root, route))
];
applicationFiles.forEach((filePath) => {
    const source = fs.readFileSync(filePath, "utf8");
    const file = relative(filePath);
    if (source.includes("carlosdelali.github.io")) fail(`${file}: base de repositorio hardcodeada`);
    if (source.includes("data/dreams.json")) fail(`${file}: dependencia retirada data/dreams.json`);
    if (/[ÃÂ]/u.test(source)) fail(`${file}: posible mojibake`);
    if (/Dream Journal|Diario de sueños/i.test(source) && !file.includes("dream-journal/")) {
        fail(`${file}: terminología legacy fuera del redirect`);
    }
});

walk("js", [".js"]).forEach((filePath) => {
    const source = fs.readFileSync(filePath, "utf8");
    for (const match of source.matchAll(/(?:from\s+|import\s*\()\s*["'](\.[^"']+)["']/g)) {
        const imported = path.resolve(path.dirname(filePath), match[1]);
        if (!fs.existsSync(imported)) fail(`${relative(filePath)}: import no resuelto ${match[1]}`);
    }
});

if (failures.length) {
    console.error("FRONTEND QA: FAIL");
    failures.forEach((failure) => console.error(`- ${failure}`));
    process.exitCode = 1;
} else {
    console.log("FRONTEND QA: PASS");
    console.log(`Routes: ${canonicalRoutes.length}`);
    console.log(`Games: ${games.length}`);
    console.log(`Projects: ${(projectsRegistry.projects ?? []).length}`);
    console.log(`Stories: ${(storiesRegistry.stories ?? []).length}`);
    console.log(`Oniric entries: ${entries.length}`);
}
