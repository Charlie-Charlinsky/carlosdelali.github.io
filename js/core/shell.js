import { alternateLanguage, storeLanguage } from "./language.js";
import { resolveRoute } from "./paths.js";
import { getEquivalentLanguageUrl } from "./routes.js";
import { createElement } from "./dom.js";

const LABELS = {
    en: {
        skip: "Skip to content",
        role: "Game Designer",
        menu: "Menu",
        close: "Close",
        navigation: "Primary navigation",
        pages: {
            about: "ABOUT",
            cv: "CV",
            games: "GAMES",
            projects: "PROJECTS",
            writing: "WRITING",
            "oniric-journal": "ONIRIC JOURNAL"
        }
    },
    es: {
        skip: "Saltar al contenido",
        role: "Diseñador de juegos",
        menu: "Menú",
        close: "Cerrar",
        navigation: "Navegación principal",
        pages: {
            about: "SOBRE MÍ",
            cv: "CV",
            games: "JUEGOS",
            projects: "PROYECTOS",
            writing: "ESCRITURA",
            "oniric-journal": "DIARIO ONÍRICO"
        }
    }
};

const NAVIGATION = ["about", "cv", "games", "projects", "writing", "oniric-journal"];
const PAGE_FAMILY = {
    "game-detail": "games",
    "project-detail": "projects",
    "oniric-journal-detail": "oniric-journal"
};

export function buildShell(language, page) {
    const strings = LABELS[language];
    const activePage = PAGE_FAMILY[page] ?? page;
    const headerMount = document.querySelector("#site-header");
    const skipLink = document.querySelector(".skip-link");
    if (skipLink) skipLink.textContent = strings.skip;

    const header = createElement("header", { className: "site-header" });
    const identity = createElement("div", { className: "site-identity" });
    const languageNav = createElement("nav", {
        className: "language-switcher",
        attributes: { "aria-label": language === "es" ? "Idioma" : "Language" }
    });

    ["es", "en"].forEach((targetLanguage) => {
        const link = createElement("a", {
            text: targetLanguage === "es" ? "ESP" : "ENG",
            attributes: {
                href: targetLanguage === language
                    ? window.location.href
                    : getEquivalentLanguageUrl(targetLanguage, page),
                hreflang: targetLanguage,
                lang: targetLanguage
            }
        });
        if (targetLanguage === language) link.setAttribute("aria-current", "true");
        link.addEventListener("click", () => storeLanguage(targetLanguage));
        languageNav.append(link);
    });

    const brand = createElement("a", {
        className: "site-brand",
        attributes: { href: resolveRoute(language, "about"), "aria-label": "Carlos J. L. Sánchez" }
    });
    brand.append(
        createElement("span", { className: "site-brand__name", text: "CARLOS J. L. SÁNCHEZ" }),
        createElement("span", { className: "site-brand__role", text: strings.role })
    );
    identity.append(languageNav, brand);

    const toggle = createElement("button", {
        className: "nav-toggle",
        text: strings.menu,
        attributes: { type: "button", "aria-expanded": "false", "aria-controls": "primary-navigation" }
    });
    const navigation = createElement("nav", {
        className: "site-nav",
        attributes: { id: "primary-navigation", "aria-label": strings.navigation }
    });

    NAVIGATION.forEach((route, index) => {
        const link = createElement("a", { attributes: { href: resolveRoute(language, route) } });
        link.append(
            createElement("span", { className: "site-nav__index", text: String(index + 1).padStart(2, "0") }),
            createElement("span", { text: strings.pages[route] })
        );
        if (route === activePage) link.setAttribute("aria-current", "page");
        navigation.append(link);
    });

    toggle.addEventListener("click", () => {
        const open = toggle.getAttribute("aria-expanded") === "true";
        toggle.setAttribute("aria-expanded", String(!open));
        toggle.textContent = open ? strings.menu : strings.close;
        navigation.classList.toggle("is-open", !open);
        document.body.classList.toggle("nav-open", !open);
    });
    navigation.addEventListener("click", () => {
        toggle.setAttribute("aria-expanded", "false");
        toggle.textContent = strings.menu;
        navigation.classList.remove("is-open");
        document.body.classList.remove("nav-open");
    });
    document.addEventListener("keydown", (event) => {
        if (event.key !== "Escape") return;
        toggle.setAttribute("aria-expanded", "false");
        toggle.textContent = strings.menu;
        navigation.classList.remove("is-open");
        document.body.classList.remove("nav-open");
    });

    header.append(identity, toggle, navigation);
    headerMount.replaceChildren(header);

    const alternate = alternateLanguage(language);
    document.querySelectorAll("link[rel='alternate']").forEach((link) => link.remove());
    const alternateLink = createElement("link", {
        attributes: { rel: "alternate", hreflang: alternate, href: getEquivalentLanguageUrl(alternate, page) }
    });
    document.head.append(alternateLink);
}
