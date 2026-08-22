const SITE_ROOT = new URL("../../", import.meta.url);

const PASSTHROUGH_PROTOCOLS = ["http:", "https:", "mailto:", "tel:", "data:", "blob:"];
const INTERNAL_ROOTS = ["assets/", "content/", "data/", "css/", "js/", "en/", "es/"];

export function getSiteRoot() {
    return new URL(SITE_ROOT.href);
}

export function isExternalUrl(value) {
    if (!value || value.startsWith("#")) return true;

    try {
        const url = new URL(value, window.location.href);
        return PASSTHROUGH_PROTOCOLS.includes(url.protocol) && url.origin !== window.location.origin;
    } catch {
        return false;
    }
}

export function resolveSiteUrl(path = "") {
    if (!path) return SITE_ROOT.href;
    if (path.startsWith("#")) return path;

    try {
        const absolute = new URL(path);
        if (PASSTHROUGH_PROTOCOLS.includes(absolute.protocol)) return absolute.href;
    } catch {
        // Repository paths are intentionally handled below.
    }

    const cleanPath = path.replace(/^\.\//, "").replace(/^\//, "");
    return new URL(cleanPath, SITE_ROOT).href;
}

export function resolveAsset(path) {
    return resolveSiteUrl(path);
}

export function resolveData(path) {
    return resolveSiteUrl(path.startsWith("data/") ? path : `data/${path}`);
}

export function resolveContent(path) {
    return resolveSiteUrl(path.startsWith("content/") ? path : `content/${path}`);
}

export function resolveRoute(language, page = "about", options = {}) {
    const routeMap = {
        about: "",
        cv: "cv/",
        games: "games/",
        "game-detail": "games/detail/",
        projects: "projects/",
        "project-detail": "projects/detail/",
        writing: "writing/",
        "oniric-journal": "oniric-journal/",
        "oniric-journal-detail": "oniric-journal/detail/"
    };
    const route = routeMap[page] ?? "";
    const url = new URL(`${language}/${route}`, SITE_ROOT);

    Object.entries(options.query ?? {}).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== "") {
            url.searchParams.set(key, value);
        }
    });

    if (options.hash) url.hash = options.hash;
    return url.href;
}

export function normalizeRepositoryUrl(value) {
    if (!value || value.startsWith("#") || /^(mailto:|tel:|data:|blob:)/i.test(value)) return value;
    if (/^https?:\/\//i.test(value) || value.startsWith("//")) return value;

    const clean = value.replace(/^\.\//, "").replace(/^\//, "");
    if (INTERNAL_ROOTS.some((root) => clean.startsWith(root))) return resolveSiteUrl(clean);
    return value;
}

export function normalizeSrcset(value) {
    return value.split(",").map((candidate) => {
        const parts = candidate.trim().split(/\s+/);
        parts[0] = normalizeRepositoryUrl(parts[0]);
        return parts.join(" ");
    }).join(", ");
}
