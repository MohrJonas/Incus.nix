{
  description = "Incus declarative resources module";

  outputs = {
    self,
    nixpkgs,
    ...
  }: {
    nixosModules.incus = ./incus.nix;
  };
}
