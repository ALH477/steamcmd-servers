# SteamCMD Servers NixOS Module

A declarative NixOS flake module for hosting multiple SteamCMD-based game servers with automatic updates, systemd hardening, and unified management.

## Features

- **Multi-instance support**: Run multiple game servers with isolated configurations
- **Declarative configuration**: Define your entire server infrastructure in Nix
- **Automatic updates**: Scheduled steamcmd updates with configurable timing
- **Systemd hardening**: Security-focused service configuration out of the box
- **Resource limits**: Memory, CPU, and nice value controls per server
- **Firewall integration**: Automatic port opening for enabled servers
- **Presets**: Ready-to-use configurations for popular games
- **Management CLI**: `steamcmd-ctl` utility for server operations

## Quick Start

### 1. Add to your flake inputs

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    steamcmd-servers.url = "github:kagurazaka-ayano/steamcmd-servers";
  };

  outputs = { self, nixpkgs, steamcmd-servers, ... }: {
    nixosConfigurations.gameserver = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        steamcmd-servers.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### 2. Basic configuration

```nix
{ config, lib, pkgs, ... }:

{
  services.steamcmd-servers = {
    enable = true;
    openFirewall = true;

    servers.tf2 = {
      enable = true;
      appId = "232250";
      appIdName = "Team Fortress 2";
      executable = "srcds_run";
      executableArgs = [
        "-game tf"
        "+maxplayers 24"
        "+map cp_badlands"
      ];
      ports.game = 27015;
    };
  };
}
```

### 3. Deploy and manage

```bash
# Rebuild system
sudo nixos-rebuild switch
```

## Using Presets

The module includes presets for popular games:

```nix
{ config, lib, pkgs, ... }:

let
  presets = import ./modules/steamcmd-servers/presets.nix { inherit lib; };
in
{
  services.steamcmd-servers.servers = {
    # Use preset with custom port
    tf2 = lib.recursiveUpdate presets.tf2 {
      enable = true;
      ports.game = 27015;
    };

    # Valheim with custom settings
    valheim = lib.recursiveUpdate presets.valheim {
      enable = true;
      executableArgs = [
        "-name \"My Server\""
        "-port 2456"
        "-world MyWorld"
        "-password secret"
      ];
    };
  };
}
```

### Available Presets

| Preset           | App ID  | Description           |
| ---------------- | ------- | --------------------- |
| `cs2`            | 730     | Counter-Strike 2      |
| `tf2`            | 232250  | Team Fortress 2       |
| `gmod`           | 4020    | Garry's Mod           |
| `rust`           | 258550  | Rust                  |
| `valheim`        | 896660  | Valheim               |
| `ark`            | 376030  | ARK: Survival Evolved |
| `projectZomboid` | 380870  | Project Zomboid       |
| `sevenDaysToDie` | 294420  | 7 Days to Die         |
| `l4d2`           | 222860  | Left 4 Dead 2         |
| `satisfactory`   | 1690800 | Satisfactory          |
| `palworld`       | 2394010 | Palworld              |
| `enshrouded`     | 2278520 | Enshrouded            |
| `vRising`        | 1829350 | V Rising              |
| `terraria`       | 105600  | Terraria              |
| `dstTogether`    | 343050  | Don't Starve Together |

## Configuration Options

### Global Options

```nix
services.steamcmd-servers = {
  enable = true;

  # Base directory for all server data
  dataDir = "/var/lib/steamcmd-servers";

  # User/group for server processes
  user = "steamcmd";
  group = "steamcmd";

  # Automatically configure firewall
  openFirewall = true;

  # Update schedule
  updates = {
    automatic = true;
    schedule = "04:00";              # Daily at 4 AM
    # Or use full OnCalendar format:
    # schedule = "Sun *-*-* 04:00:00";  # Sundays at 4 AM
    randomDelay = "15min";
  };
};
```

### Per-Server Options

```nix
servers.myserver = {
  enable = true;

  # Steam app configuration
  appId = "232250";
  appIdName = "My Game Server";
  beta = null;              # Beta branch name
  betaPassword = null;      # Beta branch password
  validate = true;          # Validate files on update

  # Authentication (most servers work with anonymous)
  anonymous = true;
  steamUsername = null;
  steamPasswordFile = null;

  # Executable configuration
  executable = "server_binary";
  executableArgs = [ "-arg1" "+arg2" ];

  # Lifecycle hooks
  preStart = "";
  postStart = "";
  postStop = "";

  # Environment variables
  environment = {
    MY_VAR = "value";
  };

  # Networking
  ports = {
    game = 27015;
    query = null;           # Defaults to game port
    rcon = null;
    extraPorts = [
      { port = 27016; protocol = "udp"; }
      { port = 8080; protocol = "tcp"; }
    ];
  };

  # Resource limits
  resources = {
    memoryLimit = "4G";
    cpuQuota = "200%";      # 200% = 2 CPU cores
    nice = 0;               # -20 to 19
  };

  # Service behavior
  autoStart = true;
  restartOnFailure = true;
  restartSec = 10;

  # Update behavior
  autoUpdate = true;
  stopBeforeUpdate = true;

  # Extra steamcmd commands
  extraSteamcmdCommands = [
    "workshop_download_item 440 123456789"
  ];
};
```

## Management CLI

The `steamcmd-ctl` utility provides convenient server management:

```bash
# List all servers
steamcmd-ctl list

# Server status
steamcmd-ctl status          # All servers
steamcmd-ctl status tf2      # Specific server

# Start/stop/restart
steamcmd-ctl start tf2
steamcmd-ctl stop tf2
steamcmd-ctl restart tf2

# View logs (follows by default)
steamcmd-ctl logs tf2        # Last 50 lines
steamcmd-ctl logs tf2 100    # Last 100 lines

# Trigger updates
steamcmd-ctl update          # All servers
steamcmd-ctl update tf2      # Specific server
```

## Systemd Services

Each server creates these systemd units:

- `steamcmd-server-<name>.service` - The game server
- `steamcmd-update.service` - Update job (oneshot)
- `steamcmd-update.timer` - Update schedule

```bash
# Direct systemd commands also work
sudo systemctl status steamcmd-server-tf2
sudo journalctl -u steamcmd-server-tf2 -f
```

## Security

The module applies these hardening measures by default:

- Dedicated system user/group
- `NoNewPrivileges=true`
- `PrivateTmp=true`
- `ProtectSystem=strict`
- `ProtectHome=true`
- Restricted write paths
- Kernel tunables/modules protection

## Authenticated Downloads

Some games require Steam account authentication:

```nix
servers.privateGame = {
  enable = true;
  appId = "123456";
  anonymous = false;
  steamUsername = "myaccount";
  steamPasswordFile = "/run/secrets/steam-password";
};
```

Account with steam guard will have to auth with steam mobile app.

## Workshop Content

Download workshop items during installation/updates:

```nix
servers.gmod = {
  enable = true;
  appId = "4020";
  extraSteamcmdCommands = [
    "workshop_download_item 4020 131759821"  # TTT
    "workshop_download_item 4020 180713847"  # ULX
    "workshop_download_item 4020 104482086"  # Wiremod
  ];
};
```

## Troubleshooting

### Server won't start

1. Check logs: `steamcmd-ctl logs <server>`
2. Verify installation: Check if files exist in data directory
3. Manual steamcmd run: `sudo -u steamcmd steamcmd +runscript /etc/steamcmd-servers/<server>.txt`

### Update failures

1. Check network connectivity
2. Verify disk space
3. Try manual update with verbose output

### Permission issues

Ensure the data directory is owned by the steamcmd user:

```bash
sudo chown -R steamcmd:steamcmd /var/lib/steamcmd-servers
```

## Contributing

Issues and PRs welcome. Please test changes with the included NixOS test:

```bash
nix flake check
```

Sandbox test, though, is not sufficient for verifing configuration for concrete games. Because checks are done in virtual machine, and virtual machine doesn't have network access so steamcmd can't fetch game content. But given this flake should NOT handle and is NOT responsible for what is under the hood of steamcmd, flake check still need to pass.

## License

MIT
