# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Jekyll static site for Jacob Maskell-Key (musician/composer, member of Nihiloxica). Built to be hosted on GitHub Pages. The repo is owned/managed by the developer (not Jacob); Jacob is intended to be added as a GitHub collaborator and edit content through a Decap CMS admin panel once that's set up (not yet implemented — see "Planned: Decap CMS" below).

## Commands

Install dependencies and run the local dev server:

```bash
bundle install
bundle exec jekyll serve
```

Site is served at `http://127.0.0.1:4000/`. Jekyll auto-rebuilds on file save — just refresh the browser, no restart needed (except after editing `_config.yml`, which requires restarting `jekyll serve`).

There is no test suite, linter, or build step beyond Jekyll's own build.

## Architecture

**Page = content, not layout.** Every top-level `*.html` file (e.g. `discography.html`, `gigs.html`) is a thin page: Jekyll front matter (`layout: default`, `permalink: ...`) plus a `{% for %}` loop over `site.data.*` pulling in a shared `_includes/*.html` component. Adding a new entry (an album, a gig, a video, a press mention) never means editing a page template — it means adding a row to the matching file in `_data/`.

**`_data/*.yml` is the content layer.** Each YAML file is a flat list of records matching one content type:
- `discography.yml`, `remixes.yml` — band/album/year/image/link (rendered via `_includes/album-card.html`)
- `gigs.yml` — status (upcoming/past)/year/date/city/venue/project (rendered via `_includes/gig-row.html`)
- `music_videos.yml` — title/youtube_id/description/credits (rendered via `_includes/video-card.html`)
- `press.yml` — publication/title/url (rendered via `_includes/press-card.html`, which auto-fetches the article's `og:image` live via the Microlink API rather than storing a local image)

**One shared layout, one shared stylesheet.** `_layouts/default.html` wraps every page with `_includes/navbar.html` + `<main>` + `_includes/footer.html`, and loads `assets/css/main.css` — there is no per-page CSS. All design tokens (colors, fonts, spacing) are CSS custom properties defined once at the top of `main.css` under `:root`; reuse those (`var(--color-heading)`, `var(--size-body)`, etc.) rather than hardcoding values, since this keeps the whole site's styling centrally adjustable.

**`.wrapper` must keep `width: 100%`.** `body` is `display: flex; flex-direction: column` (for a sticky footer) and `.wrapper` is centered with `max-width` + `margin: 0 auto`. Flexbox auto-margins stop stretching a child to the container width, so without the explicit `width: 100%` on `.wrapper`, its size silently becomes shrink-to-fit based on each page's content — causing the navbar to shift position from page to page. If this regresses, that's almost certainly why.

**Design system, from the original Figma spec:**
- Font: `Bricolage Grotesque` (headings/UI) — loaded via Google Fonts in `main.css`
- Colors: `#000831` deep indigo (headings/primary UI), `#EA1B1B` red (links, accents), `#6B6B6B` muted gray (secondary text), `#E1E1E1` page background
- Icons: Font Awesome, loaded via CDN `<link>` in `_layouts/default.html` — use `<i class="fa-solid fa-...">` / `<i class="fa-brands fa-...">` classes directly in markup, no local icon files

**Responsive breakpoints used throughout `main.css`:** `900px` (3→2 column grids), `760px` (navbar/nav stacking), `600px` (single-column grids, mobile button/card layout changes). Match these rather than introducing new breakpoints.

## Planned: Decap CMS

Not yet implemented. The plan is to add a git-based CMS (Decap CMS) at `/admin` so Jacob can edit `_data/*.yml` content and upload images through a form UI instead of editing YAML/pushing commits directly. This requires a GitHub OAuth app whose callback URL depends on the final GitHub Pages URL, so it should be set up *after* the site is deployed, not before.
