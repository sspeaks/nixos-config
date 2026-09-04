{ inputs, lib, config, outputs, ... }:
# P2.1 — the replacement Azure edge.
#
# This is a SPECIALIZED image: the VHD is built here, uploaded, and booted
# as-is. Azure does NOT provision it at first boot, and several settings below
# exist specifically because of that.
#
# Target: Standard_B2pts_v2 (Arm64) in West US 2, 16 GiB E3 OS disk.
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    ../../modules/azure-serial-console.nix
    ./edge.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs = {
    overlays = lib.mkDefault outputs.lib.overlayList;
    config.allowUnfree = lib.mkDefault true;
  };

  networking.hostName = "proxy";

  # ---------------------------------------------------------------- image ---
  # Gen2 (UEFI) so the disk is GPT with a real ESP. nixpkgs' azureImage builder
  # emits a FIXED-size VHD via `qemu-img convert -o subformat=fixed,force_size`.
  # Azure rejects dynamic VHDs at disk-create time, so this is not optional.
  virtualisation.azureImage = {
    vmGeneration = "v2";
    bootSize = 256;
  };
  # Sized to fit the 16 GiB E3 disk. "auto" sizes to content and then grows,
  # which makes the uploaded byte count unpredictable -- and `az disk create
  # --upload-type Upload` demands an exact --upload-size-bytes.
  virtualisation.diskSize = 15 * 1024;

  # GRUB EFI in REMOVABLE mode. A specialized image never gets the chance to
  # write EFI boot variables on the target VM, so the bootloader must sit at
  # the fallback path firmware always tries: /EFI/BOOT/BOOTAA64.EFI on aarch64.
  # canTouchEfiVariables must be false to match -- efibootmgr would fail in the
  # build VM and would be pointless on Azure.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    efiInstallAsRemovable = true;
    configurationLimit = 3;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  # ------------------------------------------------------------ networking ---
  # waagent stays ON. It provides VMAccess, which is the supported way to reset
  # SSH credentials on a VM you can no longer log into -- a genuine recovery
  # path worth keeping.
  #
  # cloud-init's NETWORK rendering is off, though. azure-common turns it on so
  # waagent will not fall back to ifupdown, but the result is two things that
  # both believe they own DHCP. systemd-networkd is made the sole owner here
  # via an explicit unit, so first-boot networking is deterministic.
  services.cloud-init.network.enable = lib.mkForce false;
  networking.useNetworkd = true;
  networking.useDHCP = false;

  systemd.network = {
    enable = true;
    networks."10-azure-primary" = {
      matchConfig.Name = "eth0 en*";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = false;
      };
      dhcpV4Config.UseDNS = true;
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # Provisioning already happened at image build time. Left enabled, waagent
  # waits for provisioning data that never arrives and stalls first boot.
  #
  # NOTE (owner, 2026-09-02): pogbot needed a waagent overlay (overlays.nix)
  # because upstream nixpkgs did not ship `$out/bin/waagent`. Upstream now does
  # -- `pkgs/by-name/wa/waagent/package.nix` builds that wrapper itself in
  # preFixup, and uses `--argv0` deliberately, because waagent re-executes
  # itself in UpdateHandler.run_latest and plain wrapProgram cannot express
  # that. Our overlay replaces `fixupPhase` wholesale, so upstream's preFixup
  # (the udev-rule move, buildPythonPath, and the --argv0 wrapper) does not
  # run, and it re-implements the wrapper with wrapProgram instead.
  #
  # It is nevertheless kept for now: waagent 2.15.0.1 is verified healthy under
  # this overlay on BOTH pogbot and vid-stream (goal-state agent running,
  # heartbeats clean), and AutoUpdate is disabled so the self-re-execution path
  # the --argv0 handling protects is not exercised. Re-packaging the agent that
  # provides our VMAccess recovery path, immediately before building the
  # replacement edge, would add risk with no migration benefit. Dropping the
  # overlay is a good standalone cleanup once the migration is done.
  services.waagent.settings = {
    Provisioning.Enable = false;
    ResourceDisk.Format = false;
    ResourceDisk.EnableSwap = false;
  };

  # ---------------------------------------------------------------- access ---
  # The bootstrap key is baked in. A specialized image receives no
  # Azure-injected SSH key, so without this the VM boots unreachable.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = lib.mkForce "no";
      X11Forwarding = false;
    };
  };

  # Serial console recovery. On this host it is not just a safety net: until
  # DNS cutover there is no other route in if sshd or the firewall misbehaves.
  #
  # The rescue account ships LOCKED. This image has no sops identity yet --
  # the host's SSH key, from which its age identity is derived, does not exist
  # until the VM first boots. The plan sequences this deliberately: "locked
  # rescue account" in the image, "final sops hash neededForUsers" afterwards.
  # Once the proxy has booted, add its host key to .sops.yaml, create
  # secrets/proxy.yaml, and set passwordHashFile to the decrypted secret.
  services.azureSerialConsole = {
    enable = true;
    passwordHashFile = null;
  };

  # ----------------------------------------------------------- guardrails ---
  # No auto-upgrade. This host is deployed deliberately from a reviewed commit;
  # an unattended rebuild of the public edge is exactly the class of surprise
  # this migration is removing.
  system.autoUpgrade.enable = lib.mkForce false;
  # No swap on the root disk: E3 is 16 GiB, and swap would consume it while
  # adding write amplification to a disk billed per operation.
  swapDevices = lib.mkForce [ ];

  security.sudo.wheelNeedsPassword = false;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = { inherit inputs outputs; };
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks-bare.nix ];
  };

  # 80/443 for the public edge; 51820/udp for home peers dialling out.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
    allowedUDPPorts = [ 51820 ];
  };

  time.timeZone = "America/Los_Angeles";
  # hosts/common/global already sets 23.05; these are new hosts so a newer
  # stateVersion is correct, but it must override rather than conflict.
  system.stateVersion = lib.mkForce "25.11";
}
