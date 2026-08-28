export const PUBLICATION_POLICY = Object.freeze({
    sections: Object.freeze([
        "about",
        "cv",
        "games",
        "projects",
        "writing",
        "oniric-journal"
    ]),
    items: Object.freeze({
        "cv-downloads": Object.freeze(["cv"])
    })
});

const PAGE_SECTIONS = Object.freeze({
    "game-detail": "games",
    "project-detail": "projects",
    "oniric-journal-detail": "oniric-journal"
});

export function getSectionForPage(pageId) {
    return PAGE_SECTIONS[pageId] ?? pageId;
}

export function isSectionPublished(sectionId) {
    return PUBLICATION_POLICY.sections.includes(sectionId);
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
