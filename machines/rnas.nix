{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./base.nix
    ../disko/rnas.nix
  ];

  networking.hostName = "rnas";
  boot.loader.generic-extlinux-compatible.configurationLimit = 5;
  hardware.deviceTree.name = "rockchip/rk3568-qnap-ts233-pcb-12-11.dtb";
  hardware.enableRedistributableFirmware = true;

  sops = {
    defaultSopsFile = ../secrets/rnas.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      sshKeyPaths = [ ];
    };
    gnupg.sshKeyPaths = [ ];
    secrets = {
      healthchecks-alert-url = { };
      healthchecks-canary-url = { };
    };
  };

  services.monitoringLite = {
    canary = {
      enable = true;
      urlFile = config.sops.secrets.healthchecks-canary-url.path;
      disks = [
        "/"
        "/lake"
      ];
      extraContext.u-boot-version = {
        runtimeInputs = [ pkgs.coreutils ];
        script = ''
          tr -d '\0' < /proc/device-tree/chosen/u-boot,version
        '';
      };
    };
    smartd = {
      enable = true;
      urlFile = config.sops.secrets.healthchecks-alert-url.path;
    };
    systemdFail = {
      enable = true;
      urlFile = config.sops.secrets.healthchecks-alert-url.path;
      services = [
        "monitoring-lite-smartd-short-self-test"
        "smartd"
        "sshd"
        "syncthing"
      ];
    };
  };

  fileSystems."/lake" = {
    device = "/dev/disk/by-label/hdd-lake";
    fsType = "xfs";
    options = [
      "defaults"
      "logbsize=256k"
      "X-fstrim.notrim"
    ];
  };

  users.users.syncthing.extraGroups = [ "data" ];

  systemd.tmpfiles.rules = [
    "d /data 0755 root root -"
    "d /data/shared 2770 syncthing data -"
    "d /data/syncthing 0750 syncthing syncthing -"
  ];

  services.syncthing = {
    enable = true;
    dataDir = "/data/syncthing";
    guiAddress = "127.0.0.1:8384";
    openDefaultPorts = true;
    # Manage folders and devices through the Web UI.
    overrideDevices = false;
    overrideFolders = false;
  };

  services.udev.extraRules =
    let
      mkRule = as: lib.concatStringsSep ", " as;
      mkRules = rs: lib.concatStringsSep "\n" rs;
    in
    mkRules [
      (mkRule [
        ''ACTION=="add|change"''
        ''SUBSYSTEM=="block"''
        ''KERNEL=="sd[a-z]"''
        ''ATTR{queue/rotational}=="1"''
        ''RUN+="${pkgs.hdparm}/bin/hdparm -S 244 /dev/%k"''
      ])
    ];

  system.stateVersion = "25.11";
}
