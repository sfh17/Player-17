#!/bin/sh
# Builds the Player-17 packages in the current folder, from the same files:
#   player-17_<version>_amd64.deb          Ubuntu / Zorin / Debian
#   player-17-<version>-1.x86_64.rpm       Fedora        (needs rpmbuild:  sudo apt install rpm)
#   player-17-<version>-1-x86_64.pkg.tar.* Arch / Manjaro
# Run it from anywhere on Ubuntu 24.04 / Zorin 18 (or newer), with internet:
#     sh packaging/deb/build-deb.sh
# Install:  sudo apt install ./player-17_*_amd64.deb   |   sudo dnf install ./player-17-*.rpm
#           sudo pacman -U ./player-17-*.pkg.tar.*
# Remove:   sudo apt remove player-17   |   sudo dnf remove player-17   |   sudo pacman -R player-17
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
TOP=$(cd "$HERE/../.." && pwd)
ID=io.github.sfh17.Player-17
VERSION=$(sed -n 's/^APP_VERSION = "\(.*\)"/\1/p' "$TOP/app.py")
OUT="$PWD/player-17_${VERSION}_amd64.deb"

# Packages of older versions move to old-builds/, so only the current ones sit here
# (the same version is simply rebuilt over itself).
mkdir -p "$PWD/old-builds"
for f in "$PWD"/player-17_*_amd64.deb "$PWD"/player-17-*.x86_64.rpm "$PWD"/player-17-*-x86_64.pkg.tar.* "$PWD"/player-17_*_x86_64.flatpak; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
        player-17_"$VERSION"_*|player-17-"$VERSION"-*) ;;
        *) mv -f "$f" "$PWD/old-builds/" && echo "older build moved: old-builds/$(basename "$f")" ;;
    esac
done
rmdir "$PWD/old-builds" 2>/dev/null || true
WORK=$(mktemp -d)
ROOT="$WORK/root"
trap 'rm -rf "$WORK"' EXIT

echo "Player-17 $VERSION"

# --- the app ---
install -Dm644 "$TOP/app.py" "$ROOT/usr/share/player-17/app.py"
install -Dm755 "$HERE/player-17" "$ROOT/usr/bin/player-17"
install -Dm644 "$TOP/data/$ID.desktop" "$ROOT/usr/share/applications/$ID.desktop"
install -Dm644 "$TOP/data/$ID.service" "$ROOT/usr/share/dbus-1/services/$ID.service"   # the browser starts it by D-Bus
install -Dm644 "$TOP/data/$ID.metainfo.xml" "$ROOT/usr/share/metainfo/$ID.metainfo.xml"
install -Dm644 "$TOP/data/icons/$ID.svg" "$ROOT/usr/share/icons/hicolor/scalable/apps/$ID.svg"
for s in 16 32 48 64 128 256 512; do
    install -Dm644 "$TOP/data/icons/$ID-$s.png" "$ROOT/usr/share/icons/hicolor/${s}x${s}/apps/$ID.png"
done
# The same icon under the process names, so System Monitor shows the Player-17 icon next to
# "Player-17", "Player-17-BPM" and "Player-17-Export" (it looks the icon up by the process name).
for n in Player-17 Player-17-BPM Player-17-Export; do
    install -Dm644 "$TOP/data/icons/$ID.svg" "$ROOT/usr/share/icons/hicolor/scalable/apps/$n.svg"
    for s in 16 32 48 64 128 256 512; do
        install -Dm644 "$TOP/data/icons/$ID-$s.png" "$ROOT/usr/share/icons/hicolor/${s}x${s}/apps/$n.png"
    done
done
install -Dm644 "$TOP/LICENSE" "$ROOT/usr/share/doc/player-17/copyright"

# --- pedalboard (VST3 hosting): not in apt, so a copy goes into the package ---
if ! python3 -m pip --version >/dev/null 2>&1; then
    echo "pip is needed to fetch pedalboard:  sudo apt install python3-pip"
    exit 1
fi
VST=yes
# every Python a supported distro may have (Ubuntu 26.04 = 3.14); PB_PYS="..." to change
for PY in ${PB_PYS:-3.12 3.13 3.14 3.15}; do
    DL="$WORK/wheel-$PY"
    if python3 -m pip download pedalboard --no-deps --only-binary=:all: \
            --python-version "$PY" --platform manylinux_2_28_x86_64 \
            --platform manylinux_2_17_x86_64 --platform manylinux2014_x86_64 \
            -d "$DL" -q 2>/dev/null; then
        mkdir -p "$ROOT/usr/lib/player-17/python$PY"
        python3 -m zipfile -e "$DL"/pedalboard-*.whl "$ROOT/usr/lib/player-17/python$PY"
        echo "  pedalboard for Python $PY: added"
    else
        echo "  pedalboard for Python $PY: could not download (VST3 off for that Python)"
        VST=no
    fi
done
find "$ROOT/usr/lib/player-17" -name "*.so" -exec strip --strip-unneeded {} \; 2>/dev/null || true

# --- package info ---
# Permissions: the build folder may be group-writable (umask 002 = 775): in the package every
# folder must be 755 and no file writable by others (also a security matter)
find "$ROOT" -type d -exec chmod 755 {} +
find "$ROOT" -type f -exec chmod go-w {} +
python3 "$(dirname "$0")/check-libs.py" "$ROOT"
SIZE=$(du -sk "$ROOT" | cut -f1)
mkdir -p "$ROOT/DEBIAN"
cat > "$ROOT/DEBIAN/control" << CONTROL
Package: player-17
Version: $VERSION
Architecture: amd64
Maintainer: sfh17 <sfh17arm@gmail.com>
Installed-Size: $SIZE
Section: sound
Priority: optional
Homepage: https://github.com/sfh17/Player-17
Depends: python3 (>= 3.12), python3-gi, python3-gi-cairo, python3-gst-1.0, gir1.2-secret-1,
 gir1.2-gtk-4.0, gir1.2-adw-1 (>= 1.4), gir1.2-gstreamer-1.0, gir1.2-gst-plugins-base-1.0,
 gstreamer1.0-plugins-base, gstreamer1.0-plugins-good, gstreamer1.0-plugins-bad,
 gstreamer1.0-pulseaudio, python3-mutagen, python3-numpy, libatomic1
Recommends: gstreamer1.0-libav, gstreamer1.0-plugins-ugly, gstreamer1.0-gtk4, python3-aubio, ffmpeg,
 python3-pyqt6.qtwebengine, libqt6svg6, gir1.2-webkit-6.0
Conflicts: plyer-17
Replaces: plyer-17
Suggests: lsp-plugins-lv2, x42-plugins, calf-plugins
Description: music and video player with VST3/LV2 effects
 Player-17 plays music (MP3, FLAC, ALAC, OGG, Opus, WAV...) and video.
 It has a parametric equalizer (Prism EQ) with a live spectrum,
 hosts VST3 and LV2 effects, detects BPM, changes tempo with
 Master Tempo, records internet radio and exports tracks and
 videos with all effects applied.
CONTROL

dpkg-deb --root-owner-group -Zxz --build "$ROOT" "$OUT" >/dev/null
echo "Done: $OUT"

# The same files without the .deb's own folder, for the other packages
STAGE="$WORK/stage"
mkdir -p "$STAGE"
cp -a "$ROOT/." "$STAGE/"
rm -rf "$STAGE/DEBIAN"

# --- .rpm (Fedora) ---
# Fedora has no AAC decoder and no gtk4 video sink by default: radio played silence and the
# video window could not draw fast without gstreamer1-plugin-libav / gstreamer1-plugin-gtk4.
if command -v rpmbuild >/dev/null 2>&1; then
    R="$WORK/rpm"
    mkdir -p "$R/BUILD" "$R/RPMS" "$R/SPECS" "$R/SOURCES" "$R/SRPMS"
    cat > "$R/SPECS/player-17.spec" << SPEC
Name: player-17
Version: $VERSION
Release: 1
Summary: Music and video player with VST3/LV2 effects
License: GPL-3.0-or-later
URL: https://github.com/sfh17/Player-17
AutoReqProv: no
Requires: python3, python3-gobject, python3-cairo, python3-gstreamer1, gtk4, libadwaita, libsecret,
Requires: gstreamer1-plugins-base, gstreamer1-plugins-good, gstreamer1-plugins-bad-free,
Requires: gstreamer1-plugin-libav, gstreamer1-plugin-gtk4, python3-mutagen, python3-numpy, libatomic
Recommends: ffmpeg-free, python3-aubio
Suggests: lsp-plugins-lv2, x42-plugins, calf-plugins
%description
Player-17 plays music and video, with a parametric equalizer (Prism EQ), VST3 and LV2
effects, BPM detection, Master Tempo, internet radio recording and export with effects.
%install
cp -a "$STAGE"/. %{buildroot}/
%files
/usr/bin/player-17
/usr/share/player-17
/usr/lib/player-17
/usr/share/applications/$ID.desktop
/usr/share/dbus-1/services/$ID.service
/usr/share/metainfo/$ID.metainfo.xml
/usr/share/icons/hicolor/*/apps/$ID.*
/usr/share/icons/hicolor/*/apps/Player-17*.*
/usr/share/doc/player-17
SPEC
    sed -i 's/^Requires: \(.*\),$/Requires: \1/' "$R/SPECS/player-17.spec"
    rpmbuild --quiet --define "_topdir $R" --define "_build_id_links none" --define "__strip /bin/true" \
             --target x86_64 -bb "$R/SPECS/player-17.spec"
    cp "$R"/RPMS/*/*.rpm "$PWD/"
    echo "Done: $PWD/$(basename "$R"/RPMS/*/*.rpm)"
else
    echo "(no rpmbuild: the .rpm is skipped — sudo apt install rpm)"
fi

# --- Arch / Manjaro ---
rm -f "$PWD"/player-17-"$VERSION"-1-*.pkg.tar.*
python3 "$HERE/mkarchpkg.py" "$STAGE" "$PWD" player-17 "$VERSION" x86_64 \
    "Music and video player with VST3/LV2 effects" "https://github.com/sfh17/Player-17" \
    python python-gobject python-cairo gst-python gtk4 libadwaita libsecret gst-plugins-base \
    gst-plugins-good gst-plugins-bad gst-libav gst-plugin-gtk4 python-mutagen python-numpy gcc-libs
echo "Done: Arch package in $PWD"
[ "$VST" = yes ] || echo "Note: built without some pedalboard copies (no internet?)."
