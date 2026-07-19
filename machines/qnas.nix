{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./base.nix
    ./hardware/ts-433.nix
    ../disko/qnas.nix
  ];
  networking.hostName = "qnas";

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
    proxy = "socks5h://127.0.0.1:9050";
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
    btrfs-progs
    exfatprogs
    gnupg
    iperf
    lvm2
    mdadm
    openssl
    sops
    uutils-coreutils
    # keep-sorted end
  ];

  system.stateVersion = "25.11";
}
