(function () {
    "use strict";

    const header = document.querySelector("[data-site-header]");
    const navToggle = document.querySelector(".nav-toggle");
    const siteNav = document.querySelector(".site-nav");
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

    function setHeaderState() {
        if (header) {
            header.classList.toggle("is-scrolled", window.scrollY > 24);
        }
    }

    function closeNavigation() {
        if (!navToggle || !siteNav) return;
        navToggle.setAttribute("aria-expanded", "false");
        siteNav.classList.remove("is-open");
        document.body.classList.remove("nav-open");
    }

    if (navToggle && siteNav) {
        navToggle.addEventListener("click", function () {
            const isOpen = navToggle.getAttribute("aria-expanded") === "true";
            navToggle.setAttribute("aria-expanded", String(!isOpen));
            siteNav.classList.toggle("is-open", !isOpen);
            document.body.classList.toggle("nav-open", !isOpen);
        });

        siteNav.querySelectorAll("a").forEach(function (link) {
            link.addEventListener("click", closeNavigation);
        });

        document.addEventListener("keydown", function (event) {
            if (event.key === "Escape") closeNavigation();
        });
    }

    window.addEventListener("scroll", setHeaderState, { passive: true });
    setHeaderState();

    document.querySelectorAll("[data-current-year]").forEach(function (item) {
        item.textContent = String(new Date().getFullYear());
    });

    const reveals = document.querySelectorAll(".reveal");
    if (reducedMotion.matches || !("IntersectionObserver" in window)) {
        reveals.forEach(function (item) {
            item.classList.add("is-visible");
        });
    } else {
        const revealObserver = new IntersectionObserver(function (entries, observer) {
            entries.forEach(function (entry) {
                if (!entry.isIntersecting) return;
                entry.target.classList.add("is-visible");
                observer.unobserve(entry.target);
            });
        }, { rootMargin: "0px 0px -8%", threshold: 0.08 });

        reveals.forEach(function (item) {
            revealObserver.observe(item);
        });
    }

    function bindActiveNavigation(navSelector, sectionSelector) {
        const nav = document.querySelector(navSelector);
        const sections = document.querySelectorAll(sectionSelector);
        if (!nav || !sections.length || !("IntersectionObserver" in window)) return;

        const links = Array.from(nav.querySelectorAll("a[href^='#']"));
        const observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (!entry.isIntersecting) return;
                const current = "#" + entry.target.id;
                links.forEach(function (link) {
                    link.classList.toggle("is-active", link.getAttribute("href") === current);
                });
            });
        }, { rootMargin: "-28% 0px -62%", threshold: 0 });

        sections.forEach(function (section) {
            observer.observe(section);
        });
    }

    bindActiveNavigation(".home-page .site-nav", ".home-page main > section[id]");
    bindActiveNavigation(".project-local-nav", ".project-chapter[id], .project-hero[id]");
    bindActiveNavigation(".gdd-toc", ".document-section[id]");

    document.querySelectorAll("[data-concept-book]").forEach(function (book) {
        const stage = book.querySelector(".book-stage");
        const pages = Array.from(book.querySelectorAll(".book-page"));
        const previousButton = book.querySelector("[data-book-previous]");
        const nextButton = book.querySelector("[data-book-next]");
        const currentStatus = book.querySelector("[data-book-current]");
        const totalStatus = book.querySelector("[data-book-total]");
        const mobileQuery = window.matchMedia("(max-width: 40rem)");
        let index = 0;
        let touchStartX = 0;
        let touchStartY = 0;
        let animationTimer;

        if (!stage || !pages.length || !previousButton || !nextButton) return;

        function pageCount() {
            return mobileQuery.matches ? 1 : 2;
        }

        function lastIndex() {
            const count = pageCount();
            return Math.max(0, count === 1 ? pages.length - 1 : Math.ceil(pages.length / 2) * 2 - 2);
        }

        function normalizeIndex() {
            if (pageCount() === 2 && index % 2 !== 0) index -= 1;
            index = Math.max(0, Math.min(index, lastIndex()));
        }

        function render(direction) {
            normalizeIndex();
            const count = pageCount();

            window.clearTimeout(animationTimer);
            stage.classList.remove("turn-next", "turn-previous");
            void stage.offsetWidth;
            if (direction && !reducedMotion.matches) {
                stage.classList.add(direction === "next" ? "turn-next" : "turn-previous");
                animationTimer = window.setTimeout(function () {
                    stage.classList.remove("turn-next", "turn-previous");
                }, 450);
            }

            pages.forEach(function (page, pageIndex) {
                const isVisible = pageIndex >= index && pageIndex < index + count;
                page.classList.toggle("is-visible", isVisible);
                page.classList.remove("is-left", "is-right");
                page.setAttribute("aria-hidden", String(!isVisible));

                if (isVisible) {
                    page.classList.add(count === 1 || pageIndex === index ? "is-left" : "is-right");
                }
            });

            previousButton.disabled = index === 0;
            nextButton.disabled = index >= lastIndex();

            if (currentStatus) {
                currentStatus.textContent = count === 1
                    ? String(index + 1).padStart(2, "0")
                    : String(Math.floor(index / 2) + 1).padStart(2, "0");
            }

            if (totalStatus) {
                totalStatus.textContent = count === 1
                    ? String(pages.length).padStart(2, "0")
                    : String(Math.ceil(pages.length / 2)).padStart(2, "0");
            }

            book.setAttribute("aria-label", count === 1
                ? "Concept page " + (index + 1) + " of " + pages.length
                : "Concept spread " + (Math.floor(index / 2) + 1) + " of " + Math.ceil(pages.length / 2));
        }

        function next() {
            if (index >= lastIndex()) return;
            index += pageCount();
            render("next");
        }

        function previous() {
            if (index <= 0) return;
            index -= pageCount();
            render("previous");
        }

        previousButton.addEventListener("click", previous);
        nextButton.addEventListener("click", next);

        book.addEventListener("keydown", function (event) {
            if (event.key === "ArrowRight") {
                event.preventDefault();
                next();
            }
            if (event.key === "ArrowLeft") {
                event.preventDefault();
                previous();
            }
        });

        stage.addEventListener("touchstart", function (event) {
            if (event.touches.length !== 1) return;
            touchStartX = event.touches[0].clientX;
            touchStartY = event.touches[0].clientY;
        }, { passive: true });

        stage.addEventListener("touchend", function (event) {
            if (event.changedTouches.length !== 1) return;
            const deltaX = event.changedTouches[0].clientX - touchStartX;
            const deltaY = event.changedTouches[0].clientY - touchStartY;
            if (Math.abs(deltaX) < 48 || Math.abs(deltaX) < Math.abs(deltaY)) return;
            if (deltaX < 0) next();
            else previous();
        }, { passive: true });

        mobileQuery.addEventListener("change", function () {
            render();
        });

        render();
    });
}());
