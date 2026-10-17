# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Jekyll static site for Jacob Maskell-Key (musician/composer, member of Nihiloxica), live at **https://jacobmkey.work**. Hosted on GitHub Pages (custom domain, HTTPS enforced), deployed via GitHub Actions. The repo is owned/managed by the developer; Jacob (`jacobmkey` on GitHub) is a collaborator with push access and edits content day-to-day through **Pages CMS** (pagescms.org) rather than touching YAML/Jekyll directly.

## Commands

Install dependencies and run the local dev server:

```bash
bundle install
bundle exec jekyll serve
```

Site is served at `http://127.0.0.1:4000/`. Jekyll auto-rebuilds on file save — just refresh the browser, no restart needed (except after editing `_config.yml`, which requires restarting `jekyll serve`).

There is no test suite, linter, or build step beyond Jekyll's own build.

## Architecture

**Page = content, not layout.** Every top-level `*.html` file (e.g. `discography.html`, `gigs.html`) is a thin page: Jekyll front matter (`layout: default`, `permalink: ...`) plus a `{% for %}` loop over `site.data.*` pulling in a shared `_includes/*.html` component. Adding a new entry (an album, a gig, a video, a press mention) never means editing a page template — it means adding a row to the matching file in `_data/`, normally done through Pages CMS rather than by hand.

**`_data/*.yml` is the content layer.** Each YAML file is a flat list of records matching one content type:
- `discography.yml`, `remixes.yml` — band/album/label/year/image/link (rendered via `_includes/album-card.html`). `label` is the record label and is optional — only rendered if present.
- `gigs.yml` — **date** (single ISO `YYYY-MM-DD`, e.g. `"2026-11-14"`)/city/venue/project/link (rendered via `_includes/gig-row.html`). There is **no manual status field** — `gig-row.html` derives Upcoming/Past at build time by comparing `date` to `site.time`. This only updates when the site rebuilds, which is why the Pages workflow has a daily cron trigger (see Deployment below).
- `music_videos.yml`, `commisions.yml` — title/youtube_id/description/credits (rendered via `_includes/video-card.html` / `_includes/commission-card.html`). `credits` **must be a real YAML list** of short strings (one per line, e.g. `"Composition: Jacob Maskell-Key"`), not a single string — see the Pages CMS gotcha below if this breaks again.
- `press.yml` — publication/title/url (rendered via `_includes/press-card.html`, which auto-fetches the article's `og:image` live via the Microlink API rather than storing a local image)
- `live_projects.yml` — name/image/link (rendered via `_includes/band-card.html`, opens in a new tab)
- `about.yml` — single `bio` field, written as **Markdown** (not HTML), rendered via `markdownify` on `about.html`. Links inside it are forced to `target="_blank"` by a small script, since Markdown links don't carry that attribute.
- `home.yml` — `hero_left` / `hero_right`, the two homepage hero media paths (gif/image).

**One shared layout, one shared stylesheet.** `_layouts/default.html` wraps every page with `_includes/navbar.html` + `<main>` + `_includes/footer.html`, and loads `assets/css/main.css` — there is no per-page CSS. All design tokens (colors, fonts, spacing) are CSS custom properties defined once at the top of `main.css` under `:root`; reuse those (`var(--color-heading)`, `var(--size-body)`, etc.) rather than hardcoding values, since this keeps the whole site's styling centrally adjustable.

**`.wrapper` must keep `width: 100%`.** `body` is `display: flex; flex-direction: column` (for a sticky footer) and `.wrapper` is centered with `max-width` + `margin: 0 auto`. Flexbox auto-margins stop stretching a child to the container width, so without the explicit `width: 100%` on `.wrapper`, its size silently becomes shrink-to-fit based on each page's content — causing the navbar to shift position from page to page. If this regresses, that's almost certainly why.

**Design system, from the original Figma spec:**
- Font: `Bricolage Grotesque` (headings/UI) — loaded via Google Fonts in `main.css`
- Colors: `#000831` deep indigo (headings/primary UI), `#EA1B1B` red (links, accents), `#6B6B6B` muted gray (secondary text), `#E1E1E1` page background
- Icons: Font Awesome, loaded via CDN `<link>` in `_layouts/default.html` — use `<i class="fa-solid fa-...">` / `<i class="fa-brands fa-...">` classes directly in markup, no local icon files
- Navbar social icons (`.navbar__social-icon`) use a circular brand-color sweep-up hover effect (Instagram gradient, LinkedIn blue), transparent by default — see `main.css` around `.navbar__social-icon`.

**Responsive breakpoints used throughout `main.css`:** `900px` (3→2 column grids), `760px` (navbar/nav stacking, About page gif/text stacking), `600px` (single-column grids, mobile button/card layout changes). Match these rather than introducing new breakpoints.

**Hover-grow buttons (Listen/Send) never reflow layout.** `.listen-btn` and `.send-btn` expand on hover to reveal a text label. For `.listen-btn` specifically, it sits inside a `.listen-btn-slot` wrapper that always reserves the button's *expanded* width, so hovering never pushes or overlaps the album title next to it. The hover-grow effect itself is scoped to `@media (hover: hover) and (pointer: fine)` so touch devices (which fake `:hover` on tap) don't trigger a tap-animation — mobile instead shows the full-width static button with the label always visible.

## Content Management: Pages CMS

Jacob edits content at **https://app.pagescms.org**, signed in with his own GitHub account (`jacobmkey`, added as a repo collaborator with push access). No OAuth app or separate auth server is needed — Pages CMS's own hosted GitHub App handles login, scoped to this repo.

**Config file:** `.pages.yml` at the repo root defines every editable collection (Discography, Remixes, Gigs, Watch/Watch, Commissions, Press, Live Projects, About, Home Page) and the media upload location (`assets/images/uploads/`, served at `/assets/images/uploads/`). Every save in the CMS is a **real commit pushed straight to `main`** — there is no draft/staging mode, so content changes go live within about a minute (GitHub Actions rebuild + redeploy).

**Pages CMS field-config gotchas (already fixed once, documented so they don't recur):**
- A field made repeatable needs `list: true` as a **direct sibling property** of `name`/`type` — not nested under `options:`. Nesting it under `options` silently falls back to a single free-text field instead of a repeatable list (this broke `credits` on Watch/Commissions once already — the CMS user types what looks like several lines, but it all gets saved as one mashed-together string with no real separation).
- The `select` field's choices go under `options.values`, with each choice using **`name`** (not `value`) + `label` — e.g. `options: { values: [{ name: upcoming, label: Upcoming }] }`. Using `options.choices` with `value`/`label` keys (a reasonable guess, but wrong) silently produces an empty dropdown.
- Since merge conflicts between local edits and CMS commits happen routinely (see below), always `git fetch && git log origin/main` and look at what actually changed before resolving — a wiped/emptied data file after a CMS save is usually a symptom of one of the above bugs, not intentional content.

**Workflow when pushing code changes:** the CMS can commit to `main` at any time (Jacob may be editing concurrently). Before `git push`, always `git fetch origin` first — if rejected, check `git log origin/main --oneline` and `git show origin/main:<file>` for what changed before merging, rather than blindly force-pushing or discarding.

## Deployment

**Custom domain:** `jacobmkey.work` (registered on GoDaddy), DNS pointed at GitHub Pages via 4 `A` records (`185.199.108.153` / `.109.153` / `.110.153` / `.111.153`) on `@`, plus a `CNAME` record on `www` → `andriusax.github.io`. The `CNAME` file at the repo root tells GitHub Pages which domain to serve. HTTPS is enforced (Let's Encrypt cert, auto-renewing).

**Build/deploy:** `.github/workflows/pages.yml` — a GitHub Actions workflow (not the legacy "Deploy from a branch" Pages builder, which pins an old Jekyll 3.9 via the `github-pages` gem and ignores this repo's own `Gemfile`). It builds with this project's actual Jekyll version (`~> 4.3`) on every push to `main`, **plus a daily cron (`5 0 * * *` UTC)** so gigs flip from Upcoming to Past automatically even on days nobody pushes a change (see the `gigs.yml` note above).

`baseurl` is intentionally left blank in `_config.yml` — local `jekyll serve` always serves at the root. The workflow passes the correct base path at build time via `--baseurl "${{ steps.pages.outputs.base_path }}"`, which resolves to empty on the custom domain and `/jacob-maskell-key-website` if ever served from the bare `github.io` project-page URL instead. `site.url` in `_config.yml` is `https://jacobmkey.work` — used by the contact form's post-submit redirect and the Open Graph/Twitter Card tags (see below).

**Any inline `style="background-image: url(...)"` or hardcoded `/assets/...` path must go through Jekyll's `relative_url` filter**, not a bare string — a bare `/assets/...` path breaks the moment the site is served from a subpath (this caused a real bug on `index.html`/`live-projects.html` once already, see git history).

## Contact form

`contact.html` posts to FormSubmit (`https://formsubmit.co/<email>`), currently Jacob's real inbox. Hidden fields: `_next` (redirects to `thank-you.html` instead of FormSubmit's branded page — uses `absolute_url`, so it depends on `site.url` being correct), `_subject` (fixed subject line), `_captcha: false` (skips FormSubmit's reCAPTCHA step). **Any brand-new destination email requires a one-time "Activate Form" click** sent by FormSubmit to that inbox before real submissions deliver — already done for the current address.

## SEO / link previews

`_layouts/default.html` uses `jekyll-seo-tag`'s `{% seo %}` tag (not hand-rolled `<title>`/`<meta description>`) to generate Open Graph + Twitter Card tags and JSON-LD. Every page gets a default preview image via the `image:` front-matter default in `_config.yml`'s `defaults:` block (currently the favicon photo) — override per-page with that page's own `image:` front matter if a specific page needs a different preview image.

## Known outstanding content (not code) TODOs

- Homepage hero gif/image (`_data/home.yml`) still point at dev placeholder files (a test photo and an abstract render) — real ones need uploading via Pages CMS.
- `shop.html` is still a "coming soon" stub — intentionally parked.
- Occasional test/duplicate entries from CMS experimentation (e.g. in Live Projects, Press) — Jacob is expected to clean these up himself through the CMS.
