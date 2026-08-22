import { getStoredLanguage } from "./core/language.js";
import { resolveRoute } from "./core/paths.js";

const language = getStoredLanguage();
const target = new URL(resolveRoute(language, "about"));
target.search = window.location.search;
target.hash = window.location.hash;
window.location.replace(target.href);
