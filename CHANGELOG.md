# Changelog

## Unreleased

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
