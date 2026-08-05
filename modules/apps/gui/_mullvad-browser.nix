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
  pname = "mullvad-browser";
  version = "16.0a9";

  src = fetchurl {
    url = "https://dist.torproject.org/mullvadbrowser/${version}/mullvad-browser-linux-aarch64-${version}.tar.xz";
    hash = "sha256-z94GG0c1L9eZ6A1XaYkEu/CUTCn30imAa9g+6vlbWn8=";
  };

  nativeBuildInputs = [
    patchelf
    makeWrapper
    copyDesktopItems
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/mullvad-browser $out/bin
    cp -r Browser/* $out/lib/mullvad-browser/

    interpreter=$(cat ${stdenv.cc}/nix-support/dynamic-linker)
    for b in mullvadbrowser.real glxtest vaapitest vulkantest abicheck updater; do
      if [ -f "$out/lib/mullvad-browser/$b" ]; then
        patchelf --set-interpreter "$interpreter" "$out/lib/mullvad-browser/$b" 2>/dev/null || true
      fi
    done

    cat <<'EOF' > $out/bin/mullvad-browser
#!/bin/sh
PROFILE_DIR="$HOME/.local/share/mullvad-browser/profile.default"
mkdir -p "$PROFILE_DIR"
BASE_DIR="$(dirname $(readlink -f $0))/../lib/mullvad-browser"
if [ ! -f "$PROFILE_DIR/prefs.js" ] && [ -d "$BASE_DIR/MullvadBrowser/Data/Browser/profile.default" ]; then
  cp -rn "$BASE_DIR/MullvadBrowser/Data/Browser/profile.default/"* "$PROFILE_DIR/" 2>/dev/null || true
fi
exec "$BASE_DIR/mullvadbrowser.real" --profile "$PROFILE_DIR" "$@"
EOF
    chmod +x $out/bin/mullvad-browser

    wrapProgram $out/bin/mullvad-browser \
      --prefix LD_LIBRARY_PATH : "$out/lib/mullvad-browser:${libPath}"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "mullvad-browser";
      exec = "mullvad-browser %u";
      icon = "mullvad-browser";
      desktopName = "Mullvad Browser";
      genericName = "Web Browser";
      categories = [
        "Network"
        "WebBrowser"
      ];
    })
  ];
}
