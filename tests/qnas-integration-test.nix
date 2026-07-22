{ inputs, system }:

(import "${inputs.nixpkgs}/nixos/lib/testing-python.nix" { inherit system; }).runTest {
  name = "qnas-integration-test";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        ./../machines/qnas.nix
        inputs.disko.nixosModules.disko
        inputs.home-manager.nixosModules.home-manager
        inputs.nixos-monitoring-lite.nixosModules.canary
        inputs.sops-nix.nixosModules.sops
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.daniel = import ./../users/daniel/home-manager.nix;
        }
      ];

      disko.devices.disk.main.device = "/dev/vda";
      networking.interfaces.eth0.useDHCP = true;

      sops = {
        defaultSopsFile = lib.mkForce ./../secrets/ci.yaml;
        useSystemdActivation = true;
      };

      systemd.services.sops-install-secrets = {
        wantedBy = lib.mkForce [ ];
        requiredBy = lib.mkForce [ ];
      };
      systemd.timers.monitoring-lite-canary.wantedBy = lib.mkForce [ ];

      virtualisation.memorySize = 2048;
      virtualisation.diskSize = 8192;
    };

  testScript = ''
    import os

    machine.wait_for_unit("multi-user.target")
    machine.succeed("uname -a")
    machine.succeed("id daniel")
    machine.wait_for_unit("sshd.service")
    machine.succeed("systemctl status sshd")
    machine.succeed("ip addr show")
    machine.succeed("which zsh")
    machine.succeed("which git")
    machine.succeed("which htop")
    machine.succeed("su - daniel -c 'echo \$SHELL'")
    machine.succeed("mount | grep -E '(ext4)'")
    machine.succeed("df -h /")

    ci_key = os.environ.get("SOPS_AGE_KEY_FILE")
    if ci_key:
        machine.copy_from_host(ci_key, "/var/lib/sops-nix/key.txt")
        machine.succeed("chmod 600 /var/lib/sops-nix/key.txt")
        machine.succeed("systemctl start sops-install-secrets.service")
        machine.succeed("test -s /run/secrets/healthchecks-canary-url")
        machine.wait_until_succeeds("journalctl -u tor.service | grep -q 'Bootstrapped 100%'")
        machine.succeed("systemctl start monitoring-lite-canary.service")
    elif os.environ.get("REQUIRE_SOPS_E2E"):
        raise RuntimeError("SOPS_AGE_KEY_FILE is required for the canary E2E test")
  '';
}
