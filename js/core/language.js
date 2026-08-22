const STORAGE_KEY = "portfolio-language";
const SUPPORTED_LANGUAGES = ["en", "es"];

export function normalizeLanguage(value) {
    return SUPPORTED_LANGUAGES.includes(value) ? value : "en";
}

export function getDocumentLanguage() {
    return normalizeLanguage(document.documentElement.lang || document.body.dataset.lang);
}

export function getStoredLanguage() {
    try {
        return normalizeLanguage(window.localStorage.getItem(STORAGE_KEY));
    } catch {
        return "en";
    }
}

export function storeLanguage(language) {
    try {
        window.localStorage.setItem(STORAGE_KEY, normalizeLanguage(language));
    } catch {
        // Storage can be unavailable in privacy modes; routing still works.
    }
}

export function alternateLanguage(language) {
    return normalizeLanguage(language) === "en" ? "es" : "en";
}
