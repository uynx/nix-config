{
  stdenv,
  fetchurl,
  dpkg,
  patchelf,
  openssl,
  gmp,
  zlib,
  lib,
  ...
}:
stdenv.mkDerivation {
  pname = "simplex-chat";
  version = "7.0.3";
  src = fetchurl {
    url = "https://github.com/simplex-chat/simplex-chat/releases/download/v7.0.3/simplex-chat-ubuntu-24_04-x86_64.deb";
    hash = "sha256-oAT7Dql/ZH2TZLVvK0HwhCAbMoHHFfKIAKWGgCboEQI=";
  };
  nativeBuildInputs = [
    dpkg
    patchelf
  ];
  unpackPhase = "dpkg-deb -x $src .";
  dontBuild = true;
  dontStrip = true;
  # autoPatchelfHook (patchelf 0.19) and strip both corrupt this binary into a segfault; keep --no-sort.
  installPhase = ''
    install -Dm755 usr/bin/simplex-chat $out/bin/simplex-chat
    patchelf --no-sort \
      --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
      --set-rpath ${lib.makeLibraryPath [ openssl gmp zlib ]} \
      $out/bin/simplex-chat
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/simplex-chat --version
  '';
  meta = {
    description = "SimpleX Chat command-line client and local bot API";
    homepage = "https://simplex.chat";
    license = lib.licenses.agpl3Only;
    mainProgram = "simplex-chat";
    platforms = [ "x86_64-linux" ];
  };
}
