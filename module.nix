{ lib
, config
, pkgs
, ...
}:
with lib;
let
  cfg = config.programs.xin;
  statCfg = config.programs.xin-status;
  stgs = config.programs.xin-status.settings;
  cmdStr = ''command="/run/current-system/sw/bin/xin",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty'';
  mkCommandKeys = keyList:
    map (key: ''${cmdStr} ${key}'') keyList;
  hostStatusModule = types.submodule {
    options = {
      name = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional name for the host";
      };

      host = mkOption {
        type = types.str;
        description = "Hostname or IP address";
      };

      port = mkOption {
        type = types.int;
        default = 22;
        description = "SSH port number";
      };

      mac = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "MAC address of the host (optional)";
      };
    };
  };
in
{
  options = {
    programs.xin-status = {
      enable = mkEnableOption "Enable xin-status";
      settings = {
        repository = mkOption {
          type = types.str;
          description = "Path to the on-disk git repository that represents your flake config.";
        };
        privKeyPath = mkOption {
          type = types.path;
          description = "Path to the openssh private key.";
        };
        flakeRss = mkOption {
          type = types.str;
          description = "URL to the rss feed containing commit info for your flake";
        };
        statuses = mkOption {
          type = types.listOf hostStatusModule;
        };
        ciHost = mkOption {
          type = types.str;
          description = "Host to use for CI";
        };
      };
    };
    programs.xin = {
      enable = mkEnableOption "Enable xin";
      monitorKeys = mkOption {
        type = types.listOf types.singleLineStr;
        default = [ ];
        description = ''
          A list of OpenSSH public keys that will be permitted to run `xin` commands.
        '';
        example = [
          "ssh-rsa AA....06 key@host"
          "ssh-ed25519 AA....MZJ otherkey@otherhost"
        ];
      };
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable) {
      users.users.root.openssh.authorizedKeys.keys = mkCommandKeys cfg.monitorKeys;
      environment.systemPackages = [ pkgs.xin ];
    })
    (mkIf (statCfg.enable) {
      environment = {
        systemPackages = [ pkgs.xin-status ];
        etc = {
          "xin/xin-status.json" = {
            text = builtins.toJSON {
              repo = stgs.repository;
              priv_key_path = stgs.privKeyPath;
              flake_rss = stgs.flakeRss;
              inherit (stgs) statuses;
              ci_host = stgs.ciHost;
            };
          };
        };
      };
    })
  ];
}
