# Compilation tools
EFIINC := $(EFIDIR)/include/efi
EFILIB := $(EFIDIR)/lib

HOSTCC := $(prefix)gcc
CC := $(prefix)$(CROSS_COMPILE)gcc
LD := $(prefix)$(CROSS_COMPILE)ld
INSTALL := install
DESTDIR ?= /

OS       := $(shell uname -s)
HOSTARCH ?= $(shell $(HOSTCC) -dumpmachine | cut -f1 -d- | sed -e s,i[3456789]86,ia32, -e 's,armv[67].*,arm,' )
ARCH     ?= $(shell $(HOSTCC) -dumpmachine | cut -f1 -d- | sed -e s,i[3456789]86,ia32, -e 's,armv[67].*,arm,' )

TARGETS = poweroff.efi reboot.efi hello.efi

# App subsystem
SUBSYSTEM := 0xa

# Get ARCH from the compiler if cross compiling
ifneq ($(CROSS_COMPILE),)
  override ARCH := $(shell $(CC) -dumpmachine | cut -f1 -d-| sed -e s,i[3456789]86,ia32, -e 's,armv[67].*,arm,' )
endif

ifneq ($(ARCH),arm)
  export LIBGCC=$(shell $(CC) $(CFLAGS) $(ARCH3264) -print-libgcc-file-name)
endif

# FreeBSD (and possibly others) reports amd64 instead of x86_64
ifeq ($(ARCH),amd64)
  override ARCH := x86_64
endif

ifeq ($(ARCH),ia32)
  CFLAGS += -mno-mmx -mno-sse
  ifeq ($(HOSTARCH),x86_64)
	ARCH3264 = -m32
  endif
endif

ifeq ($(ARCH),ia64)
  CFLAGS += -mfixed-range=f32-f127
endif

ifeq ($(ARCH),x86_64)
  CPPFLAGS += -DGNU_EFI_USE_MS_ABI -DGNU_EFI_USE_EXTERNAL_STDARG -maccumulate-outgoing-args
  CFLAGS += -mno-red-zone
endif

ifeq ($(ARCH),mips64el)
  CFLAGS += -march=mips64r2
  ARCH3264 = -mabi=64
endif

ifneq (,$(filter $(ARCH),ia32 x86_64))
  # Disable AVX, if the compiler supports that.
  CC_CAN_DISABLE_AVX=$(shell $(CC) -Werror -c -o /dev/null -xc -mno-avx - </dev/null >/dev/null 2>&1 && echo 1)
  ifeq ($(CC_CAN_DISABLE_AVX), 1)
    CFLAGS += -mno-avx
  endif
endif

# Only enable -fPIE for non MinGW compilers (unneeded on MinGW)
GCCMACHINE := $(shell $(CC) -dumpmachine)
ifneq (mingw32,$(findstring mingw32, $(GCCMACHINE)))
  CFLAGS += -fpie
endif

# Set HAVE_EFI_OBJCOPY if objcopy understands --target efi-[app|bsdrv|rtdrv],
# otherwise we need to compose the PE/COFF header using the assembler
# aarch64 efi objcopy doesn't work
ifeq ($(findstring $(ARCH),arm mips64el riscv64 loongarch64 aarch64),)
  export HAVE_EFI_OBJCOPY=y
endif

ifneq ($(HAVE_EFI_OBJCOPY),)
  FORMAT := --target efi-app-$(ARCH)
else
  LDFLAGS += --defsym=EFI_SUBSYSTEM=$(SUBSYSTEM)
  FORMAT := -O binary
endif

INCDIR          = -I$(EFIINC) -I$(EFIINC)/$(ARCH) -I$(EFIINC)/protocol
CRTOBJS         = $(EFILIB)/crt0-efi-$(ARCH).o
LDSCRIPT        = $(EFILIB)/elf_$(ARCH)_efi.lds
ifneq (,$(findstring FreeBSD,$(OS)))
  LDSCRIPT	= $(TOPDIR)/gnuefi/elf_$(ARCH)_fbsd_efi.lds
endif

CPPFLAGS += -DCONFIG_$(ARCH)
CFLAGS += -ffreestanding -fno-stack-protector -fno-stack-check \
	      -funsigned-char -fshort-wchar \
          -Wall -Wextra -Wno-pointer-sign -Werror -ggdb

# https://www.redhat.com/en/blog/linkers-warnings-about-executable-stacks-and-segments
# Don't feel like editing the linkerscript to fix currently (rwx-segments)
LDFLAGS += -nostdlib --warn-common --no-undefined --fatal-warnings \
		   --no-warn-rwx-segments -znocombreloc \
		   -shared -Bsymbolic -L$(EFILIB) $(CRTOBJS)
LOADLIBES += -lgnuefi -lefi $(LIBGCC) -T $(LDSCRIPT)

ARFLAGS := -U
ASFLAGS += $(ARCH3264)

SECTIONS = .text .sdata .data .dynamic .dynsym \
	       .rel .rela .rel.* rela.* .rel* .rela* \
		   .reloc
DEBUG_SECTIONS = .debug_* .note.gnu.build-id


all: $(TARGETS)

%.efi: %.so
	$(OBJCOPY) $(foreach sec,$(SECTIONS),-j $(sec)) \
		$(FORMAT) $*.so $@

%.efi.debug: %.so
	$(OBJCOPY) $(foreach sec,$(SECTIONS) $(DEBUG_SECTIONS),-j $(sec)) \
		$(FORMAT) $*.so $@

%.so: %.o
	$(LD) $(LDFLAGS) $^ -o $@ $(LOADLIBES)

%.o: %.c
	$(CC) $(INCDIR) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

install:
	mkdir -p $(DESTDIR)
	$(INSTALL) -m 644 $(TARGETS) $(DESTDIR)

clean:
	rm -f $(TARGETS)

.PHONY: install
