import { createMediaImage, localizedValue } from "./components.js";
import { createElement } from "./dom.js";
import { resolveAsset } from "./paths.js";

export const MEDIA_LIMITS = Object.freeze({ images: 12, videos: 4, total: 16 });

export function youtubeEmbedUrl(videoId) {
    return `https://www.youtube-nocookie.com/embed/${encodeURIComponent(videoId)}`;
}

function youtubeThumbnailUrl(videoId) {
    return `https://i.ytimg.com/vi/${encodeURIComponent(videoId)}/hqdefault.jpg`;
}

export function composeGameMedia(youtubeVideos = [], localMedia = []) {
    const youtube = youtubeVideos
        .filter((item) => item?.provider === "youtube" && /^[A-Za-z0-9_-]{11}$/.test(item.videoId ?? ""))
        .map((item) => ({ ...item, type: "youtube" }));
    const localVideos = localMedia.filter((item) => item?.type === "video");
    const images = localMedia.filter((item) => item?.type === "image");
    const remainingVideoSlots = Math.max(0, MEDIA_LIMITS.videos - youtube.length);
    return limitMedia([
        ...youtube,
        ...localVideos.slice(0, remainingVideoSlots),
        ...images
    ]);
}

const LABELS = {
    en: {
        gallery: "Media gallery",
        empty: "Media pending.",
        previous: "Previous media",
        next: "Next media",
        theater: "Open theater mode",
        exitTheater: "Close theater mode",
        fullscreen: "Open fullscreen mode",
        exitFullscreen: "Exit fullscreen mode",
        openImage: "Open image in theater mode",
        image: "Image",
        video: "Video"
    },
    es: {
        gallery: "Galería multimedia",
        empty: "Medios pendientes.",
        previous: "Medio anterior",
        next: "Medio siguiente",
        theater: "Abrir modo cine",
        exitTheater: "Cerrar modo cine",
        fullscreen: "Abrir pantalla completa",
        exitFullscreen: "Salir de pantalla completa",
        openImage: "Abrir imagen en modo cine",
        image: "Imagen",
        video: "Vídeo"
    }
};

const CONTEXT_LABELS = {
    project: {
        en: { gallery: "Project media", empty: "Showcase media pending." },
        es: { gallery: "Medios del proyecto", empty: "Medios del showcase pendientes." }
    },
    game: {
        en: { gallery: "Game media", empty: "Game media pending." },
        es: { gallery: "Medios del juego", empty: "Medios del juego pendientes." }
    }
};

export function limitMedia(source = []) {
    const counts = { image: 0, video: 0 };
    return source.reduce((items, item) => {
        if (!item || !["image", "video", "youtube"].includes(item.type)) return items;
        if (item.type === "youtube" && !/^[A-Za-z0-9_-]{11}$/.test(item.videoId ?? "")) return items;
        if (item.type !== "youtube" && !item.src) return items;
        if (items.length >= MEDIA_LIMITS.total) return items;
        const category = item.type === "image" ? "image" : "video";
        const limit = category === "image" ? MEDIA_LIMITS.images : MEDIA_LIMITS.videos;
        if (counts[category] >= limit) return items;
        counts[category] += 1;
        items.push(item);
        return items;
    }, []);
}

function createControl(text, label, className = "") {
    return createElement("button", {
        className,
        text,
        attributes: { type: "button", "aria-label": label, title: label }
    });
}

export function createMediaGallery(sourceMedia, { language, title, context = "generic" }) {
    const labels = { ...LABELS[language], ...CONTEXT_LABELS[context]?.[language] };
    const media = limitMedia(sourceMedia);
    const root = createElement("section", {
        className: `media-viewer media-viewer--${context}`,
        attributes: { "aria-label": labels.gallery, tabindex: "0" }
    });
    const stage = createElement("div", { className: "media-viewer__stage" });
    const viewport = createElement("div", { className: "media-viewer__viewport" });
    const actions = createElement("div", { className: "media-viewer__actions" });
    const theaterButton = createControl("THEATER", labels.theater, "media-viewer__theater-button");
    const fullscreenButton = createControl("⛶", labels.fullscreen, "media-viewer__fullscreen-button");
    const carousel = createElement("div", { className: "media-viewer__carousel" });
    const previousButton = createControl("←", labels.previous, "media-viewer__previous");
    const nextButton = createControl("→", labels.next, "media-viewer__next");
    const strip = createElement("div", {
        className: "media-viewer__strip",
        attributes: { "aria-label": labels.gallery }
    });
    const thumbnails = [];
    let selectedIndex = media.length ? 0 : -1;
    let theaterOpen = false;
    let restoreFocus = null;
    const anchor = createElement("div", { className: "media-viewer__anchor", attributes: { "aria-hidden": "true" } });
    const theater = createElement("div", {
        className: "media-viewer-theater",
        attributes: { role: "dialog", "aria-modal": "true", "aria-label": labels.gallery }
    });
    const closeTheaterButton = createControl("×", labels.exitTheater, "media-viewer-theater__close");

    function stopCurrentMedia() {
        viewport.querySelector("video")?.pause();
        const youtube = viewport.querySelector(".media-viewer__youtube");
        if (youtube) youtube.src = "about:blank";
    }

    function openTheater() {
        if (theaterOpen) return;
        theaterOpen = true;
        restoreFocus = document.activeElement;
        root.before(anchor);
        theater.append(closeTheaterButton, root);
        document.body.append(theater);
        document.body.classList.add("has-media-theater");
        root.classList.add("is-theater");
        theaterButton.setAttribute("aria-label", labels.exitTheater);
        theaterButton.title = labels.exitTheater;
        closeTheaterButton.focus();
    }

    async function closeTheater() {
        if (!theaterOpen) return;
        if (document.fullscreenElement === root && document.exitFullscreen) {
            await document.exitFullscreen().catch(() => {});
        }
        theaterOpen = false;
        anchor.replaceWith(root);
        theater.remove();
        document.body.classList.remove("has-media-theater");
        root.classList.remove("is-theater");
        theaterButton.setAttribute("aria-label", labels.theater);
        theaterButton.title = labels.theater;
        restoreFocus?.focus?.();
    }

    function createPrimaryMedia(item, index) {
        const alt = localizedValue(item.alt, language, `${title} — ${labels.image} ${index + 1}`);
        if (item.type === "video") {
            return createElement("video", {
                className: "media-viewer__video",
                attributes: {
                    src: resolveAsset(item.src),
                    poster: item.poster ? resolveAsset(item.poster) : undefined,
                    controls: "",
                    preload: "metadata",
                    playsinline: ""
                }
            });
        }
        if (item.type === "youtube") {
            return createElement("iframe", {
                className: "media-viewer__youtube",
                attributes: {
                    src: youtubeEmbedUrl(item.videoId),
                    title: localizedValue(item.label, language, `${title} - ${labels.video} ${index + 1}`),
                    loading: "lazy",
                    allow: "accelerometer; encrypted-media; gyroscope; picture-in-picture; web-share",
                    allowfullscreen: "",
                    referrerpolicy: "strict-origin-when-cross-origin"
                }
            });
        }

        const button = createElement("button", {
            className: "media-viewer__image-button",
            attributes: { type: "button", "aria-label": labels.openImage }
        });
        const image = createMediaImage(item.src, alt, "media-viewer__image");
        image.loading = "eager";
        button.append(image);
        button.addEventListener("click", openTheater);
        return button;
    }

    function selectMedia(index, scrollThumbnail = true) {
        if (!media.length || index < 0 || index >= media.length) return;
        stopCurrentMedia();
        selectedIndex = index;
        viewport.replaceChildren(createPrimaryMedia(media[index], index));
        thumbnails.forEach((thumbnail, thumbnailIndex) => {
            thumbnail.setAttribute("aria-pressed", String(thumbnailIndex === selectedIndex));
        });
        previousButton.disabled = selectedIndex === 0;
        nextButton.disabled = selectedIndex === media.length - 1;
        if (scrollThumbnail) {
            thumbnails[selectedIndex]?.scrollIntoView({
                behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
                block: "nearest",
                inline: "center"
            });
        }
    }

    media.forEach((item, index) => {
        const isVideo = item.type === "video" || item.type === "youtube";
        const mediaLabel = isVideo ? labels.video : labels.image;
        const thumbnail = createElement("button", {
            className: `media-viewer__thumbnail media-viewer__thumbnail--${item.type}`,
            attributes: {
                type: "button",
                "aria-label": localizedValue(item.label, language, `${mediaLabel} ${index + 1}`),
                "aria-pressed": String(index === selectedIndex)
            }
        });
        const previewPath = item.type === "youtube" ? youtubeThumbnailUrl(item.videoId) : (item.type === "video" ? item.poster : item.src);
        if (previewPath) thumbnail.append(createMediaImage(previewPath, "", "media-viewer__thumbnail-image"));
        if (isVideo) {
            thumbnail.append(createElement("span", {
                className: "media-viewer__video-badge",
                text: "▶",
                attributes: { "aria-hidden": "true" }
            }));
        }
        thumbnail.addEventListener("click", () => selectMedia(index));
        thumbnails.push(thumbnail);
        strip.append(thumbnail);
    });

    previousButton.addEventListener("click", () => selectMedia(selectedIndex - 1));
    nextButton.addEventListener("click", () => selectMedia(selectedIndex + 1));
    theaterButton.addEventListener("click", () => theaterOpen ? closeTheater() : openTheater());
    closeTheaterButton.addEventListener("click", closeTheater);
    fullscreenButton.addEventListener("click", async () => {
        if (!root.requestFullscreen) return;
        try {
            if (document.fullscreenElement === root) {
                await document.exitFullscreen();
            } else {
                await root.requestFullscreen();
            }
        } catch {
            // Fullscreen permission and support remain browser-controlled.
        }
    });

    root.addEventListener("keydown", (event) => {
        if (event.target.closest("video, iframe")) return;
        if (event.key === "ArrowLeft") {
            event.preventDefault();
            selectMedia(selectedIndex - 1);
        } else if (event.key === "ArrowRight") {
            event.preventDefault();
            selectMedia(selectedIndex + 1);
        } else if (event.key === "Escape" && theaterOpen) {
            event.preventDefault();
            closeTheater();
        }
    });

    document.addEventListener("fullscreenchange", () => {
        const fullscreen = document.fullscreenElement === root;
        fullscreenButton.setAttribute("aria-label", fullscreen ? labels.exitFullscreen : labels.fullscreen);
        fullscreenButton.title = fullscreen ? labels.exitFullscreen : labels.fullscreen;
    });

    actions.append(theaterButton, fullscreenButton);
    stage.append(viewport, actions);
    carousel.append(previousButton, strip, nextButton);
    root.append(stage, carousel);

    if (media.length) {
        selectMedia(0, false);
    } else {
        viewport.append(createElement("p", { className: "media-viewer__empty", text: labels.empty }));
        previousButton.disabled = true;
        nextButton.disabled = true;
    }
    if (!root.requestFullscreen) fullscreenButton.disabled = true;

    return root;
}
