{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  makeWrapper,
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

let
  libPath = lib.makeLibraryPath [
    stdenv.cc.cc.lib
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
    patchelf --set-interpreter "$interpreter" $out/lib/tor-browser/firefox.real

    makeWrapper $out/lib/tor-browser/firefox.real $out/bin/tor-browser \
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
