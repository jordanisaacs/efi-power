{
  stdenv,
  buildPackages,
  gnu-efi,
}:
stdenv.mkDerivation {
  name = "efi-power";
  src = ./.;

  buildInputs = [gnu-efi];

  hardeningDisable = ["stackprotector"];

  makeFlags = [
    "EFIDIR=${gnu-efi}"
    "DESTDIR=$(out)"
    "HOSTCC=${buildPackages.stdenv.cc.targetPrefix}cc"
    "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
  ];
}
