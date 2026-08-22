export function createElement(tagName, options = {}) {
    const element = document.createElement(tagName);
    if (options.className) element.className = options.className;
    if (options.text !== undefined) element.textContent = options.text;
    if (options.html !== undefined) element.innerHTML = options.html;
    Object.entries(options.attributes ?? {}).forEach(([name, value]) => {
        if (value !== undefined && value !== null) element.setAttribute(name, String(value));
    });
    return element;
}

export function setPageTitle(title) {
    document.title = `${title} — Carlos J. L. Sánchez`;
}

export function renderLoading(target, text) {
    target.replaceChildren(createElement("p", {
        className: "system-message",
        text,
        attributes: { role: "status" }
    }));
}

export function renderError(target, error, language = "en") {
    const message = language === "es"
        ? "No se ha podido cargar esta página. Revisa la conexión y vuelve a intentarlo."
        : "This page could not be loaded. Check the connection and try again.";
    const detail = error?.resource ? ` [${error.resource}]` : "";
    const panel = createElement("section", { className: "error-state", attributes: { role: "alert" } });
    panel.append(
        createElement("p", { className: "eyebrow", text: language === "es" ? "ERROR DE CARGA" : "LOAD ERROR" }),
        createElement("h1", { text: message }),
        createElement("p", { className: "error-state__detail", text: detail })
    );
    target.replaceChildren(panel);
}

export function padIndex(index) {
    return String(index + 1).padStart(2, "0");
}
