# Quick Steam for Omarchy

Your Steam library one key away, and what Steam is doing right now, in the
Omarchy bar.

The bar shows the Steam icon. While Steam downloads a game, updates one,
fetches Workshop items or pre-compiles shaders, the icon takes your theme's
accent colour and shows the percentage. Open the panel and you get the whole
picture, plus your library with ProtonDB ratings, the Proton version of each
game and the free space left on every Steam library.

## What you get

- **In the bar:** the Steam icon, with a percentage and a thin progress line
  while something is going on. While you play, the game's banner takes the
  icon's place and the tooltip says for how long. Left click opens the panel,
  middle click opens Big Picture, right click opens the Steam library.
- **Activity:**
  - downloads and updates with size, speed and time left;
  - Workshop downloads with how many items are coming;
  - shader pre-caching with its percentage, whether it runs in the
    background or before a game launches, and how many games are queued.
- **Library:**
  - installed and not installed games, read from your Steam licences, so
    games Steam has never downloaded are listed too, while refunded games
    and expired free weekends are left out;
  - games you hid in Steam stay out of the list and the search, as they do
    in Steam's library, unless you turn on "Hidden games" in the settings;
  - search, and sorting by recent, name or size;
  - covers.
- **Details** of the selected game:
  - cover;
  - ProtonDB rating and the Proton version Steam will use;
  - Steam Deck status, review score and genres;
  - playtime and when you last played;
  - the store description.
- **Free space** on every Steam library, at the bottom of the panel.
- **Install and uninstall without Steam's dialogs:** you pick the library
  in the panel, in the free space row, and confirm uninstalls there too.
- **Notifications:**
  - a game installed from the panel started downloading, and where;
  - a game finished installing ("Ready to play") or updating;
  - a game uninstalled from the panel is gone, and how much space it freed;
  - a game's Workshop items finished downloading;
  - Steam finished pre-compiling shaders after more than a minute in the
    background.
- **Keyboard:** everything works without a mouse (see below).
- **Settings page** (the gear, or `C`):
  - language;
  - which sections to show;
  - hidden games;
  - progress in the bar;
  - each kind of notification.
- **Languages:** English and Spanish, following the system language unless
  you pick one.

## Requirements

- Omarchy with shell plugins (tested on 4.0.5).
- Steam, the native package. The Flatpak location is detected too, but it
  hasn't been tested.
- `python3`, which Omarchy already has.

## Install

```sh
omarchy plugin add https://github.com/Rysen-Winters/omarchy-quick-steam.git --enable
```

The icon appears in the right section of the bar. Move it wherever you like:

```sh
omarchy bar move io.github.rysen-winters.quick-steam --section right --index 0
```

To open the panel from the keyboard, add a binding to
`~/.config/hypr/bindings.lua` with any free key:

```lua
o.bind("SUPER + CTRL + G", "Quick Steam", "omarchy-shell shell toggle io.github.rysen-winters.quick-steam")
```

Update or remove it like any other plugin:

```sh
omarchy plugin update io.github.rysen-winters.quick-steam
omarchy plugin remove io.github.rysen-winters.quick-steam
```

## Keys

The panel opens with the game list focused, so letters are shortcuts. Each
one only works where its button would be.

| Key | Action |
|---|---|
| `↑` `↓` `PgUp` `PgDn` `Home` `End` | Move through the list |
| `Enter` | Play the selected game, or install it |
| `P` | Play |
| `I` | Install: pick the library with `←` `→`, `Enter` installs, `Esc` or `N` cancels. With a single library it installs right away |
| `U` | Uninstall: `Y` confirms, `Esc` or `N` cancels |
| `S` | Open the game's store page |
| `L` | Open the Steam library |
| `B` | Open Big Picture |
| `F` | Change the sort order |
| `Tab` | Switch between installed and not installed |
| `/` | Search (`↓` or `Esc` goes back to the list, keeping the filter) |
| `C` | Settings |
| `Esc` | Clear the search, then close the panel |

## Settings

The settings page writes them to the widget's entry in
`~/.config/omarchy/shell.json`, so you can also set them there:

| Key | Default | What it does |
|---|---|---|
| `language` | `"auto"` | `"auto"`, `"en"` or `"es"` |
| `showActivity` | `true` | Downloads, Workshop and shaders in the panel |
| `showLibrary` | `true` | The game list. Activity or the list always stays on |
| `showDetails` | `true` | The details next to the list. Without them the panel is narrower and each row gets its own button |
| `showHidden` | `false` | The games you hid in Steam, in the list and marked Hidden |
| `showProgress` | `true` | Percentage and progress line in the bar |
| `notifyDownloads` | `true` | Notify installs and uninstalls from the panel, and finished installs, updates and Workshop downloads |
| `notifyShaders` | `true` | Notify finished shader pre-caching |

## How it works

Quick Steam only reads Steam's own files and never writes to them:
- the app manifests;
- the logs;
- `config.vdf`;
- the library folders.

Everything it does in Steam goes through `steam://` links, the same ones a
browser would use, except installing and uninstalling. Those links make Steam
ask where to install and whether to uninstall, so instead the panel asks, and
then hands Steam its own console commands (`app_install <game> <library>`,
`app_uninstall <game>`) on the `steam` command line. The launcher passes them
to the running Steam through `~/.steam/steam.pipe`, which only you can write
to, or starts Steam with them. No debugging port or anything else is opened.

- **One small background process** watches Steam. Every 2 seconds it compares
  the modification times of a few files. It only reads them, and only prints
  something, when they changed. With Steam quiet it uses about 0.03 % of one
  CPU core and around 10 MB of memory. With several monitors there is still
  just one.
- **The library** is read from local files when the panel opens (about 0.1 to
  0.2 s), and again when a download starts or ends.
- **Network access** is limited to the details and missing covers, one
  request at a time:
  - `store.steampowered.com` for the description;
  - `protondb.com` for the rating;
  - `shared.steamstatic.com` for covers your Steam folder doesn't have.

  Answers are cached in `~/.cache/quick-steam`: descriptions and covers for
  30 days, ProtonDB ratings for 3.
- **Steam and its games** are started through `uwsm-app` when it is there,
  so they run in their own scope like anything else you launch in Omarchy.

## Known limits

- **Steam comes forward on install and uninstall:** when Steam is running,
  every command it gets opens its window (even if it was closed to the tray)
  and takes the focus, so the panel closes. When Steam was closed, it starts
  without a window.
- **Flatpak Steam:** the commands need the native `steam` launcher, so with
  the Flatpak installing and uninstalling still go through Steam's dialogs.
- **Uninstalling a game while it downloads:** Steam cancels the download,
  deletes the files and reports the game uninstalled, but sometimes writes
  its manifest back as a paused install. The list keeps showing it as queued
  until Steam restarts and it is uninstalled again. Quick Steam notifies when
  a game is still there half a minute after uninstalling it.
- **Paused downloads:** Steam has no link that resumes one. "Resume in Steam"
  opens Steam's Downloads page instead.
- **Progress:** Steam doesn't update its files while it downloads, so the
  percentage comes from what has been written to disk. It follows Steam's own
  number closely, but not to the byte.
- **Very short Workshop downloads:** one that starts and finishes in under
  two seconds (a single small item) can go unseen, and then it doesn't notify.

## License

[MIT](LICENSE)
