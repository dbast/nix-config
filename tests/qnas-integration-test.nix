{ inputs, system }:

(import "${inputs.nixpkgs}/nixos/lib/testing-python.nix" { inherit system; }).runTest {
  name = "qnas-integration-test";

  nodes.machine =
    { ... }:
    {
      imports = [
        ./../machines/qnas.nix
        inputs.disko.nixosModules.disko
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.daniel = import ./../users/daniel/home-manager.nix;
        }
      ];

      disko.devices.disk.main.device = "/dev/vda";

      virtualisation.memorySize = 2048;
      virtualisation.diskSize = 8192;
    };

  testScript = ''
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
  '';
}
