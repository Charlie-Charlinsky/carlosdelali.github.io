import { resolveRoute } from "./core/paths.js";

const language = document.documentElement.lang === "es" ? "es" : "en";
const target = new URL(resolveRoute(language, "oniric-journal"));
target.search = window.location.search;
target.hash = window.location.hash;
window.location.replace(target.href);
