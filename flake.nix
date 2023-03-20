{
  description = "Stablesats documentation in mdbook";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs }: {
    packages.mdbook = nixpkgs.mdbook;

    defaultPackage = self.packages.mdbook;
  };
}
