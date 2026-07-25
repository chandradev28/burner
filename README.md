# Burner 🔥

A movies & TV shows streaming app built with **Flutter**, styled after the **HBO Max** UI, and powered by the **Stremio addon protocol** for catalogs, metadata, search, and streams.

## Features

- **HBO Max style UI** — near-black theme, purple/blue brand gradient, hero carousel, horizontal content rails, immersive detail pages.
- **Stremio addon support** — install any Stremio addon by its `manifest.json` URL (also accepts `stremio://` links).
  - Catalogs (`/catalog/{type}/{id}.json`) power the Home screen rails and hero carousel.
  - Metadata (`/meta/{type}/{id}.json`) powers detail pages, seasons & episodes.
  - Search (catalog `search` extra) powers the Search screen across all addons.
  - Streams (`/stream/{type}/{id}.json`) are aggregated from every installed addon and shown in a stream picker sheet.
- **Built-in video player** — `video_player` + `chewie` with fullscreen, seek, playback speed, resume-from-position, and screen wakelock.
- **My List (watchlist)** — add/remove any movie or show, persisted locally.
- **Continue Watching** — playback progress is saved automatically and shown with progress bars; resume with one tap.
- **Series support** — season picker, episode list with thumbnails and overviews, per-episode stream resolution (`id:season:episode`).
- **Addon manager** — view installed addons (name, version, capabilities), add new ones, remove any addon.
- Ships with **Cinemeta** (Stremio's official metadata addon) pre-installed so the app works out of the box.

## Project structure

```
lib/
  main.dart                 # App entry, providers, MaterialApp
  core/
    theme.dart              # HBO Max style dark theme + brand gradient
    constants.dart          # Defaults (bundled addons, limits)
  models/
    addon.dart              # Addon, manifest, resources, catalogs
    meta.dart               # MetaItem (movie/series) + Video (episode)
    stream_item.dart        # Stream results from addons
  services/
    addon_client.dart       # Stremio addon protocol HTTP client
    storage_service.dart    # SharedPreferences wrapper
  providers/
    addon_provider.dart     # Installed addons state
    catalog_provider.dart   # Home rails + hero items
    library_provider.dart   # Watchlist + continue watching
  screens/
    splash_screen.dart      # Boot + data init
    main_shell.dart         # Bottom navigation shell
    home_screen.dart        # Hero carousel + catalog rails
    search_screen.dart      # Debounced cross-addon search
    detail_screen.dart      # Movie/series detail, seasons, episodes
    player_screen.dart      # Chewie video player w/ resume
    library_screen.dart     # Continue Watching + My List
    addons_screen.dart      # Addon manager
    profile_screen.dart     # Profile & settings
  widgets/
    common.dart             # Gradient text/button, loading pulse
    hero_carousel.dart      # Auto-advancing featured carousel
    content_row.dart        # Horizontal poster rail
    poster_card.dart        # Poster tile
    episode_tile.dart       # Episode row item
    stream_sheet.dart       # Stream picker bottom sheet
```

## Getting started

1. Make sure Flutter (3.19+) is installed.
2. From this folder, generate the platform scaffolding (android/ios/etc.):

   ```bash
   flutter create . --project-name burner --org com.burner.app
   flutter pub get
   ```

3. Run it — internet permissions for Android and iOS are already configured (see [Internet & permissions](#internet--permissions) below):

   ```bash
   flutter run
   ```

## Adding addons

Go to **Profile → Manage addons** (or the puzzle icon on Home) and paste any Stremio addon manifest URL, e.g.:

```
https://v3-cinemeta.strem.io/manifest.json
```

`stremio://` URLs are converted automatically. Addons that only return torrent `infoHash` streams (no direct URL) need a debrid/resolver addon to become playable — the app labels those accordingly.

## Disclaimer

Burner is an addon **client**. It hosts no content and ships only with Cinemeta (metadata). You are responsible for the addons you install — only use addons that serve content you have the legal right to access.

## Internet & permissions

This repo ships pre-configured platform files so all networking works out of the box after `flutter create .`:

- **Android** (`android/app/src/main/AndroidManifest.xml`)
  - `INTERNET` — addon catalogs, metadata, artwork and video streams
  - `ACCESS_NETWORK_STATE` — connectivity checks
  - `WAKE_LOCK` — keep screen on during playback
  - `FOREGROUND_SERVICE` — media playback
  - `usesCleartextTraffic="true"` — allows plain `http://` streams (some addons still serve them). Remove for https-only.
  - `<queries>` for `http`/`https` — lets url_launcher open external links on Android 11+
- **iOS** (`ios/Runner/Info.plist`)
  - `NSAppTransportSecurity > NSAllowsArbitraryLoads` — allows non-https streams
  - `UIBackgroundModes: audio` — keeps audio alive if the app is backgrounded during playback
  - `LSApplicationQueriesSchemes` — url_launcher support

> Note: `flutter create .` does not overwrite existing files, so these stay in place when you generate the platform folders. If you ever regenerate from scratch, re-apply these settings.
