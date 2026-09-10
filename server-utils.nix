{
  lib,
  writeShellScriptBin,
  systemd,
  coreutils,
  gnugrep,
  ncurses,
}:
writeShellScriptBin "steamcmd-ctl" ''
    set -euo pipefail

    # Dependencies
    SYSTEMCTL="${systemd}/bin/systemctl"
    JOURNALCTL="${systemd}/bin/journalctl"
    GREP="${gnugrep}/bin/grep"
    TPUT="${ncurses}/bin/tput"

    # Colors (with fallback for non-interactive)
    if [ -t 1 ]; then
      RED=$($TPUT setaf 1 2>/dev/null || echo "")
      GREEN=$($TPUT setaf 2 2>/dev/null || echo "")
      YELLOW=$($TPUT setaf 3 2>/dev/null || echo "")
      BLUE=$($TPUT setaf 4 2>/dev/null || echo "")
      BOLD=$($TPUT bold 2>/dev/null || echo "")
      RESET=$($TPUT sgr0 2>/dev/null || echo "")
    else
      RED="" GREEN="" YELLOW="" BLUE="" BOLD="" RESET=""
    fi

    usage() {
      cat <<EOF
  ''${BOLD}steamcmd-ctl''${RESET} - SteamCMD Server Management Utility

  ''${BOLD}USAGE:''${RESET}
      steamcmd-ctl <COMMAND> [OPTIONS]

  ''${BOLD}COMMANDS:''${RESET}
      ''${GREEN}list''${RESET}                      List all configured servers with status
      ''${GREEN}status''${RESET} [SERVER]           Show detailed status (all or specific)
      ''${GREEN}start''${RESET} <SERVER>            Start a server
      ''${GREEN}stop''${RESET} <SERVER>             Stop a server (graceful)
      ''${GREEN}restart''${RESET} <SERVER>          Restart a server
      ''${GREEN}logs''${RESET} <SERVER> [OPTIONS]   Show server logs
      ''${GREEN}update''${RESET} [SERVER]           Update servers (all or specific)

  ''${BOLD}LOG OPTIONS:''${RESET}
      -n, --lines <N>           Number of lines to show (default: 50)
      -f, --follow              Follow log output (like tail -f)

  ''${BOLD}EXAMPLES:''${RESET}
      steamcmd-ctl list
      steamcmd-ctl status tf2
      steamcmd-ctl logs rust -n 100
      steamcmd-ctl logs tf2 -f
      steamcmd-ctl update

  ''${BOLD}SYSTEMD INTEGRATION:''${RESET}
      Services are named: steamcmd-server-<name>
      Timer for updates:  steamcmd-update.timer

  EOF
    }

    # Check if a server exists
    server_exists() {
      local server="$1"
      $SYSTEMCTL list-unit-files "steamcmd-server-$server.service" --no-legend 2>/dev/null | $GREP -q .
    }

    # Validate server name
    require_server() {
      local server="$1"
      if [ -z "$server" ]; then
        echo "''${RED}Error:''${RESET} Server name required" >&2
        exit 1
      fi
      if ! server_exists "$server"; then
        echo "''${RED}Error:''${RESET} Server '$server' not found" >&2
        echo "Use '$(basename "$0") list' to see available servers" >&2
        exit 1
      fi
    }

    list_servers() {
      echo "''${BOLD}Configured SteamCMD Servers''${RESET}"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""

      local found=0
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        found=1

        local unit state
        unit=$(echo "$line" | awk '{print $1}')

        # Extract server name
        local server_name="''${unit#steamcmd-server-}"
        server_name="''${server_name%.service}"

        # Get status
        if $SYSTEMCTL is-active --quiet "$unit" 2>/dev/null; then
          state="''${GREEN}● running''${RESET}"
        elif $SYSTEMCTL is-failed --quiet "$unit" 2>/dev/null; then
          state="''${RED}✗ failed''${RESET}"
        else
          state="''${YELLOW}○ stopped''${RESET}"
        fi

        printf "  %-24s %s\n" "$server_name" "$state"
      done < <($SYSTEMCTL list-unit-files 'steamcmd-server-*.service' --no-legend 2>/dev/null)

      if [ "$found" = "0" ]; then
        echo "  ''${YELLOW}No servers configured''${RESET}"
        echo ""
        echo "  Add servers via your NixOS configuration:"
        echo "    services.steamcmd-servers.servers.myserver = { ... };"
      fi

      echo ""

      # Show update timer status
      if $SYSTEMCTL is-active --quiet steamcmd-update.timer 2>/dev/null; then
        local next_run
        next_run=$($SYSTEMCTL show steamcmd-update.timer --property=NextElapseUSecRealtime --value 2>/dev/null | head -1)
        echo "''${BOLD}Update Timer:''${RESET} ''${GREEN}active''${RESET}"
        if [ -n "$next_run" ] && [ "$next_run" != "n/a" ]; then
          echo "  Next update: $next_run"
        fi
      else
        echo "''${BOLD}Update Timer:''${RESET} ''${YELLOW}inactive''${RESET}"
      fi
    }

    server_status() {
      local server="$1"
      if [ -z "$server" ]; then
        echo "''${BOLD}All Server Status''${RESET}"
        echo ""
        $SYSTEMCTL status 'steamcmd-server-*' --no-pager 2>/dev/null || true
      else
        require_server "$server"
        $SYSTEMCTL status "steamcmd-server-$server" --no-pager
      fi
    }

    start_server() {
      local server="$1"
      require_server "$server"

      echo "''${BLUE}→''${RESET} Starting $server..."
      if $SYSTEMCTL start "steamcmd-server-$server"; then
        echo "''${GREEN}✓''${RESET} Server $server started"
      else
        echo "''${RED}✗''${RESET} Failed to start $server"
        echo "  Check logs with: steamcmd-ctl logs $server"
        exit 1
      fi
    }

    stop_server() {
      local server="$1"
      require_server "$server"

      echo "''${BLUE}→''${RESET} Stopping $server..."
      if $SYSTEMCTL stop "steamcmd-server-$server"; then
        echo "''${GREEN}✓''${RESET} Server $server stopped"
      else
        echo "''${RED}✗''${RESET} Failed to stop $server"
        exit 1
      fi
    }

    restart_server() {
      local server="$1"
      require_server "$server"

      echo "''${BLUE}→''${RESET} Restarting $server..."
      if $SYSTEMCTL restart "steamcmd-server-$server"; then
        echo "''${GREEN}✓''${RESET} Server $server restarted"
      else
        echo "''${RED}✗''${RESET} Failed to restart $server"
        echo "  Check logs with: steamcmd-ctl logs $server"
        exit 1
      fi
    }

    show_logs() {
      local server=""
      local lines=50
      local follow=0

      # Parse arguments
      while [ $# -gt 0 ]; do
        case "$1" in
          -n|--lines)
            lines="$2"
            shift 2
            ;;
          -f|--follow)
            follow=1
            shift
            ;;
          -*)
            echo "''${RED}Error:''${RESET} Unknown option: $1" >&2
            exit 1
            ;;
          *)
            if [ -z "$server" ]; then
              server="$1"
            fi
            shift
            ;;
        esac
      done

      require_server "$server"

      local args=("-u" "steamcmd-server-$server" "-n" "$lines" "--no-pager")
      if [ "$follow" = "1" ]; then
        args+=("-f")
      fi

      $JOURNALCTL "''${args[@]}"
    }

    update_servers() {
      local server="''${1:-}"

      if [ -z "$server" ]; then
        echo "''${BLUE}→''${RESET} Triggering update for all servers..."
        if $SYSTEMCTL start steamcmd-update.service; then
          echo "''${GREEN}✓''${RESET} Update job started"
          echo ""
          echo "Monitor progress with:"
          echo "  journalctl -u steamcmd-update -f"
        else
          echo "''${RED}✗''${RESET} Failed to start update job"
          exit 1
        fi
      else
        require_server "$server"

        echo "''${BOLD}Updating $server''${RESET}"
        echo ""

        local was_running=0
        if $SYSTEMCTL is-active --quiet "steamcmd-server-$server"; then
          echo "''${BLUE}→''${RESET} Stopping server for update..."
          $SYSTEMCTL stop "steamcmd-server-$server" || true
          was_running=1
        fi

        echo "''${BLUE}→''${RESET} Running SteamCMD update..."
        local script_path="/etc/steamcmd-servers/$server.txt"

        if [ ! -f "$script_path" ]; then
          # Fallback: use systemd to reinstall
          echo "  (Reinstalling via service preStart)"
          rm -f "/var/lib/steamcmd-servers/servers/$server/.installed" 2>/dev/null || true
        else
          if sudo -u steamcmd steamcmd +runscript "$script_path"; then
            echo "''${GREEN}✓''${RESET} Update successful"
          else
            echo "''${RED}✗''${RESET} Update failed"
          fi
        fi

        if [ "$was_running" = "1" ]; then
          echo "''${BLUE}→''${RESET} Restarting server..."
          if $SYSTEMCTL start "steamcmd-server-$server"; then
            echo "''${GREEN}✓''${RESET} Server restarted"
          else
            echo "''${RED}✗''${RESET} Failed to restart"
          fi
        fi
      fi
    }

    # Main command dispatch
    case "''${1:-}" in
      list|ls)
        list_servers
        ;;
      status|st)
        server_status "''${2:-}"
        ;;
      start)
        start_server "''${2:-}"
        ;;
      stop)
        stop_server "''${2:-}"
        ;;
      restart)
        restart_server "''${2:-}"
        ;;
      logs|log)
        shift
        show_logs "$@"
        ;;
      update|up)
        update_servers "''${2:-}"
        ;;
      help|--help|-h)
        usage
        ;;
      "")
        usage
        ;;
      *)
        echo "''${RED}Error:''${RESET} Unknown command: $1" >&2
        echo "Run 'steamcmd-ctl help' for usage" >&2
        exit 1
        ;;
    esac
''
