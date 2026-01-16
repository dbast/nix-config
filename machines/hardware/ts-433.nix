{ pkgs, ... }:

{
  nixpkgs.hostPlatform.system = "aarch64-linux";

  # Allow firmware blobs required by the NIC (e.g. r8125)
  hardware.enableRedistributableFirmware = true;

  # Bootloader: mainline U-Boot with extlinux on TS-433
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.loader.generic-extlinux-compatible.configurationLimit = 5;
  boot.loader.timeout = 20;

  # No EFI variables on this platform
  boot.loader.efi.canTouchEfiVariables = false;

  # boot.kernelPackages = pkgs.linuxPackages_6_17;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Serial console for headless debugging on TS-433
  boot.kernelParams = [
    "console=ttyS2,115200n8"
    "rootdelay=30"
  ];

  # Initrd modules required to reach boot and data storage on TS-433
  boot.initrd.availableKernelModules = [
    # SATA / storage
    "ahci"
    "ahci_platform"
    "sdhci"
    "sdhci_of_arasan"
    "mmc_block"

    # USB 3 / DWC3 (for recovery, external disks, etc.)
    "xhci_pci"
    "dwc3"

    # Ethernet: Rockchip GMAC + PHYs
    "stmmac"
    "stmmac_platform"
    "dwmac_rk"
    "realtek"
    "libphy"

    # Filesystems
    "xfs"
  ];
  boot.kernelModules = [
    "rk3568_thermal"
    "r8169"
    "xfs"
  ];
  boot.initrd.supportedFilesystems = [ "xfs" ];
  boot.supportedFilesystems = [
    "ext4"
    "vfat"
    "xfs"
  ];
}
