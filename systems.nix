# From gnu-efi supported systems
# Used for direct flake support (aka native compilation)
# commented out systems do not support pure linux stdenv
[
  "aarch64-linux"
  # "armv5tel-linux" - missing from nixpkgs even though in gnu-efi supported systems
  "armv6l-linux"
  "armv7a-linux"
  "armv7l-linux"
  "i686-linux"
  # "m68k-linux"
  # "microblaze-linux"
  # "microblazeel-linux"
  # "mipsel-linux"
  # "mips64el-linux" - missing from nixpkgs
  # "powerpc64-linux"
  # "powerpc64le-linux" - missing from nixpkgs even though in gnu-efi supported systems
  # "riscv32-linux"
  "riscv64-linux"
  # "s390-linux"
  # "s390x-linux"
  "x86_64-linux"
]
