# Incus.nix - declarative incus resource management

### DISCLAIMER: This is still in its early stages, and only the features I need have been implemented. If you need anything else, either create a pull request (PR) or an issue.

# Usage

```nix
{
  inputs = {
    incus.url = "github:mohrjonas/incus.nix";
  };
  outputs = { incus, ... }: {
    nixosConfigurations.<something> = nixpkgs.lib.nixosSystem {
      modules = [
        incus.nixosModules.incus
      ];
    };
  };
}
```

# Options

Currently, creating
- projects
- networks
- instances

are supported.

Sample:

```nix
virtualisation.incus = {
    enable = true;
    resources = {
        enable = true;
        projects = {
            testProject = {
                description = "This is a test project";
                features.images = true;
            };
        };
        networks = {
            maclan = {
                type = "macvlan";
                project = "testProject";
                description = "This is a test network";
                properties = {
                    parent = "enp0s3";
                };
            };
        };
        instances = {
            sample = {
                description = "This is a test instance";
                image = "images:ubuntu/questing";
                project = "testProject";
                devices = {
                    rootDisk = {
                        type = "disk";
                        properties = {
                            path = "/";
                            pool = "default";
                        };
                    };
                    net = {
                        type = "nic";
                        properties = {
                            network = "macvlan";
                        };
                    };
                };
            };
        };
    };
};
```