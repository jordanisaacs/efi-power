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
    hostpkgs = nixpkgs.legacyPackages.${system};
    editor = neovim-flake.packages.${system}.nix.extendConfiguration {
      modules = [
        {
          vim.languages.clang.enable = true;
          vim.git.gitsigns.codeActions = false;
        }
      ];
      pkgs = hostpkgs;
    };

    buildEfi = pkgs:
      pkgs.stdenv.mkDerivation {
        name = "efi-power";
        src = ./.;

        buildInputs = [pkgs.gnu-efi];

        hardeningDisable = ["stackprotector"];

        makeFlags = [
          "EFIDIR=${pkgs.gnu-efi}"
          "DESTDIR=$(out)"
          "HOSTCC=${pkgs.buildPackages.stdenv.cc.targetPrefix}cc"
          "CROSS_COMPILE=${pkgs.stdenv.cc.targetPrefix}"
        ];

        EFI_DIR = pkgs.gnu-efi;
      };

    buildShell = pkgs:
      (buildEfi pkgs).overrideAttrs (o: {
        OVMF_PATH = "${pkgs.OVMF.fd}/FV";
        nativeBuildInputs = with hostpkgs; [editor socat qemu];
      });

    pkgs = import nixpkgs {
      inherit system;
      crossSystem = {
        config = "aarch64-unknown-linux-gnu";
      };
    };
  in {
    packages.${system}.default = buildEfi pkgs;

    devShells.${system}.default = buildShell pkgs;
  };
}
