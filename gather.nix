{ lib, pkgs, config, path, ... }:

with lib;

let
  gatherList = pkgs.writeText "gather-list" (concatMapStringsSep "\n"
    (part: part.target)
    (attrValues config.gather.parts));

  gatherScript = pkgs.writeShellScript "gather" ''
    set -o errexit
    set -o nounset
    set -o pipefail

    SCRATCH="$(mktemp -d)"
    trap 'rm -rf -- "$SCRATCH"' EXIT

    cd "$SCRATCH"

    ${concatMapStringsSep "\n"
      (part: ''
        mkdir -p "$(dirname "${part.target}")"
        ${optionalString (part.file != null) ''
          cp -f "${part.file}" "$SCRATCH/${part.target}"
        ''}
        ${optionalString (part.command != null) ''
          "${pkgs.writeShellScript "gather-${part.name}" part.command}" > "$SCRATCH/${part.target}"
        ''}
      '')
      (attrValues config.gather.parts)}

    ${pkgs.gnutar}/bin/tar c --dereference --files-from "${gatherList}"
  '';

  cfg = config.gather;

in
{
  options.gather = {
    target = mkOption {
      description = ''
        Function to determine target path of a gethered entry.
        The path is relative to project root and must not start with a slash.
        Must be `string -> string`
      '';
      type = types.functionTo (types.addCheck types.nonEmptyStr (x: substring 0 1 x != "/"));
    };

    root = mkOption {
      description = ''
        Path to root of project.
      '';
      type = types.path;
    };

    parts = mkOption {
      description = ''
        Entries to gather from the system.
      '';
      type = types.attrsOf (types.submodule ({ name, config, ... }: {
        options = {
          name = mkOption {
            description = ''
              File name to gather from system.
            '';
            type = types.str;
            default = if config.file != null 
              then baseNameOf config.file
              else name;
          };

          file = mkOption {
            description = ''
              Path of the file to gether.
            '';
            type = types.nullOr types.path;
            apply = mapNullable toString;
            default = null;
          };

          command = mkOption {
            description = ''
              Command to run for output to gether.
            '';
            type = types.nullOr types.lines;
            default = null;
          };

          target = mkOption {
            description = ''
              Target path to copy the gathered data to.
            '';
            type = types.str;
            readOnly = true;
            default = cfg.target config.name;
          };

          path = mkOption {
            description = ''
              Path of the gathered data.
            '';
            type = types.path;
            readOnly = true;
            default = /${cfg.root}/${config.target};
          };
        };
      }));
      default = { };
    };
  };

  config = {
    system.activationScripts.gather = ''
      #!${pkgs.runtimeShell}

      ln -sfn "${gatherScript}" /run/gather
    '';

    assertions = mapAttrsToList
      (name: part: {
        assertion = length (filter (s: s != null) [ part.file part.command ]) == 1;
        message = "Exactly one of `gather.${name}.file` and `gather.${name}.command` must be set.";
      })
      config.gather.parts;
  };
}
