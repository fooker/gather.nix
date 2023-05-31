NixOS module to gather a declarative list of data from a remote host.

The module allows a machine to define a set of information to be exported and gathered by calling a single script in a well-know path.
This is useful in conjunction with a deployment tool like colmena or morph.

## Usage

### Install the module using flakes
```
{
  inputs.gather.url = "github:fooker/gather.nix";

  outputs = { nixpkgs, gather, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      modules = [
        gather.nixosModules.gather
        ./configuration.nix
      ];
    };
  };
}
```

### Install the module using `fetchTarball`

```
{
  imports = [
    "${builtins.fetchTarball "https://github.com/fooker/gather.nix/archive/main.tar.gz"}/gather.nix"
  ];
}
```

### Using the module:

```
{ pkgs, config, ... }: {
  gather.target = part: "gathered/yourhostname/${part}";
  gather.root = ./.;

  gather.parts."ssh/hostKey/ed25519" = {
    name = "ssh_host_ed25519_key.pub";
    file = "/etc/ssh/ssh_host_ed25519_key.pub";
  };

  gather.parts."wireguard/publicKey" = {
    name = "wg.pub"
    command = ''
      ${pkgs.wireguard-tools}/bin/wg pubkey < /run/secrets/wg.key
    '';
  }

  example.option.file = config.gather.parts."ssh/hostKey/ed25519".path;
}
```

### Creating the tarball

The gather script is linked to `/run/gather` which will create a tar archive on stdout:

```
/run/gather > gather.tar
```
