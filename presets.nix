{lib, ...}:
# Common game server presets
# Usage: services.steamcmd-servers.servers.myserver = lib.recursiveUpdate presets.csgo { ... };
with lib; {
  # Counter-Strike 2
  cs2 = {
    appId = "730";
    appIdName = "Counter-Strike 2";
    executable = "game/bin/linuxsteamrt64/cs2";
    executableArgs = [
      "-dedicated"
      "-console"
      "+game_type 0"
      "+game_mode 0"
      "+map de_dust2"
      "+sv_setsteamaccount CHANGEME"
    ];
    ports = {
      game = 27015;
      extraPorts = [
        {
          port = 27020;
          protocol = "udp";
        } # TV port
      ];
    };
    environment = {
      LD_LIBRARY_PATH = "./game/bin/linuxsteamrt64";
    };
    resources.memoryLimit = "8G";
  };

  # Team Fortress 2
  tf2 = {
    appId = "232250";
    appIdName = "Team Fortress 2 Dedicated Server";
    executable = "srcds_run";
    executableArgs = [
      "-game tf"
      "+maxplayers 24"
      "+map cp_badlands"
      "-norestart"
    ];
    ports.game = 27015;
    resources.memoryLimit = "4G";
  };

  # Garry's Mod
  gmod = {
    appId = "4020";
    appIdName = "Garry's Mod Dedicated Server";
    executable = "srcds_run";
    executableArgs = [
      "-game garrysmod"
      "+maxplayers 16"
      "+map gm_construct"
      "-norestart"
    ];
    ports.game = 27015;
    resources.memoryLimit = "4G";
  };

  # Rust
  rust = {
    appId = "258550";
    appIdName = "Rust Dedicated Server";
    executable = "RustDedicated";
    executableArgs = [
      "-batchmode"
      "+server.port 28015"
      "+rcon.port 28016"
      "+server.level Procedural Map"
      "+server.seed 12345"
      "+server.worldsize 4000"
      "+server.maxplayers 100"
      "+server.hostname \"Rust Server\""
    ];
    ports = {
      game = 28015;
      rcon = 28016;
    };
    resources.memoryLimit = "12G";
  };

  # Valheim
  valheim = {
    appId = "896660";
    appIdName = "Valheim Dedicated Server";
    executable = "valheim_server.x86_64";
    executableArgs = [
      "-name \"Valheim Server\""
      "-port 2456"
      "-world Dedicated"
      "-password secret"
      "-public 1"
    ];
    ports = {
      game = 2456;
      extraPorts = [
        {
          port = 2457;
          protocol = "udp";
        }
        {
          port = 2458;
          protocol = "udp";
        }
      ];
    };
    environment = {
      LD_LIBRARY_PATH = "./linux64";
      SteamAppId = "892970";
    };
    resources.memoryLimit = "4G";
  };

  # ARK: Survival Evolved
  ark = {
    appId = "376030";
    appIdName = "ARK: Survival Evolved Server";
    executable = "ShooterGame/Binaries/Linux/ShooterGameServer";
    executableArgs = [
      "TheIsland?listen?SessionName=ArkServer"
      "-server"
      "-log"
      "-NoBattlEye"
    ];
    ports = {
      game = 7777;
      query = 27015;
      extraPorts = [
        {
          port = 7778;
          protocol = "udp";
        }
      ];
    };
    resources.memoryLimit = "16G";
    resources.cpuQuota = "400%";
  };

  # Project Zomboid
  projectZomboid = {
    appId = "380870";
    appIdName = "Project Zomboid Server";
    executable = "start-server.sh";
    executableArgs = [
      "-servername servertest"
    ];
    ports = {
      game = 16261;
      extraPorts = [
        {
          port = 16262;
          protocol = "udp";
        }
      ];
    };
    resources.memoryLimit = "8G";
  };

  # Minecraft (via SteamCMD-adjacent - note: Minecraft isn't on Steam,
  # but this shows the pattern for manual download servers)
  # This is more of a template showing how to handle non-Steam servers
  # with a similar management approach

  # 7 Days to Die
  sevenDaysToDie = {
    appId = "294420";
    appIdName = "7 Days to Die Dedicated Server";
    executable = "7DaysToDieServer.x86_64";
    executableArgs = [
      "-logfile logs/output_log.txt"
      "-configfile serverconfig.xml"
      "-batchmode"
      "-nographics"
      "-dedicated"
    ];
    ports = {
      game = 26900;
      extraPorts = [
        {
          port = 26901;
          protocol = "udp";
        }
        {
          port = 26902;
          protocol = "udp";
        }
        {
          port = 8080;
          protocol = "tcp";
        } # Web panel
        {
          port = 8081;
          protocol = "tcp";
        } # Telnet
      ];
    };
    resources.memoryLimit = "8G";
  };

  # Left 4 Dead 2
  l4d2 = {
    appId = "222860";
    appIdName = "Left 4 Dead 2 Dedicated Server";
    executable = "srcds_run";
    executableArgs = [
      "-game left4dead2"
      "+maxplayers 8"
      "+map c1m1_hotel"
      "-norestart"
    ];
    ports.game = 27015;
    resources.memoryLimit = "2G";
  };

  # Satisfactory
  satisfactory = {
    appId = "1690800";
    appIdName = "Satisfactory Dedicated Server";
    beta = "experimental"; # Often needed for latest version
    executable = "FactoryServer.sh";
    executableArgs = [
      "-unattended"
      "-Port=7777"
      "-ServerQueryPort=15777"
      "-BeaconPort=15000"
    ];
    ports = {
      game = 7777;
      query = 15777;
      extraPorts = [
        {
          port = 15000;
          protocol = "udp";
        }
      ];
    };
    resources.memoryLimit = "12G";
  };

  # Palworld
  palworld = {
    appId = "2394010";
    appIdName = "Palworld Dedicated Server";
    executable = "PalServer.sh";
    executableArgs = [
      "-useperfthreads"
      "-NoAsyncLoadingThread"
      "-UseMultithreadForDS"
      "EpicApp=PalServer"
    ];
    ports = {
      game = 8211;
      query = 27015;
    };
    environment = {
      LD_LIBRARY_PATH = "./linux64";
    };
    resources.memoryLimit = "16G";
    resources.cpuQuota = "400%";
  };

  # Enshrouded
  enshrouded = {
    appId = "2278520";
    appIdName = "Enshrouded Dedicated Server";
    executable = "enshrouded_server.exe"; # Runs via Proton
    executableArgs = [];
    ports = {
      game = 15636;
      query = 15637;
    };
    resources.memoryLimit = "16G";
  };

  # V Rising
  vRising = {
    appId = "1829350";
    appIdName = "V Rising Dedicated Server";
    executable = "VRisingServer.exe"; # Runs via Proton/Wine
    executableArgs = [
      "-persistentDataPath ./save-data"
      "-serverName \"V Rising Server\""
      "-saveName world1"
    ];
    ports = {
      game = 9876;
      query = 9877;
    };
    resources.memoryLimit = "8G";
  };

  # Terraria (tShock)
  terraria = {
    appId = "105600";
    appIdName = "Terraria Server";
    executable = "TerrariaServer.bin.x86_64";
    executableArgs = [
      "-config serverconfig.txt"
    ];
    ports = {
      game = 7777;
      extraPorts = [
        {
          port = 7878;
          protocol = "tcp";
        } # REST API
      ];
    };
    resources.memoryLimit = "2G";
  };

  # Don't Starve Together
  dstTogether = {
    appId = "343050";
    appIdName = "Don't Starve Together Server";
    executable = "bin64/dontstarve_dedicated_server_nullrenderer_x64";
    executableArgs = [
      "-console"
      "-cluster MyDediServer"
      "-shard Master"
    ];
    ports = {
      game = 10999;
      extraPorts = [
        {
          port = 10998;
          protocol = "udp";
        } # Caves shard
      ];
    };
    resources.memoryLimit = "4G";
  };
}
