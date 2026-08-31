{
  imports = [
    ./base.nix
    ../disko/rnas.nix
  ];

  networking.hostName = "rnas";
  boot.loader.generic-extlinux-compatible.configurationLimit = 5;
  hardware.deviceTree.name = "rockchip/rk3568-qnap-ts233-pcb-12-11.dtb";

  system.stateVersion = "25.11";
}
