{
  description = "A very basic flake";

  inputs.cc-server.url = "github:danielbarter/mini_compile_commands";
  inputs.cc-server.flake = false;

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    cc-server,
  }: let
    buildEfi = pkgs: pkgs.callPackage ./. {};
  in
    {
      overlays.default = final: prev: {efi-power = buildEfi prev.pkgs;};
      devShells.x86_64-linux.default = let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;

        shell = (buildEfi pkgs).overrideAttrs (o: {
          OVMF_DIR = "${pkgs.OVMF.fd}/FV";
          nativeBuildInputs = with pkgs; [socat qemu];
        });
      in
        shell;
    }
    // flake-utils.lib.eachSystem (import ./systems.nix) (
      system: let
        supportsLegacy = builtins.elem system nixpkgs.lib.systems.flakeExposed;
        pkgs =
          if supportsLegacy
          then nixpkgs.legacyPackages.${system}
          else import nixpkgs {inherit system;};
      in {
        packages = {
          default = buildEfi pkgs;
        };
      }
    );
}
