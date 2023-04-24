{
  description = "A very basic flake";

  inputs.neovim-flake.url = "github:jordanisaacs/neovim-flake";

  inputs.cc-server.url = "github:danielbarter/mini_compile_commands";
  inputs.cc-server.flake = false;

  outputs = {
    self,
    nixpkgs,
    neovim-flake,
    cc-server,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    editor = neovim-flake.packages.${system}.nix.extendConfiguration {
      modules = [
        {
          vim.languages.clang.enable = true;
          vim.git.gitsigns.codeActions = false;
        }
      ];
      inherit pkgs;
    };

    cc-stdenv = (pkgs.callPackage cc-server {}).wrap pkgs.stdenv;

    nativeBuildInputs = with pkgs; [socat gdb];

    buildInputs = with pkgs; [gnu-efi];
  in {
    packages.${system}.default = pkgs.stdenv.mkDerivation {
      name = "efi-power";
      src = ./.;
      EFI_DIR = pkgs.gnu-efi;
      hardeningDisable = ["stackprotector"];
      makeFlags = ["DESTDIR=$(out)"];
      inherit buildInputs;
    };

    devShells.${system}.default = (pkgs.mkShell.override {stdenv = cc-stdenv;}) {
      EFI_DIR = pkgs.gnu-efi;
      OVMF_PATH = "${pkgs.OVMF.fd}/FV";
      hardeningDisable = ["stackprotector"];
      nativeBuildInputs = nativeBuildInputs ++ [editor pkgs.qemu];
      inherit buildInputs;
    };
  };
}
