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
  zlib,
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
    zlib
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

    # Without this marker the bundle runs in portable mode and keeps its profile
    # next to the binary, i.e. in the read-only store. With it, state goes to
    # ~/.config/"tor project".
    touch $out/lib/tor-browser/is-packaged-app

    interpreter=$(cat ${stdenv.cc}/nix-support/dynamic-linker)
    for b in firefox.real glxtest vaapitest vulkantest abicheck updater TorBrowser/Tor/tor; do
      if [ -f "$out/lib/tor-browser/$b" ]; then
        patchelf --set-interpreter "$interpreter" "$out/lib/tor-browser/$b" 2>/dev/null || true
      fi
    done

    substituteInPlace $out/lib/tor-browser/TorBrowser/Tor/torrc-defaults \
      --replace-fail './TorBrowser' "$out/lib/tor-browser/TorBrowser"

    fullLibPath="$out/lib/tor-browser:$out/lib/tor-browser/TorBrowser/Tor:${libPath}"

    makeWrapper $out/lib/tor-browser/firefox $out/bin/tor-browser \
      --prefix LD_LIBRARY_PATH : "$fullLibPath"

    # The browser spawns tor itself and reports only "unable to connect" if it
    # dies, so a missing library here is invisible at runtime.
    LD_LIBRARY_PATH="$fullLibPath" $out/lib/tor-browser/TorBrowser/Tor/tor --version > /dev/null

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
