import { getStoredLanguage } from "./core/language.js";
import { resolveRoute } from "./core/paths.js";
import { getDefaultPublishedSection } from "./core/publication.js";

const explicitLanguage = document.body.dataset.lang;
const language = explicitLanguage === "en" || explicitLanguage === "es"
    ? explicitLanguage
    : getStoredLanguage();
const defaultSection = getDefaultPublishedSection();

if (!defaultSection) throw new Error("No published navigation section is available");

const target = new URL(resolveRoute(language, defaultSection.route));
target.search = window.location.search;
target.hash = window.location.hash;
window.location.replace(target.href);
