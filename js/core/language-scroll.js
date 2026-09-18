const STORAGE_KEY = "portfolio-language-scroll";
export const LANGUAGE_SCROLL_STATE_VERSION = 1;
export const LANGUAGE_SCROLL_TTL_MS = 60_000;

const ANCHOR_SELECTOR = "[data-scroll-anchor], #app-content section[id], #app-content article[id]";
const READING_LINE_RATIO = 0.35;

export function clampScrollProgress(value) {
    if (!Number.isFinite(value)) return 0;
    return Math.min(1, Math.max(0, value));
}

export function createRouteIdentity(url, baseUrl = globalThis.window?.location?.href ?? "http://localhost/") {
    try {
        const parsed = new URL(url, baseUrl);
        return `${parsed.pathname}${parsed.search}`;
    } catch {
        return null;
    }
}

function getDocumentScrollHeight() {
    return Math.max(
        document.documentElement?.scrollHeight ?? 0,
        document.body?.scrollHeight ?? 0
    );
}

function getMaximumScrollDistance() {
    return Math.max(0, getDocumentScrollHeight() - Math.max(0, window.innerHeight));
}

export function getNormalizedScrollProgress({
    scrollY = window.scrollY,
    scrollHeight = getDocumentScrollHeight(),
    viewportHeight = window.innerHeight
} = {}) {
    const maximum = Math.max(0, scrollHeight - Math.max(0, viewportHeight));
    return maximum > 0 ? clampScrollProgress(scrollY / maximum) : 0;
}

function getAnchorIdentity(element) {
    return element.dataset.scrollAnchor || element.id || null;
}

function getSemanticAnchors(root = document) {
    return [...root.querySelectorAll(ANCHOR_SELECTOR)]
        .map((element) => ({ element, identity: getAnchorIdentity(element), rect: element.getBoundingClientRect() }))
        .filter(({ identity, rect }) => identity && rect.height > 0);
}

export function findCurrentScrollAnchor(root = document) {
    const viewportHeight = Math.max(1, window.innerHeight);
    const readingLine = viewportHeight * READING_LINE_RATIO;
    const candidates = getSemanticAnchors(root)
        .map((candidate) => {
            const { rect } = candidate;
            const distance = readingLine < rect.top
                ? rect.top - readingLine
                : readingLine > rect.bottom
                    ? readingLine - rect.bottom
                    : 0;
            return { ...candidate, distance };
        })
        .filter(({ distance }) => distance <= viewportHeight)
        .sort((left, right) => left.distance - right.distance);
    const match = candidates[0];
    if (!match) return null;

    const anchorOffset = Math.min(match.rect.height, Math.max(0, readingLine - match.rect.top));
    return {
        anchorId: match.identity,
        anchorOffset,
        anchorProgress: clampScrollProgress(anchorOffset / match.rect.height),
        viewportReference: READING_LINE_RATIO
    };
}

function writePendingState(state) {
    try {
        window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(state));
        return true;
    } catch {
        return false;
    }
}

export function captureLanguageSwitchScrollState({
    sourceLanguage,
    targetLanguage,
    page,
    targetUrl,
    now = Date.now()
}) {
    if (!targetUrl || sourceLanguage === targetLanguage) return false;

    const state = {
        version: LANGUAGE_SCROLL_STATE_VERSION,
        timestamp: now,
        sourceLanguage,
        targetLanguage,
        sourceRoute: page,
        targetRoute: page,
        sourceUrl: createRouteIdentity(window.location.href),
        targetUrl: createRouteIdentity(targetUrl),
        progress: getNormalizedScrollProgress(),
        ...findCurrentScrollAnchor()
    };
    return writePendingState(state);
}

function takePendingState() {
    try {
        const serialized = window.sessionStorage.getItem(STORAGE_KEY);
        window.sessionStorage.removeItem(STORAGE_KEY);
        return serialized ? JSON.parse(serialized) : null;
    } catch {
        try {
            window.sessionStorage.removeItem(STORAGE_KEY);
        } catch {
            // Storage may be unavailable; there is no pending state to restore.
        }
        return null;
    }
}

export function isLanguageSwitchScrollStateValid(state, {
    language,
    page,
    currentUrl,
    now = Date.now()
}) {
    if (!state || state.version !== LANGUAGE_SCROLL_STATE_VERSION) return false;
    if (!Number.isFinite(state.timestamp) || now < state.timestamp || now - state.timestamp > LANGUAGE_SCROLL_TTL_MS) {
        return false;
    }
    if (state.targetLanguage !== language || state.targetRoute !== page) return false;
    if (state.targetUrl !== createRouteIdentity(currentUrl)) return false;
    return Number.isFinite(state.progress) && state.progress >= 0 && state.progress <= 1;
}

function findTargetAnchor(anchorId, root = document) {
    if (!anchorId) return null;
    return getSemanticAnchors(root).find(({ identity }) => identity === anchorId) ?? null;
}

export function calculateLanguageSwitchScrollTop(state, {
    maximumScroll,
    viewportHeight,
    anchorTop,
    anchorHeight
}) {
    const maximum = Math.max(0, maximumScroll);
    if (Number.isFinite(anchorTop) && Number.isFinite(anchorHeight) && anchorHeight > 0) {
        const localOffset = Number.isFinite(state.anchorProgress)
            ? anchorHeight * clampScrollProgress(state.anchorProgress)
            : Math.min(anchorHeight, Math.max(0, state.anchorOffset ?? 0));
        const readingLine = Math.max(0, viewportHeight) * clampScrollProgress(
            state.viewportReference ?? READING_LINE_RATIO
        );
        return Math.min(maximum, Math.max(0, anchorTop + localOffset - readingLine));
    }
    return maximum * clampScrollProgress(state.progress);
}

function nextAnimationFrame() {
    return new Promise((resolve) => window.requestAnimationFrame(resolve));
}

async function waitForStableLayout() {
    try {
        await document.fonts?.ready;
    } catch {
        // Font loading failure should not prevent scroll restoration.
    }
    await nextAnimationFrame();
    await nextAnimationFrame();
}

export async function restoreLanguageSwitchScrollState({ language, page }) {
    const state = takePendingState();
    if (!isLanguageSwitchScrollStateValid(state, {
        language,
        page,
        currentUrl: window.location.href
    })) return false;

    await waitForStableLayout();
    const anchor = findTargetAnchor(state.anchorId);
    const maximumScroll = getMaximumScrollDistance();
    const top = calculateLanguageSwitchScrollTop(state, {
        maximumScroll,
        viewportHeight: window.innerHeight,
        anchorTop: anchor ? anchor.rect.top + window.scrollY : undefined,
        anchorHeight: anchor?.rect.height
    });
    window.scrollTo({ top, left: window.scrollX, behavior: "auto" });
    return true;
}
