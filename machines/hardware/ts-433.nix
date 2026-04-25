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

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPatches = [
    {
      name = "0001";
      patch = ./patches/0001-UPSTREAM-dt-bindings-clock-rk3568-Add-SCMI-clock-ids.patch;
    }
    {
      name = "0002";
      patch = ./patches/0002-UPSTREAM-clk-rockchip-rk3568-Drop-CLK_NR_CLKS-usage.patch;
    }
    {
      name = "0003";
      patch = ./patches/0003-UPSTREAM-dt-bindings-clock-rk3568-Drop-CLK_NR_CLKS-d.patch;
    }
    {
      name = "0004";
      patch = ./patches/0004-UPSTREAM-arm64-dts-rockchip-use-SCMI-clock-id-for-cp.patch;
    }
    {
      name = "0005";
      patch = ./patches/0005-UPSTREAM-arm64-dts-rockchip-add-missing-clocks-for-c.patch;
    }
    {
      name = "0006";
      patch = ./patches/0006-UPSTREAM-arm64-dts-rockchip-use-SCMI-clock-id-for-gp.patch;
    }
    {
      name = "0007";
      patch = ./patches/0007-UPSTREAM-nvmem-Add-driver-for-the-eeprom-in-qnap-mcu.patch;
    }
    {
      name = "0008";
      patch = ./patches/0008-UPSTREAM-mfd-qnap-mcu-Hook-up-the-EEPROM-sub-device.patch;
    }
    {
      name = "0009";
      patch = ./patches/0009-UPSTREAM-mfd-qnap-mcu-Calculate-the-checksum-on-the-.patch;
    }
    {
      name = "0010";
      patch = ./patches/0010-UPSTREAM-mfd-qnap-mcu-Use-EPROTO-in-stead-of-EIO-on-.patch;
    }
    {
      name = "0011";
      patch = ./patches/0011-UPSTREAM-mfd-qnap-mcu-Move-checksum-verification-to-.patch;
    }
    {
      name = "0012";
      patch = ./patches/0012-UPSTREAM-mfd-qnap-mcu-Add-proper-error-handling-for-.patch;
    }
    {
      name = "0013";
      patch = ./patches/0013-UPSTREAM-arm64-dts-rockchip-move-cpu_thermal-node-to.patch;
    }
    {
      name = "0014";
      patch = ./patches/0014-UPSTREAM-arm64-dts-rockchip-describe-mcu-eeprom-cell.patch;
    }
    {
      name = "0015";
      patch = ./patches/0015-UPSTREAM-arm64-dts-rockchip-move-common-qnap-tsx33-p.patch;
    }
    {
      name = "0016";
      patch = ./patches/0016-UPSTREAM-dt-bindings-arm-rockchip-add-TS233-to-RK356.patch;
    }
    {
      name = "0017";
      patch = ./patches/0017-UPSTREAM-arm64-dts-rockchip-add-QNAP-TS233-devicetre.patch;
    }
    {
      name = "0018";
      patch = ./patches/0018-UPSTREAM-dt-bindings-mfd-qnap-ts433-mcu-Add-qnap-ts1.patch;
    }
    {
      name = "0019";
      patch = ./patches/0019-UPSTREAM-mfd-qnap-mcu-Add-driver-data-for-TS133-vari.patch;
    }
    {
      name = "0020";
      patch = ./patches/0020-UPSTREAM-arm64-dts-rockchip-Move-SoC-include-to-indi.patch;
    }
    {
      name = "0021";
      patch = ./patches/0021-UPSTREAM-arm64-dts-rockchip-Fix-the-common-combophy-.patch;
    }
    {
      name = "0022";
      patch = ./patches/0022-UPSTREAM-arm64-dts-rockchip-Move-copy-key-to-TSx33-b.patch;
    }
    {
      name = "0023";
      patch = ./patches/0023-UPSTREAM-dt-bindings-arm-rockchip-add-TS133-to-RK356.patch;
    }
    {
      name = "0024";
      patch = ./patches/0024-UPSTREAM-arm64-dts-rockchip-Add-TS133-variant-of-the.patch;
    }
    {
      name = "0039";
      patch = ./patches/0039-arm64-dts-rockchip-Add-port-subnodes-to-RK356x-SATA-.patch;
    }
    {
      name = "0040";
      patch = ./patches/0040-arm64-dts-rockchip-add-overlay-for-qnap-ts433-device.patch;
    }
    {
      name = "0041";
      patch = ./patches/0058-HACK-disable-usb-phy-regulators-temporarily.patch;
    }
  ];

  # Serial console for headless debugging on TS-433
  boot.kernelParams = [
    "console=ttyS2,115200n8"
    "rootdelay=30"
  ];

  # Initrd modules required to reach boot and data storage on TS-433
  boot.initrd.availableKernelModules = [
    # SATA / storage
    "ahci"
    "ahci_dwc"
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
    "phy_rockchip_naneng_combphy"

    # Filesystems
    "btrfs"
    "xfs"
  ];
  boot.initrd.kernelModules = [
    "ahci_dwc"
    "phy_rockchip_naneng_combphy"
  ];
  boot.kernelModules = [
    "rk3568_thermal"
    "r8169"
    "btrfs"
    "xfs"
  ];
  boot.initrd.supportedFilesystems = [ "xfs" ];
  boot.supportedFilesystems = [
    "ext4"
    "btrfs"
    "vfat"
    "xfs"
  ];
}
