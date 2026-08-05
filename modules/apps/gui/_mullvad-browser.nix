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
    patchelf --set-interpreter "$interpreter" $out/lib/mullvad-browser/mullvadbrowser.real

    makeWrapper $out/lib/mullvad-browser/mullvadbrowser.real $out/bin/mullvad-browser \
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
