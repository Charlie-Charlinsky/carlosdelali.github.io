import { createElement, padIndex } from "./dom.js";
import { resolveAsset } from "./paths.js";

export function createPageHeader(kicker, title, description = "") {
    const header = createElement("header", { className: "page-header" });
    header.append(
        createElement("p", { className: "eyebrow", text: kicker }),
        createElement("h1", { text: title })
    );
    if (description) header.append(createElement("p", { className: "page-header__intro", text: description }));
    return header;
}

export function createBackLink(href, label) {
    return createElement("a", {
        className: "back-link",
        text: `← ${label}`,
        attributes: { href }
    });
}

export function createMediaImage(path, alt, className = "") {
    return createElement("img", {
        className,
        attributes: {
            src: resolveAsset(path),
            alt,
            loading: "lazy",
            decoding: "async"
        }
    });
}

export function createIndexLabel(index, prefix = "") {
    return createElement("span", {
        className: "item-index",
        text: `${prefix}${padIndex(index)}`
    });
}

export function localizedValue(value, language, fallback = "") {
    if (value && typeof value === "object") return value[language] || value.en || value.es || fallback;
    return value || fallback;
}
