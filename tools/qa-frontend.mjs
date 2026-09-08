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
const publicationSource = read("js/core/publication.js");
const shellSource = read("js/core/shell.js");
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
if (!gameDetailSource.includes("createMediaGallery(game.media")) {
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
    if (!game.assets.gallery?.length || game.assets.gallery.length > 6) {
        fail(`${game.id}: galería fuera del rango 1–6`);
    }
    game.assets.gallery?.forEach((asset) => assertFile(asset, `${game.id}: galería`));
});

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
for (const [language, source, heading] of [["en", contactEnglish, "Contact"], ["es", contactSpanish, "Contacto"]]) {
    if (!source.includes(`<h2>${heading}</h2>`)
        || !source.includes("<h3>Email</h3>")
        || !source.includes("<h3>LinkedIn</h3>")) {
        fail(`Contact ${language}: jerarquia H2/H3 no resuelta`);
    }
    if ((source.match(/<p>\?<\/p>/g) ?? []).length !== 2 || /<a\b/i.test(source)) {
        fail(`Contact ${language}: placeholders o enlaces invalidos`);
    }
}
if (!appSource.includes('contact: () => import("./pages/contact.js")')
    || !pathsSource.includes('contact: "contact/"')
    || !publicationSource.includes('"contact"')) {
    fail("Contact: ruta, modulo o publicacion no resueltos");
}
if (!/const NAVIGATION = \[[^\]]*"contact"\];/s.test(shellSource)
    || !/"oniric-journal",\s*"contact"\]/s.test(shellSource)) {
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
    "assets/about/profile/carlos-lopez-profile.png",
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
