{
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

  services.udev.extraRules =
    let
      mkRule = as: lib.concatStringsSep ", " as;
      mkRules = rs: lib.concatStringsSep "\n" rs;
    in
    mkRules ([
      (mkRule [
        ''ACTION=="add|change"''
        ''SUBSYSTEM=="block"''
        ''KERNEL=="sd[a-z]"''
        ''ATTR{queue/rotational}=="1"''
        ''RUN+="${pkgs.hdparm}/bin/hdparm -S 244 /dev/%k"''
      ])
    ]);

  environment.systemPackages = with pkgs; [
    # keep-sorted start
    openssl
    # keep-sorted end
  ];

  system.stateVersion = "25.11";
}
