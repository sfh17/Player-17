#!/bin/sh
# Player-17 launcher inside Flatpak (installed as /app/bin/player-17).
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
export PLAYER_SITE="/app/lib/python$PYVER/site-packages"
# The same settings as the regular (.deb) install, not a separate copy inside Flatpak: the player's
# own settings (colors, plugin chains, presets, the list of plugins that froze it), and the plugins'
# settings too (LSP keeps its window size, 200 %, in ~/.config/lsp-plugins). The cache stays apart:
# GStreamer's plugin list inside Flatpak is not the system's.
[ -d "$HOME/.config" ] && export XDG_CONFIG_HOME="$HOME/.config"
[ -d "$HOME/.local/share" ] && export XDG_DATA_HOME="$HOME/.local/share"
# The browser inside the player: the Electron that comes with the package, started through
# zypak (Chromium's sandbox inside Flatpak's sandbox). Nothing is downloaded.
export PLAYER_ELECTRON=/app/electron/electron
export PLAYER_ELECTRON_WRAPPER=/app/bin/zypak-wrapper
# Seen as "Player-17" (not "python3") in System Monitor from the very first moment: Linux names a
# process after the file it started, so python3 is started through a link called Player-17.
# The link lives in the user's own runtime folder (private to him), made fresh at each start.
# System Monitor (outside Flatpak) finds a process's icon by the process name, and Flatpak may
# only hand out icons named io.github.sfh17.Player-17*. So the same icon is copied, under the
# process names, into the user's own icon folder (only when it is missing or has changed).
ICONS="$HOME/.local/share/icons/hicolor"
for n in Player-17 Player-17-BPM Player-17-Export; do
    for s in 16 32 48 64 128 256 512; do
        SRC="/app/share/icons/hicolor/${s}x${s}/apps/io.github.sfh17.Player-17.png"
        DST="$ICONS/${s}x${s}/apps/$n.png"
        [ -f "$SRC" ] && ! cmp -s "$SRC" "$DST" 2>/dev/null && mkdir -p "${DST%/*}" && cp -f "$SRC" "$DST" 2>/dev/null
    done
    SRC=/app/share/icons/hicolor/scalable/apps/io.github.sfh17.Player-17.svg
    DST="$ICONS/scalable/apps/$n.svg"
    [ -f "$SRC" ] && ! cmp -s "$SRC" "$DST" 2>/dev/null && mkdir -p "${DST%/*}" && cp -f "$SRC" "$DST" 2>/dev/null
done
PY=$(command -v python3)
RUN="${XDG_RUNTIME_DIR:-$HOME/.cache}/player-17"
if mkdir -p "$RUN" 2>/dev/null && ln -sfn "$PY" "$RUN/Player-17" 2>/dev/null && [ -x "$RUN/Player-17" ]; then
    PY="$RUN/Player-17"
fi
exec "$PY" /app/share/player-17/app.py "$@"
