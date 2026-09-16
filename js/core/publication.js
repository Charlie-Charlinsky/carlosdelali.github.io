export const SECTION_REGISTRY = Object.freeze([
    Object.freeze({ id: 1, key: "ABOUT", route: "about", published: true }),
    Object.freeze({ id: 2, key: "CV", route: "cv", published: true }),
    Object.freeze({ id: 3, key: "GAMES", route: "games", published: true }),
    Object.freeze({ id: 4, key: "PROJECTS", route: "projects", published: false }),
    Object.freeze({ id: 5, key: "WRITING", route: "writing", published: false }),
    Object.freeze({ id: 6, key: "ONIRIC_JOURNAL", route: "oniric-journal", published: false }),
    Object.freeze({ id: 7, key: "CONTACT", route: "contact", published: true })
]);

export const PUBLICATION_POLICY = Object.freeze({
    sections: SECTION_REGISTRY,
    items: Object.freeze({
        "cv-downloads": Object.freeze(["cv"])
    })
});

const SECTION_BY_ID = new Map(SECTION_REGISTRY.map((section) => [section.id, section]));
const SECTION_BY_ROUTE = new Map(SECTION_REGISTRY.map((section) => [section.route, section]));

const PAGE_SECTIONS = Object.freeze({
    "game-detail": "games",
    "project-detail": "projects",
    "oniric-journal-detail": "oniric-journal"
});

export function getSectionForPage(pageId) {
    return PAGE_SECTIONS[pageId] ?? pageId;
}

export function getSectionById(sectionId) {
    return SECTION_BY_ID.get(Number(sectionId)) ?? null;
}

export function getPublishedSections() {
    return SECTION_REGISTRY.filter((section) => section.published);
}

export function isSectionPublished(sectionRoute) {
    return SECTION_BY_ROUTE.get(sectionRoute)?.published ?? false;
}

export function isPagePublished(pageId) {
    return isSectionPublished(getSectionForPage(pageId));
}

export function isItemPublished(groupId, itemId) {
    return PUBLICATION_POLICY.items[groupId]?.includes(itemId) ?? false;
}

export function filterPublishedItems(groupId, items, getId = (item) => item.id) {
    return [...items].filter((item) => isItemPublished(groupId, getId(item)));
}

export function applyPublicationPolicy(root) {
    root.querySelectorAll("[data-publication-group][data-publication-item]").forEach((element) => {
        if (!isItemPublished(element.dataset.publicationGroup, element.dataset.publicationItem)) {
            element.remove();
        }
    });
    return root;
}
