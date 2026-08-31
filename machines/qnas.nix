{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./base.nix
    ../disko/qnas.nix
  ];
  networking.hostName = "qnas";

  boot.loader.generic-extlinux-compatible.configurationLimit = 5;
  hardware.deviceTree.name = "rockchip/rk3568-qnap-ts433-pcb-12-10.dtb";

  sops = {
    defaultSopsFile = ../secrets/qnas.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      sshKeyPaths = [ ];
    };
    gnupg.sshKeyPaths = [ ];
    secrets.healthchecks-canary-url = { };
  };

  services.monitoringLite.canary = {
    enable = true;
    urlFile = config.sops.secrets.healthchecks-canary-url.path;
    disks = [
      "/"
      "/data"
    ];
  };

  services.tor = {
    enable = true;
    client.enable = true;
    client.socksListenAddress = {
      addr = "127.0.0.1";
      port = 9050;
    };
    settings.ClientOnly = true;
  };

  systemd.services.monitoring-lite-canary.environment.all_proxy = "socks5h://127.0.0.1:9050";

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

  environment.systemPackages = with pkgs; [
    # keep-sorted start
    aptly
    # keep-sorted end
  ];

  system.stateVersion = "25.11";
}
