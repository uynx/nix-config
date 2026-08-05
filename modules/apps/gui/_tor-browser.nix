{
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  alsa-lib,
  dbus,
  fontconfig,
  freetype,
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
  nspr,
  nss,
  pango,
}:

stdenv.mkDerivation rec {
  pname = "tor-browser";
  version = "16.0a9";

  src = fetchurl {
    url = "https://dist.torproject.org/torbrowser/${version}/tor-browser-linux-aarch64-${version}.tar.xz";
    hash = "sha256-/7CYkO6QSB/6fbWGU2ru9dkfcQZcowOLoLFSVqQb2u0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = [
    alsa-lib
    dbus
    fontconfig
    freetype
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
    nspr
    nss
    pango
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/tor-browser $out/bin
    cp -r Browser/* $out/lib/tor-browser/

    cat <<'EOF' > $out/bin/tor-browser
    #!/bin/sh
    exec $(dirname $0)/../lib/tor-browser/firefox "$@"
    EOF
    chmod +x $out/bin/tor-browser
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
