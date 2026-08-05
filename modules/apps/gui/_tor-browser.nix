{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  alsa-lib,
  atk,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libGL,
  libX11,
  libxcb,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXrandr,
  libXrender,
  libxkbcommon,
  libxshmfence,
  nspr,
  nss,
  pango,
  pciutils,
  pipewire,
  udev,
  vulkan-loader,
  wayland,
}:

let
  libPath = lib.makeLibraryPath [
    stdenv.cc.cc.lib
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libGL
    libX11
    libxcb
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libxkbcommon
    libxshmfence
    nspr
    nss
    pango
    pciutils
    pipewire
    udev
    vulkan-loader
    wayland
  ];
in
stdenv.mkDerivation rec {
  pname = "tor-browser";
  version = "16.0a9";

  src = fetchurl {
    url = "https://dist.torproject.org/torbrowser/${version}/tor-browser-linux-aarch64-${version}.tar.xz";
    hash = "sha256-/7CYkO6QSB/6fbWGU2ru9dkfcQZcowOLoLFSVqQb2u0=";
  };

  nativeBuildInputs = [
    patchelf
    makeWrapper
    copyDesktopItems
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/tor-browser $out/bin
    cp -r Browser/* $out/lib/tor-browser/

    interpreter=$(cat ${stdenv.cc}/nix-support/dynamic-linker)
    for b in firefox.real glxtest vaapitest vulkantest abicheck updater; do
      if [ -f "$out/lib/tor-browser/$b" ]; then
        patchelf --set-interpreter "$interpreter" "$out/lib/tor-browser/$b" 2>/dev/null || true
      fi
    done

    cat <<'EOF' > $out/bin/tor-browser
#!/bin/sh
PROFILE_DIR="$HOME/.local/share/tor-browser/profile.default"
mkdir -p "$PROFILE_DIR"
BASE_DIR="$(dirname $(readlink -f $0))/../lib/tor-browser"
if [ ! -f "$PROFILE_DIR/prefs.js" ] && [ -d "$BASE_DIR/TorBrowser/Data/Browser/profile.default" ]; then
  cp -rn "$BASE_DIR/TorBrowser/Data/Browser/profile.default/"* "$PROFILE_DIR/" 2>/dev/null || true
fi
exec "$BASE_DIR/firefox.real" --profile "$PROFILE_DIR" "$@"
EOF
    chmod +x $out/bin/tor-browser

    wrapProgram $out/bin/tor-browser \
      --prefix LD_LIBRARY_PATH : "$out/lib/tor-browser:${libPath}"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "tor-browser";
      exec = "tor-browser %u";
      icon = "tor-browser";
      desktopName = "Tor Browser";
      genericName = "Web Browser";
      categories = [
        "Network"
        "WebBrowser"
      ];
    })
  ];
}
