{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.virtualisation.incus.resources;
in
  with lib; {
    options.virtualisation.incus.resources = {
      enable = mkEnableOption "Whether to enable declarative incus resource management";
      projects = mkOption {
        description = "Incus projects";
        default = {};
        type = types.attrsOf (types.submodule {
          options = {
            description = mkOption {
              description = "Description of the project";
              default = null;
              type = types.nullOr types.str;
            };
            features = mkOption {
              description = "Project features to enable";
              default = {};
              type = types.submodule {
                options = {
                  volumes = mkOption {
                    description = "Use a separate set of storage volumes";
                    default = null;
                    type = types.nullOr types.bool;
                  };
                  images = mkOption {
                    description = "Use a separate set of images";
                    default = null;
                    type = types.nullOr types.bool;
                  };
                  profiles = mkOption {
                    description = "Use a separate set of projects";
                    default = null;
                    type = types.nullOr types.bool;
                  };
                };
              };
            };
          };
        });
      };
      instances = mkOption {
        description = "Incus projects";
        default = {};
        type = types.attrsOf (types.submodule {
          options = {
            description = mkOption {
              description = "Description of the instance";
              default = null;
              type = types.nullOr types.str;
            };
            project = mkOption {
              description = "Name of the associated project";
              default = null;
              type = types.nullOr types.str;
            };
            image = mkOption {
              description = "Image of the instance";
              type = types.nullOr types.str;
            };
            devices = mkOption {
              description = "Devices of the instance";
              default = {};
              type = types.attrsOf (types.submodule {
                options = {
                  type = mkOption {
                    description = "Type of the device";
                    type = types.str;
                  };
                  properties = mkOption {
                    description = "Properties of the device";
                    type = types.attrs;
                    default = {};
                  };
                };
              });
            };
          };
        });
      };
      networks = mkOption {
        description = "Incus networks";
        default = {};
        type = types.attrsOf (types.submodule {
          options = {
            type = mkOption {
              description = "Type of the network";
              type = types.str;
            };
            description = mkOption {
              description = "Description of the network";
              default = null;
              type = types.nullOr types.str;
            };
            project = mkOption {
              description = "Name of the associated project";
              default = null;
              type = types.nullOr types.str;
            };
            properties = mkOption {
              description = "Properties of the network";
              type = types.attrs;
              default = {};
            };
          };
        });
      };
    };
    config = let
      boolToString = value:
        if value
        then "true"
        else "false";
      buildNetworkBlock = network_name: network: ''
        resource "incus_network" "${network_name}" {
          name = "${network_name}"
          ${
          if network.description != null
          then "description = \"${network.description}\""
          else ""
        }
          ${
          if network.project != null
          then "project = \"${network.project}\""
          else ""
        }
          ${
          if network.type != null
          then "type = \"${network.type}\""
          else ""
        }

          config = {
            ${concatStringsSep "\n" (mapAttrsToList (name: value: "${name} = \"${value}\"") network.properties)}
          }
        }
      '';
      buildDeviceBlock = device_name: device: ''
        device {
          name = "${device_name}"
          type = "${device.type}"

          properties = {
            ${concatStringsSep "\n" (mapAttrsToList (name: value: "${name} = \"${value}\"") device.properties)}
          }
        }
      '';
      buildProjectBlock = project_name: project: ''
        resource "incus_project" "${project_name}" {
          name = "${project_name}"
          ${
          if project.description != null
          then "description = \"${project.description}\""
          else ""
        }

          config = {
            ${
          if project.features.volumes != null
          then "\"features.storage.volumes\" = ${boolToString project.features.volumes}"
          else ""
        }
            ${
          if project.features.images != null
          then "\"features.images\" = ${boolToString project.features.images}"
          else ""
        }
            ${
          if project.features.profiles != null
          then "\"features.profiles\" = ${boolToString project.features.profiles}"
          else ""
        }
          }
        }
      '';
      buildInstanceBlock = instance_name: instance: ''
        resource "incus_instance" "${instance_name}" {
          name = "${instance_name}"
          image = "${instance.image}"
          ${
          if instance.project != null
          then "project = \"${instance.project}\""
          else ""
        }

          ${concatStringsSep "\n\n" (mapAttrsToList (name: value: buildDeviceBlock name value) instance.devices)}
        }
      '';
      terraform_text = ''
        terraform {
          required_providers {
            incus = {
              source = "lxc/incus"
              version = "1.1.0"
            }
          }
        }

        provider "incus" {}

        ${concatStringsSep "\n\n" (mapAttrsToList (name: value: buildProjectBlock name value) cfg.projects)}

        ${concatStringsSep "\n\n" (mapAttrsToList (name: value: buildNetworkBlock name value) cfg.networks)}

        ${concatStringsSep "\n\n" (mapAttrsToList (name: value: buildInstanceBlock name value) cfg.instances)}
      '';
      applicationScriptText = ''
        STATE_DIR=/var/lib/incus-resources

        mkdir -p "$STATE_DIR"

        cat > "$STATE_DIR/incus.tf" << 'EOF'
        ${terraform_text}
        EOF

        ${pkgs.opentofu}/bin/tofu -chdir="$STATE_DIR" init
        ${pkgs.opentofu}/bin/tofu -chdir="$STATE_DIR" apply -auto-approve
      '';
      applicationScript = pkgs.writeShellScriptBin "incus-tofu-apply" applicationScriptText;
    in {
      systemd.services.incus-setup-resources = mkIf cfg.enable {
        wantedBy = ["default.target"];
        after = ["multi-user.target"];
        description = "Incus resource synchronization service";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${applicationScript}/bin/incus-tofu-apply";
        };
      };
    };
  }
