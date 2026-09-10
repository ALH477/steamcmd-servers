{
  description = "NixOS module for declarative SteamCMD game server hosting";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    pkgsFor = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
  in {
    # ════════════════════════════════════════════════════════════════════════
    # NixOS Modules
    # ════════════════════════════════════════════════════════════════════════

    nixosModules = {
      steamcmd-servers = import ./default.nix;
      default = self.nixosModules.steamcmd-servers;
    };

    # ════════════════════════════════════════════════════════════════════════
    # Overlays
    # ════════════════════════════════════════════════════════════════════════

    overlays.default = final: prev: {
      steamcmd-ctl = final.callPackage ./server-utils.nix {};
    };

    # ════════════════════════════════════════════════════════════════════════
    # Packages
    # ════════════════════════════════════════════════════════════════════════

    packages = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      steamcmd-ctl = pkgs.callPackage ./server-utils.nix {};
      default = self.packages.${system}.steamcmd-ctl;
    });

    # ════════════════════════════════════════════════════════════════════════
    # Library Exports (Presets)
    # ════════════════════════════════════════════════════════════════════════

    lib = {
      presets = import ./presets.nix {inherit (nixpkgs) lib;};
    };

    # ════════════════════════════════════════════════════════════════════════
    # Development Shells
    # ════════════════════════════════════════════════════════════════════════

    devShells = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          alejandra
          nil
          steamcmd
          self.packages.${system}.steamcmd-ctl
        ];
        shellHook = ''
          echo "SteamCMD Servers development shell"
          echo "  - Run 'nix flake check' to test"
          echo "  - Run 'alejandra .' to format"
        '';
      };
    });

    # ════════════════════════════════════════════════════════════════════════
    # Tests
    # ════════════════════════════════════════════════════════════════════════

    checks = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      # Module evaluation test
      module-eval = pkgs.testers.nixosTest {
        name = "steamcmd-module-evaluation";

        nodes.server = {pkgs, ...}: {
          imports = [self.nixosModules.steamcmd-servers];
          services.steamcmd-servers = {
            enable = true;
            openFirewall = true;

            updates = {
              enable = true;
              schedule = "*-*-* 04:00:00";
            };

            servers.test-tf2 = {
              enable = true;
              appId = "232250";
              appIdName = "Test TF2 Server";
              executable = "srcds_run";
              executableArgs = ["-game tf" "+map cp_badlands"];
              ports.game = 27015;
              extraNixLdPackages = [pkgs.libxi];
            };
          };
        };

        testScript = ''
          # Wait for system
          server.wait_for_unit("multi-user.target")

          # Check user/group created
          server.succeed("id steamcmd")
          server.succeed("getent group steamcmd")

          # Check directories exist
          server.succeed("test -d /var/lib/steamcmd-servers")
          server.succeed("test -d /var/lib/steamcmd-servers/servers")

          # Check timer is active
          server.succeed("systemctl is-enabled steamcmd-update.timer")

          # Check service unit exists (won't start without actual files)
          server.succeed("systemctl cat steamcmd-server-test-tf2.service")
        '';
      };

      # Package build test
      package = self.packages.${system}.steamcmd-ctl;

      # Formatting check
      formatting =
        pkgs.runCommand "check-formatting" {
          nativeBuildInputs = [pkgs.alejandra];
        } ''
          alejandra --check ${self}/*.nix
          touch $out
        '';
    });
  };
}
