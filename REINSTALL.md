# Reinstalling NixOS on this machine

Assembled 2026-08-18. The only thing not in this repo is the age identity that
decrypts `secrets/`; everything else converges from `reb`.

**This ISO has only ever booted in QEMU, never on real hardware.** Keep a stock
Asahi ISO on a second stick. If the custom image fails, boot the stock one and
run Determinate's installer inside the live environment — you lose only faster
eval and preconfigured substituters.

## 0. Build the stick, from the working machine

```bash
nix build .#nixosConfigurations.iso.config.system.build.isoImage --impure
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Confirm from a browser, not from the machine being wiped, that the Bitwarden
secure note `sops age key` is reachable. That note is the entire recovery.

## 1. Decide how deep the wipe goes

Wiping **p5 only** (the NixOS root) needs no macOS-side work. p3 (Asahi stub,
m1n1 + U-Boot) and p4 (`EFI - NIXOS`, `/boot`) both came from the macOS-side
`alx.sh` run and are not NixOS-managed.

**Never `mkfs` p4.** It holds `asahi/all_firmware.tar.gz`, `vendorfw/`, `m1n1/`
and `EFI/`. The installer mounts it by the partuuid at
`/proc/device-tree/chosen/asahi,efi-system-partition` to extract firmware.
Reformat it and the installer loses Wi-Fi *and* the installed system loses its
bootloader — recoverable only by redoing the macOS-side install.

Going back to bare macOS first: `alx.sh` → resize APFS → **UEFI environment
only** → then boot the USB.

## 2. Live environment

Boot the stick, autologin. Bring up networking (`nmcli` or `iwctl`, both on the
image). Keep a USB-C ethernet adapter or phone tethering available — if
firmware extraction failed, there is no Wi-Fi.

Encryption wraps the block device, so it precedes `mkfs`. This is the only
moment full-disk encryption can be added; it cannot be retrofitted later.

```bash
cryptsetup luksFormat /dev/nvme0n1p5
cryptsetup open /dev/nvme0n1p5 cryptroot
mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot && mount /dev/nvme0n1p4 /mnt/boot
```

## 3. Get the flake onto the target

`gh auth login` happens **here**, in the live environment. The repo is private
and the SSH key that would authenticate is inside the repo being cloned, so the
browser flow over HTTPS is the only way in.

```bash
gh auth login                     # HTTPS, browser flow
mkdir -p /mnt/home/uynx
git clone https://github.com/uynx/nixos-config.git /mnt/home/uynx/nixos-config
```

Clone into the target home so no second clone is needed later. The HTTPS URL is
deliberate and keeps working after first boot: git's `insteadOf` rewrite to SSH
fires at connect time, not clone time.

## 4. Hardware config, then install

```bash
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/uynx/nixos-config/modules/hosts/asahi/_hardware-configuration.nix
```

Do not skip this because the repo already has that file. It pins the old root
UUID and ESP `E6D0-19FC`; fresh partitions invalidate the root UUID
unconditionally, and LUKS changes it even if p4 was kept.
`nixos-generate-config` detects the LUKS container and writes the
`boot.initrd.luks.devices.cryptroot.*` entries itself.

Commit before building — the flake cannot see untracked files, and under
`import-tree` that failure is silent.

```bash
cd /mnt/home/uynx/nixos-config && git add -A && git commit -m "hardware config"
nixos-install --flake /mnt/home/uynx/nixos-config#asahi --impure
chown -R 1000:100 /mnt/home/uynx
reboot
```

`--impure` is required: the Asahi firmware directory has to stay a real path.

## 5. First boot — the one manual secret

Log in as `uynx`. Everything works except secrets; `sops-nix.service` has
failed because its key is not there yet.

```fish
bw login && bw unlock
bw get notes 'sops age key' | install -Dm600 /dev/stdin ~/.config/sops/age/keys.txt
systemctl --user restart sops-nix.service
```

If `bw unlock` reports `The decryption operation failed` against a correct
password, the CLI's cached key material is stale after a vault KDF change.
`bw logout && bw login` is the only fix — `bw unlock` is offline and `bw sync`
needs an unlocked vault.

Verify before trusting it:

```fish
systemctl --user status sops-nix.service    # active (exited)
ls -l ~/.ssh/id_ed25519                     # symlink into ~/.config/sops-nix/secrets
ssh -T git@github.com                       # prints the GitHub greeting; exits 1 even on success
```

The SSH keypair needs no manual restore. The public half has been registered on
GitHub since 2026-01-17; the private half is ciphertext already in
`secrets/secrets.yaml` and gets written out now that the age key exists.

## 6. Converge

```fish
cd ~/nixos-config && reb
```

Then reboot once. AI CLIs self-install via `home.activation.installRollingAiClis`
and the Steam container rebuilds on first launch. What does not come back:
Steam game data, and `~/gdrive` contents (encrypted in Drive, remounted by
rclone once secrets land).

**The one hard ordering rule: the age key goes in before the first `reb`.** A
missing key fails the user unit, but `nixos-rebuild` still exits 0 — so the
wrong order gives a green rebuild, a working desktop, no SSH key, no Drive
mount, and nothing but an inactive unit to explain it.
