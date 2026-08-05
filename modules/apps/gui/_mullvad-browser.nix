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
  pname = "mullvad-browser";
  version = "16.0a9";

  src = fetchurl {
    url = "https://dist.torproject.org/mullvadbrowser/${version}/mullvad-browser-linux-aarch64-${version}.tar.xz";
    hash = "sha256-z94GG0c1L9eZ6A1XaYkEu/CUTCn30imAa9g+6vlbWn8=";
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
    mkdir -p $out/lib/mullvad-browser $out/bin
    cp -r Browser/* $out/lib/mullvad-browser/

    cat <<'EOF' > $out/bin/mullvad-browser
    #!/bin/sh
    exec $(dirname $0)/../lib/mullvad-browser/mullvadbrowser.real "$@"
    EOF
    chmod +x $out/bin/mullvad-browser
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
