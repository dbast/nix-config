{ ... }:

{
  disko.devices = {
    disk.emmc = {
      device = "/dev/disk/by-path/platform-fe310000.mmc";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            start = "32M";
            size = "2048M";
            type = "8300";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/boot";
              mountOptions = [ "noatime" ];
              extraArgs = [
                "-O"
                "^has_journal"
              ];
            };
          };
        };
      };
    };

    disk.main = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = null;
          };

          swap = {
            size = "8G";
            type = "8200";
            content = {
              type = "swap";
              randomEncryption = true;
              discardPolicy = "both";
            };
          };

          root = {
            size = "64G";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/";
              mountOptions = [
                "defaults"
                "logbsize=256k"
              ];
            };
          };

          data = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/data";
              mountOptions = [
                "defaults"
                "logbsize=256k"
              ];
            };
          };
        };
      };
    };
  };
}
