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
  # Temporary collector for intermittent end0 failures; rerun with systemctl start.
  systemd.services.rnas-network-diagnostics = {
    description = "Collect RNAS Ethernet evidence in a new persistent run directory";
    wantedBy = [ "multi-user.target" ];
    # Broken networking must not prevent collection.
    after = [ "network.target" ];
    path = with pkgs; [
      bash
      coreutils
      dhcpcd
      dtc
      ethtool
      iproute2
      iptables
      iputils
      jq
      kmod
      nftables
      procps
      systemd
      tcpdump
      usbutils
      util-linux
    ];
    environment = {
      LABEL = "unlabelled";
      SETTLE_SECONDS = "120";
      TARGET_IPV4 = "";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "rnas-network-diagnostics" (
        builtins.readFile ./rnas-network-diagnostics.sh
      );
      EnvironmentFile = "-/var/lib/rnas-network-diagnostics/experiment.env";
      StateDirectory = "rnas-network-diagnostics";
      StateDirectoryMode = "0700";
      UMask = "0077";
      TimeoutStartSec = "10min";
    };
  };

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
        "smartd"
        "sshd"
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
