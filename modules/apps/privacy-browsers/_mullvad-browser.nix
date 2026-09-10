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
  pin = (builtins.fromJSON (builtins.readFile ./pins.json)).mullvad-browser;
in
stdenv.mkDerivation rec {
  pname = "mullvad-browser";
  inherit (pin) version;

  src = fetchurl {
    url = "https://dist.torproject.org/mullvadbrowser/${version}/mullvad-browser-linux-aarch64-${version}.tar.xz";
    inherit (pin) hash;
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

    touch $out/lib/mullvad-browser/is-packaged-app

    interpreter=$(cat ${stdenv.cc}/nix-support/dynamic-linker)
    for b in mullvadbrowser.real glxtest vaapitest vulkantest abicheck updater; do
      if [ -f "$out/lib/mullvad-browser/$b" ]; then
        patchelf --set-interpreter "$interpreter" "$out/lib/mullvad-browser/$b" 2>/dev/null || true
      fi
    done

    fontsConf=$out/lib/mullvad-browser/fonts/fonts.conf
    substituteInPlace "$fontsConf" \
      --replace-fail '<dir prefix="cwd">fonts</dir>' "<dir>$out/lib/mullvad-browser/fonts</dir>"

    makeWrapper $out/lib/mullvad-browser/mullvadbrowser $out/bin/mullvad-browser \
      --prefix LD_LIBRARY_PATH : "$out/lib/mullvad-browser:${libPath}" \
      --set FONTCONFIG_FILE "$fontsConf" \
      --set-default MOZ_ENABLE_WAYLAND 1

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
