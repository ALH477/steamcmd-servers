{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.steamcmd-servers;

  # Server instance submodule
  serverOpts = {name, ...}: {
    options = {
      enable = mkEnableOption "this game server instance";

      appId = mkOption {
        type = types.str;
        description = "Steam App ID for the dedicated server.";
        example = "232250";
      };

      appIdName = mkOption {
        type = types.str;
        default = name;
        description = "Human-readable name for the server.";
        example = "Team Fortress 2";
      };

      beta = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Beta branch to install (if any).";
        example = "prerelease";
      };

      betaPasswordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing beta branch password.";
        example = "/run/secrets/beta-password";
      };

      steamRun = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Run server executable via steam-run for better library compatibility.";
        };
        package = mkOption {
          type = types.nullOr types.package;
          default = pkgs.steam-run;
          description = "Nix package to use with steam-run (defaults to steamcmd if null).";
        };
      };
      installDir = mkOption {
        type = types.path;
        default = "${cfg.dataDir}/servers/${name}";
        defaultText = literalExpression ''"''${cfg.dataDir}/servers/''${name}"'';
        description = "Installation directory for this server.";
      };
      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [];
        description = "Additional packages to include in PATH for this server.";
      };
      extraNixLdPackages = mkOption {
        type = types.listOf types.package;
        default = [];
        description = "Additional nix-ld package to use.";
      };
      validate = mkOption {
        type = types.bool;
        default = true;
        description = "Validate files on update (recommended, but slower).";
      };
      # Authentication
      anonymous = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Use anonymous login. Works for most dedicated servers.
          Set to false and provide steamUsername/steamPasswordFile for games
          requiring authenticated downloads.
        '';
      };

      steamUsername = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Steam username for authenticated downloads.";
      };

      steamPasswordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to file containing Steam password.
          File should be readable only by root and the steamcmd user.
        '';
        example = "/run/secrets/steam-password";
      };

      # Game Server Login Token
      gsltFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to file containing Game Server Login Token (GSLT).
          Required for CS2, TF2, and other Valve games to be listed publicly.
          Generate at: https://steamcommunity.com/dev/managegameservers
        '';
        example = "/run/secrets/gslt-token";
      };

      gsltEnvVar = mkOption {
        type = types.str;
        default = "STEAM_GSLT";
        description = "Environment variable name to expose GSLT token as.";
      };

      # Execution
      executable = mkOption {
        type = types.str;
        description = "Path to server executable relative to installDir.";
        example = "srcds_run";
      };

      executableArgs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Arguments to pass to the server executable.";
        example = ["-game tf" "+maxplayers 24" "+map cp_badlands"];
      };

      preStart = mkOption {
        type = types.lines;
        default = "";
        description = "Shell commands to run before starting the server.";
      };

      postStart = mkOption {
        type = types.lines;
        default = "";
        description = "Shell commands to run after starting the server.";
      };

      postStop = mkOption {
        type = types.lines;
        default = "";
        description = "Shell commands to run after stopping the server.";
      };

      # Environment
      environment = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = ''
          Environment variables for the server process.
          LD_LIBRARY_PATH is automatically prepended with common paths.
        '';
        example = {
          SRCDS_TOKEN = "your_token_here";
        };
      };

      extraLdLibraryPaths = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional paths to prepend to LD_LIBRARY_PATH.";
        example = ["bin" "linux64"];
      };

      # Networking
      ports = {
        game = mkOption {
          type = types.port;
          default = 27015;
          description = "Main game port (UDP).";
        };

        gameProtocol = mkOption {
          type = types.enum ["udp" "tcp" "both"];
          default = "udp";
          description = "Protocol for main game port.";
        };

        query = mkOption {
          type = types.nullOr types.port;
          default = null;
          description = "Query port (defaults to game port if null).";
        };

        rcon = mkOption {
          type = types.nullOr types.port;
          default = null;
          description = "RCON port (TCP, if separate from game port).";
        };

        extraPorts = mkOption {
          type = types.listOf (types.submodule {
            options = {
              port = mkOption {
                type = types.port;
                description = "Port number.";
              };
              protocol = mkOption {
                type = types.enum ["tcp" "udp" "both"];
                default = "udp";
                description = "Protocol for this port.";
              };
              description = mkOption {
                type = types.str;
                default = "";
                description = "What this port is used for.";
              };
            };
          });
          default = [];
          description = "Additional ports to open.";
        };
      };

      # Resource limits
      resources = {
        memoryLimit = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Memory limit (systemd format).";
          example = "8G";
        };

        memoryHigh = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Memory high watermark (throttling starts here).";
          example = "6G";
        };

        cpuQuota = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "CPU quota percentage (e.g., '200%' for 2 cores).";
          example = "400%";
        };

        nice = mkOption {
          type = types.ints.between (-20) 19;
          default = 0;
          description = "Nice value for the process.";
        };

        ioSchedulingClass = mkOption {
          type = types.enum ["realtime" "best-effort" "idle" "none"];
          default = "best-effort";
          description = "IO scheduling class.";
        };
      };

      # Systemd service options
      autoStart = mkOption {
        type = types.bool;
        default = true;
        description = "Start this server automatically on boot.";
      };

      restartPolicy = mkOption {
        type = types.enum ["no" "on-success" "on-failure" "on-abnormal" "on-watchdog" "on-abort" "always"];
        default = "on-failure";
        description = "When to restart the service.";
      };

      restartSec = mkOption {
        type = types.int;
        default = 10;
        description = "Seconds to wait before restart.";
      };

      restartMaxRetries = mkOption {
        type = types.int;
        default = 5;
        description = "Maximum restart attempts within restartWindow.";
      };

      restartWindow = mkOption {
        type = types.int;
        default = 300;
        description = "Time window (seconds) for counting restart attempts.";
      };

      stopTimeout = mkOption {
        type = types.int;
        default = 3600;
        description = "Seconds to wait for graceful shutdown before SIGKILL.";
      };

      # Update behavior
      autoUpdate = mkOption {
        type = types.bool;
        default = true;
        description = "Include in automatic update schedule.";
      };

      stopBeforeUpdate = mkOption {
        type = types.bool;
        default = true;
        description = "Stop server before updating (recommended).";
      };

      # Extra steamcmd commands
      extraSteamcmdCommands = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Extra commands to run in steamcmd before app_update.";
        example = ["workshop_download_item 440 123456789"];
      };

      # Security
      extraReadWritePaths = mkOption {
        type = types.listOf types.path;
        default = [];
        description = "Additional paths the server can write to.";
      };

      allowNetworkAccess = mkOption {
        type = types.bool;
        default = true;
        description = "Allow network access (disable for offline testing).";
      };
    };
  };

  # Helper to build steamcmd script content
  mkSteamcmdScript = name: server:
    pkgs.writeText "steamcmd-${name}.txt" ''
      @ShutdownOnFailedCommand 1
      @NoPromptForPassword 1
      force_install_dir ${server.installDir}
      login ${
        if server.anonymous
        then "anonymous"
        else server.steamUsername
      } ${
        if !server.anonymous && server.steamPasswordFile != null
        then "${builtins.readFile server.steamPasswordFile}"
        else ""
      }
      ${concatStringsSep "\n" server.extraSteamcmdCommands}
      app_update ${server.appId}${optionalString server.validate " validate"}${optionalString (server.beta != null) " -beta ${server.beta}"}
      quit
    '';

  # Helper for port rules
  portsForProtocol = proto: servers:
    flatten (mapAttrsToList (
      name: server: let
        matchProto = p: p == proto || p == "both";
        gamePorts = optional (matchProto server.ports.gameProtocol) server.ports.game;
        queryPorts = optional (server.ports.query != null && proto == "udp") server.ports.query;
        rconPorts = optional (server.ports.rcon != null && proto == "tcp") server.ports.rcon;
        extraPorts = map (p: p.port) (filter (p: matchProto p.protocol) server.ports.extraPorts);
      in
        gamePorts ++ queryPorts ++ rconPorts ++ extraPorts
    ) (filterAttrs (_: s: s.enable) servers));

  enabledServers = filterAttrs (_: s: s.enable) cfg.servers;
in {
  options.services.steamcmd-servers = {
    enable = mkEnableOption "SteamCMD game server hosting";

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/steamcmd-servers";
      description = "Base directory for all server data.";
    };

    user = mkOption {
      type = types.str;
      default = "steamcmd";
      description = "User account for running servers.";
    };

    group = mkOption {
      type = types.str;
      default = "steamcmd";
      description = "Group for server processes.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall ports for all enabled servers.";
    };

    # Global update settings
    updates = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic updates via systemd timer.";
      };

      schedule = mkOption {
        type = types.str;
        default = "*-*-* 04:00:00";
        description = "When to run automatic updates (systemd OnCalendar format).";
        example = "Sun *-*-* 04:00:00";
      };

      randomDelay = mkOption {
        type = types.str;
        default = "15min";
        description = "Random delay added to update time to spread load.";
      };

      notifyOnFailure = mkOption {
        type = types.bool;
        default = true;
        description = "Send systemd notification on update failure.";
      };
    };

    # Server instances
    servers = mkOption {
      type = types.attrsOf (types.submodule serverOpts);
      default = {};
      description = "Game server instances to manage.";
      example = literalExpression ''
        {
          tf2 = {
            enable = true;
            appId = "232250";
            appIdName = "Team Fortress 2";
            executable = "srcds_run";
            executableArgs = [
              "-game tf"
              "+maxplayers 24"
              "+map cp_badlands"
              "-port 27015"
            ];
            ports.game = 27015;
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    # ══════════════════════════════════════════════════════════════════════════
    # Configuration validation
    # ══════════════════════════════════════════════════════════════════════════
    assertions = flatten (mapAttrsToList (name: server: [
        {
          assertion = server.enable -> server.appId != "";
          message = "steamcmd-servers.servers.${name}: appId is required when enabled.";
        }
        {
          assertion = server.enable -> server.executable != "";
          message = "steamcmd-servers.servers.${name}: executable is required when enabled.";
        }
        {
          assertion = !server.anonymous -> server.steamUsername != null;
          message = "steamcmd-servers.servers.${name}: steamUsername required when not using anonymous login.";
        }
        {
          assertion = !server.anonymous -> server.steamPasswordFile != null;
          message = "steamcmd-servers.servers.${name}: steamPasswordFile required when not using anonymous login.";
        }
      ])
      cfg.servers);

    warnings = flatten (mapAttrsToList (
        name: server:
          optional (server.enable && server.appId == "730" && server.gsltFile == null)
          "steamcmd-servers.servers.${name}: CS2 servers require a GSLT token to be publicly listed. Set gsltFile."
      )
      cfg.servers);

    # ══════════════════════════════════════════════════════════════════════════
    # Package dependencies
    # ══════════════════════════════════════════════════════════════════════════
    environment.systemPackages = [pkgs.steamcmd];

    # ══════════════════════════════════════════════════════════════════════════
    # User/group creation
    # ══════════════════════════════════════════════════════════════════════════
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      description = "SteamCMD game server user";
    };

    users.groups.${cfg.group} = {};

    # ══════════════════════════════════════════════════════════════════════════
    # Directory structure
    # ══════════════════════════════════════════════════════════════════════════
    systemd.tmpfiles.rules =
      [
        "d ${cfg.dataDir}          0750 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/servers  0750 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/steamcmd 0750 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/logs     0750 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/scripts  0750 ${cfg.user} ${cfg.group} -"
      ]
      ++ (mapAttrsToList
        (name: server: "d ${server.installDir} 0750 ${cfg.user} ${cfg.group} -")
        enabledServers);
    programs.nix-ld = let
      libraries = concatLists (mapAttrsToList (name: s: s.extraNixLdPackages) enabledServers);
    in {
      enable = lib.lists.length libraries > 0;
      inherit libraries;
    };
    # ══════════════════════════════════════════════════════════════════════════
    # Server services
    # ══════════════════════════════════════════════════════════════════════════
    systemd.services =
      mapAttrs'
      (name: server:
        nameValuePair "steamcmd-server-${name}" {
          description = "SteamCMD Server: ${server.appIdName} (${name})";
          documentation = ["https://developer.valvesoftware.com/wiki/SteamCMD"];
          after = ["network-online.target"];
          wants = ["network-online.target"];
          wantedBy = mkIf server.autoStart ["multi-user.target"];

          environment = let
            baseLdPath = "${server.installDir}:${server.installDir}/bin";
            extraLdPaths = concatStringsSep ":" (map (p: "${server.installDir}/${p}") server.extraLdLibraryPaths);
            ldPath =
              if extraLdPaths != ""
              then "${extraLdPaths}:${baseLdPath}"
              else baseLdPath;
            userLdPath = server.environment.LD_LIBRARY_PATH or "";
            nixld_library_path = (
              if config.programs.nix-ld.enable
              then (builtins.getEnv "NIX_LD_LIBRARY_PATH")
              else ""
            );
            finalLdPath =
              if userLdPath != ""
              then "${userLdPath}:${ldPath}:${nixld_library_path}"
              else "${ldPath}:${nixld_library_path}";
          in
            (removeAttrs server.environment ["LD_LIBRARY_PATH"])
            // {
              HOME = cfg.dataDir;
              LD_LIBRARY_PATH = finalLdPath;
            };

          path = with pkgs;
            [
              coreutils
              gawk
              gnugrep
              gnutar
              gzip
              steamcmd
            ]
            ++ server.extraPackages
            ++ (
              if server.steamRun.enable
              then [server.steamRun.package]
              else []
            );

          preStart = ''
            # Install server if not present
            if [ ! -f "${server.installDir}/.installed" ]; then
              echo "Installing ${server.appIdName} (App ID: ${server.appId})..."
              ${pkgs.steamcmd}/bin/steamcmd +runscript ${mkSteamcmdScript name server}
              touch "${server.installDir}/.installed"
              echo "Installation complete."
            fi
            ${server.preStart}
          '';

          script = let
            exec =
              if server.steamRun.enable
              then "${lib.getExe server.steamRun.package}"
              else "exec";
          in ''
            cd "${server.installDir}"

            ${optionalString (server.gsltFile != null) ''
              if [ -f "${server.gsltFile}" ]; then
                export ${server.gsltEnvVar}="$(cat "${server.gsltFile}")"
              fi
            ''}

            ${exec} ./${server.executable} ${escapeShellArgs server.executableArgs}
          '';

          postStart = server.postStart;
          postStop = server.postStop;

          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = server.installDir;

            # Restart behavior
            Restart = server.restartPolicy;
            RestartSec = server.restartSec;
            StartLimitBurst = server.restartMaxRetries;
            StartLimitIntervalSec = server.restartWindow;

            # Graceful shutdown
            KillSignal = "SIGTERM";
            TimeoutStopSec = server.stopTimeout;
            KillMode = "mixed";

            # Process priority
            Nice = server.resources.nice;
            IOSchedulingClass = server.resources.ioSchedulingClass;

            # Resource limits
            MemoryMax = mkIf (server.resources.memoryLimit != null) server.resources.memoryLimit;
            MemoryHigh = mkIf (server.resources.memoryHigh != null) server.resources.memoryHigh;
            CPUQuota = mkIf (server.resources.cpuQuota != null) server.resources.cpuQuota;

            # Security hardening
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictNamespaces = false;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = false; # Game servers often require JIT
            PrivateNetwork = !server.allowNetworkAccess;

            # File access
            ReadWritePaths =
              [
                cfg.dataDir
                "${cfg.dataDir}"
                "${cfg.dataDir}/servers"
                "${cfg.dataDir}/steamcmd"
                "${cfg.dataDir}/logs"
                "${cfg.dataDir}/scripts"
                server.installDir
                "${cfg.dataDir}/logs"
              ]
              ++ server.extraReadWritePaths;

            # Logging
            StandardOutput = "journal";
            StandardError = "journal";
            SyslogIdentifier = "steamcmd-${name}";
          };

          unitConfig = {
            # Don't start if config is broken
            ConditionPathExists = server.installDir;
          };
        })
      enabledServers
      # ══════════════════════════════════════════════════════════════════════════
      # Update service (runs as root to manage services)
      # ══════════════════════════════════════════════════════════════════════════
      // optionalAttrs cfg.updates.enable {
        steamcmd-update = {
          description = "Update all SteamCMD game servers";
          documentation = ["https://developer.valvesoftware.com/wiki/SteamCMD"];
          after = ["network-online.target"];
          wants = ["network-online.target"];

          path = with pkgs; [coreutils steamcmd systemd sudo];

          environment = {
            HOME = cfg.dataDir;
          };

          script = let
            updatableServers = filterAttrs (_: s: s.enable && s.autoUpdate) cfg.servers;
          in ''
            set -euo pipefail

            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "║  SteamCMD Server Update - $(date '+%Y-%m-%d %H:%M:%S')       ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo ""

            update_failed=0

            ${concatStringsSep "\n" (mapAttrsToList (name: server: ''
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "Updating: ${server.appIdName} (${server.appId})"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

                was_running=0
                ${optionalString server.stopBeforeUpdate ''
                  if systemctl is-active --quiet "steamcmd-server-${name}"; then
                    echo "→ Stopping server for update..."
                    systemctl stop "steamcmd-server-${name}" || true
                    was_running=1
                  fi
                ''}

                echo "→ Running SteamCMD update..."
                if sudo -u ${cfg.user} ${pkgs.steamcmd}/bin/steamcmd +runscript ${mkSteamcmdScript name server}; then
                  echo "✓ Update successful"
                else
                  echo "✗ Update failed!"
                  update_failed=1
                fi

                ${optionalString server.stopBeforeUpdate ''
                  if [ "$was_running" = "1" ]; then
                    echo "→ Restarting server..."
                    systemctl start "steamcmd-server-${name}" || echo "✗ Failed to restart!"
                  fi
                ''}

                echo ""
              '')
              updatableServers)}

            echo "════════════════════════════════════════════════════════════════"
            if [ "$update_failed" = "0" ]; then
              echo "All updates completed successfully."
            else
              echo "Some updates failed. Check logs above."
              exit 1
            fi
          '';

          serviceConfig = {
            Type = "oneshot";
            Nice = 10;
            IOSchedulingClass = "idle";
            # Run as root for systemctl access, steamcmd runs via sudo -u
          };
        };
      };

    # ══════════════════════════════════════════════════════════════════════════
    # Update timer
    # ══════════════════════════════════════════════════════════════════════════
    systemd.timers.steamcmd-update = mkIf cfg.updates.enable {
      description = "Timer for SteamCMD server updates";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.updates.schedule;
        RandomizedDelaySec = cfg.updates.randomDelay;
        Persistent = true;
      };
    };

    # ══════════════════════════════════════════════════════════════════════════
    # Firewall configuration
    # ══════════════════════════════════════════════════════════════════════════
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = portsForProtocol "tcp" cfg.servers;
      allowedUDPPorts = portsForProtocol "udp" cfg.servers;
    };
  };
}
