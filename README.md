# nix-config

This repository contains a minimal NixOS configuration for a QNAP TS-433 NAS, including the extlinux/U-Boot boot setup, RK3568 kernel module defaults, and disk layout used by the `qnas` machine. It assumes the device is booted with a mainline U-Boot image, such as the one built by [qnap-ts-433-bootloader-builder](https://github.com/dbast/qnap-ts-433-bootloader-builder), and is intentionally TS-433-first until related hardware has been tested.

The same setup can potentially also be used for related TSx33 devices by forcing the Linux device tree that NixOS writes into `extlinux.conf`, for example `hardware.deviceTree.name = "rockchip/rk3568-qnap-ts233.dtb";` for TS-233 or `hardware.deviceTree.name = "rockchip/rk3566-qnap-ts133.dtb";` for TS-133. Treat this as experimental: the TS-433 U-Boot image may be enough to hand off to Linux with the right DTB, but TS-133/TS-233-specific support should only be promoted into real modules after validation on hardware.
