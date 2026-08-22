import { normalizeRepositoryUrl, normalizeSrcset, resolveSiteUrl } from "./paths.js";

export class FrontendLoadError extends Error {
    constructor(message, resource, cause) {
        super(message, { cause });
        this.name = "FrontendLoadError";
        this.resource = resource;
    }
}

async function request(path, responseType) {
    const url = resolveSiteUrl(path);

    try {
        const response = await fetch(url, { credentials: "same-origin" });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return responseType === "json" ? response.json() : response.text();
    } catch (error) {
        throw new FrontendLoadError(`No se pudo cargar el recurso solicitado.`, path, error);
    }
}

export function loadJson(path) {
    return request(path, "json");
}

export async function loadSemanticFragment(path) {
    const html = await request(path, "text");
    const template = document.createElement("template");
    template.innerHTML = html.trim();
    normalizeFragmentUrls(template.content);
    return template.content;
}

export function normalizeFragmentUrls(root) {
    root.querySelectorAll("[href], [src], [poster], [srcset]").forEach((element) => {
        ["href", "src", "poster"].forEach((attribute) => {
            if (!element.hasAttribute(attribute)) return;
            element.setAttribute(attribute, normalizeRepositoryUrl(element.getAttribute(attribute)));
        });

        if (element.hasAttribute("srcset")) {
            element.setAttribute("srcset", normalizeSrcset(element.getAttribute("srcset")));
        }
    });
}
