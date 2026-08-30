{
  imports = [
    ./base.nix
    ../disko/rnas.nix
  ];

  networking.hostName = "rnas";
  boot.loader.generic-extlinux-compatible.configurationLimit = 5;

  system.stateVersion = "25.11";
}
