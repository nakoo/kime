{
  description = "Korean IME";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs;
    flake-utils.url = github:numtide/flake-utils;
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = import nixpkgs {
          inherit system;
        }; in
        {
          devShells.default = import ./shell.nix { inherit pkgs; };
          packages.default = import ./default.nix { inherit pkgs; };
        }
      );
}
