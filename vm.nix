# The isolated analysis VM: no network, no shared folders, its own Nix store.
# Samples come in on a read-only disk (/input), results go out on a separate disk (/results).
{ config, lib, pkgs, ... }:
let
  tools = import ./tools.nix pkgs;
in
{
  system.stateVersion = "26.11";
  networking.hostName = "analysis";

  virtualisation = {
    memorySize = 2048;
    cores = 2;
    # the ephemeral root disk, for unpacking samples and scratch work
    diskSize = 4096;

    # console in the terminal, no graphics device
    graphics = false;

    # no network card at all; without -nic none QEMU adds one by itself
    qemu.networkingOptions = lib.mkForce [ "-nic none" ];

    # own copy of the Nix store instead of sharing the host's, and no shared folders
    useNixStoreImage = true;
    mountHostNixStore = false;
    sharedDirectories = lib.mkForce { };
  };

  # the run script attaches these disks by serial; nofail so the VM boots without them.
  # virtualisation.fileSystems, because the VM module replaces plain fileSystems with its own
  virtualisation.fileSystems."/input" = {
    device = "/dev/disk/by-id/virtio-input";
    fsType = "squashfs";
    options = [ "ro" "nofail" "noexec" "nosuid" "nodev" ];
  };
  virtualisation.fileSystems."/results" = {
    device = "/dev/disk/by-id/virtio-results";
    fsType = "ext4";
    options = [ "nofail" "noexec" "nosuid" "nodev" ];
  };

  # nothing to log in to remotely, so log the analyst in on the console directly
  users.users.analyst = {
    isNormalUser = true;
    # the results disk is created on the host with this owner
    uid = 1000;
    extraGroups = [ "wheel" ];
  };
  services.getty.autologinUser = "analyst";
  security.sudo.wheelNeedsPassword = false;

  networking.useDHCP = false;
  networking.firewall.enable = true;
  documentation.enable = false;

  environment.systemPackages = tools.logs ++ tools.static;

  users.motd = ''

    Isolated analysis VM: no network, nothing shared with the host.
      /input     samples and logs from the host (read-only, nothing executable)
      /results   copied back to the host when the VM shuts down; never put samples here
      ~/work     scratch space, deleted on shutdown

    Unpack a sample:  7zz x /input/sample.zip -pinfected -o$HOME/work
    Shut down:        sudo poweroff

  '';
  systemd.tmpfiles.settings.work."/home/analyst/work".d = {
    user = "analyst";
    group = "users";
    mode = "0700";
  };
}
