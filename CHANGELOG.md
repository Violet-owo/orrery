# Changelog

## Unreleased

- Updates, in *Health*: choose the stable or the beta channel, check for a new version (by itself at most once a day,
  or with a button; it can be turned off) and install it with your password. Only Orrery's own package is installed,
  downloaded from its GitHub release and checked against its checksum, with `pacman -U`: the rest of the system is not
  touched. Going from a beta back to the stable channel installs the stable release; Orrery restarts by itself
- Orrery no longer watches its own files while it runs
- Works with Caelestia installed from git: the package no longer requires `caelestia-shell`, and the font is also
  taken from `~/.config/quickshell/caelestia`. The login screen still needs the AUR package, and *Login* says so

## 0.2.0

The first stable release with everything from the betas 0.1.2beta1 to 0.2.0beta4, listed below.

## 0.2.0beta4

- Scroll bars in the pages, the shortcuts, the picture chooser and every list: thin, shown while scrolling, wider under the pointer, draggable
- Desktop shortcuts (`Ctrl+K`, or *Keyboard*): every key of Caelestia, Orrery and your own hypr-user.lua, grouped
  and searchable, with your hypr-vars.lua changes, the areas Orrery took over, keys used twice, apps that are not
  installed, and active keys that come from other configuration. Read-only
- Lighter and faster: the state is read in half the time (default apps read from mimeapps.list instead of nine
  xdg-mime runs, slow parts side by side); still pictures are shown from small cached thumbnails instead of being
  decoded at full size (up to 4K); looping animations pause while Orrery's window is not the active one (0% CPU)
- Apply shows Orrery's moving logo while it works, and the bar leaves once when it is done instead of flashing back
- *Appearance*: which apps follow Caelestia's colours (window borders, terminals, GTK, Qt, Discord, Spotify, Chromium,
  Zed, fuzzel, btop and more) and the icon theme for dark and light; with Apply they take the colours at once
- *Wallpapers*, On the desktop: Caelestia's desktop clock (position, size, background, shadow) and audio bars,
  with a preview on your wallpaper
- *Bar*, Panels: weather city, clicking a notification runs its action, how long notifications stay over full screen
  apps, and the third button of the shut down menu (Hibernate, Suspend or Lock: Hibernate does nothing without swap)
- *Login*: switches from SDDM (or another login manager) to greetd at the next boot, and back
- *Health*: when Qt is updated, says that Quickshell must be rebuilt and gives the command, with `aur/` so that
  repository packages claiming to be quickshell-git (noctalia-qs) are never picked
- Spotify, in *Default apps*: whether spicetify is applied (and a check in *Health* for when a Spotify update removes it),
  apply and restore, Spotify following Caelestia's colours (your previous theme comes back when you turn it off),
  colours changing live in the Spotify area, and spicetify's own extensions. Only spicetify's commands are used;
  if spicetify or Spotify are missing, Orrery gives you the command to install them

## 0.2.0beta3

- GIFs and pictures, in *Wallpapers*: the animations Caelestia shows for media and in the shut down menu, and the
  pictures with no notifications, with a live preview and their speed. Choose them from your files, or search GIPHY
  stickers with a free key of your own: Orrery shows how to create it. Stickers with a background are marked and
  cannot be used; the ones you choose are kept in Orrery's folder for you alone
- The picture chooser opens like Caelestia's lock screen, with Orrery's moving logo while GIPHY loads; only the
  animations you can see play
- *Caelestia's originals*: keeps a copy of Caelestia's own pictures and puts everything back in one go
- New dependency: `python-pillow`, to check that a picture has no background

## 0.2.0beta2

- Bar, a new page (`Ctrl+3`): order of the blocks, spaces between them, the screens that show the bar, and the volume
  and brightness indicators (microphone too, and how long they stay). Pages after it move by one; *Health* is `Ctrl+0`
- Power: low battery warnings at the levels you choose, and when Caelestia hibernates on an almost empty battery,
  with a warning when the computer cannot hibernate
- Undo restores only the keys of shell.json that Orrery changed

## 0.2.0beta1

- Power, a new page: when to lock, turn the screen off and suspend, with separate times on battery and while charging,
  staying awake during playback or while charging, and locking before suspending. *Health* is now `Ctrl+9`
- Rows of your own in Caelestia's idle list are kept, and undo restores only what Orrery changed there

## 0.1.2beta2

- Login on several monitors: the lock is shown whole on every screen instead of being stretched across them.
  Typing is mirrored; mouse and buttons work on the first screen

## 0.1.2beta1

- Areas reopen exactly where they were left: apps whose window name differs from the desktop entry (Telegram on Wayland)
  were started again at every opening and took the focus
- Window names are matched in any case

## 0.1.1

- Credits, portfolio and source links in *Health → About*
- Installation from the GitHub release

## 0.1.0

First release.

- Areas: shortcuts, apps, several workspaces, arrow navigation, animations
- Keyboard: layouts, switch shortcut, Num Lock, repeat
- Default apps, including Caelestia's shortcuts
- Wallpapers: folder setup without restarting the shell, two wallpapers
- Keyboard backlight at boot and Caelestia's lock screen as login (experimental)
- Appearance, search, full keyboard control, English and Italian
