{
  flake.homeModules.braveOrigin =
    { pkgs, ... }:

    let
      update-brave-origin = pkgs.writers.writePython3Bin "update-brave-origin" { } ''
        import json
        import os
        import re
        import subprocess
        import urllib.request

        base = "https://brave-browser-apt-release.s3.brave.com"
        url = f"{base}/dists/stable/main/binary-arm64/Packages"
        idx = urllib.request.urlopen(url).read().decode()
        pat = r"Package: brave-origin\n.*?Version: ([\d.]+)"
        latest = re.search(pat, idx, re.DOTALL).group(1)
        # Split: writePython3Bin runs a PEP8 check and E501 fires at 79 chars.
        rel = "modules/apps/brave-origin/pins.json"
        path = os.path.expanduser(f"~/nixos-config/{rel}")
        with open(path) as f:
            pins = json.load(f)
        print(f"Current: {pins['version']} | Latest: {latest}")
        if pins["version"] == latest:
            print("Already up to date.")
            raise SystemExit(0)


        def h(arch):
            url = (
                f"{base}/pool/main/b/brave-origin/"
                f"brave-origin_{latest}_{arch}.deb"
            )
            print(f"Hashing {arch}...")
            cmd = ["nix-prefetch-url", url]
            pf = subprocess.run(
                cmd, capture_output=True, text=True, check=True
            )
            cmd_convert = [
                "nix", "hash", "convert",
                "--hash-algo", "sha256",
                "--to", "sri",
                pf.stdout.strip()
            ]
            return subprocess.run(
                cmd_convert, capture_output=True, text=True, check=True
            ).stdout.strip()


        # Keys are the Debian arch names, which _brave-origin.nix indexes
        # directly. Both hashes are fetched before anything is written, so a
        # failed fetch leaves the old pair intact rather than a mixed one.
        fresh = {
            "version": latest,
            "arm64": h("arm64"),
            "amd64": h("amd64"),
        }
        with open(path, "w") as f:
            json.dump(fresh, f, indent=2)
            f.write("\n")
        print("Updated pins.json successfully!")
      '';

    in
    {
      home.packages = [ update-brave-origin ];

      programs.chromium = {
        enable = true;
        package = pkgs.callPackage ./_brave-origin.nix { };
      };
    };
}
