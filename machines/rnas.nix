{
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
