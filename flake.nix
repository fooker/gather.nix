{
  inputs = {
  };

  outputs = { ... }: rec {
    nixosModules = rec {
      gather = import ./gather.nix;
      default = gather;
    };
    nixosModule = nixosModules.default;
  };
}