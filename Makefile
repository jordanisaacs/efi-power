HOSTCC := $(prefix)gcc
CC := $(prefix)$(CROSS_COMPILE)gcc
LD := $(prefix)$(CROSS_COMPILE)ld
INSTALL := install
DESTDIR ?= /

ARCH ?= $(shell $(HOSTCC) -dumpmachine | cut -f1 -d- | sed -e s,i[3456789]86,ia32, -e 's,armv[67].*,arm,' )

ifneq ($(ARCH),arm)
  export LIBGCC=$(shell $(CC) $(CFLAGS) $(ARCH3264) -print-libgcc-file-name)
endif

ifeq ($(ARCH),x86_64)
  CPPFLAGS += -DGNU_EFI_USE_MS_ABI -maccumulate-outgoing-args
  CFLAGS += -mno-red-zone
endif

ifneq (,$(filter $(ARCH),ia32 x86_64))
  CFLAGS += -mno-avx
endif

ifeq ($(ARCH),ia32)
  CFLAGS += -mno-mmx -mno-sse
endif

ifeq ($(ARCH),ia64)
  CFLAGS += -mfixed-range=f32-f127
endif
ifeq ($(ARCH),mips64el)
  CFLAGS += -march=mips64r2
  ARCH3264 = -mabi=64
endif

# Only enable -fPIE for non MinGW compilers (unneeded on MinGW)
GCCMACHINE := $(shell $(CC) -dumpmachine)
ifneq (mingw32,$(findstring mingw32, $(GCCMACHINE)))
  CFLAGS += -fpie
endif

CPPFLAGS += -DCONFIG_$(ARCH)

# Necessary for gnu-efi
CFLAGS += \
    -ffreestanding -fno-stack-protector -fno-stack-check \
	-funsigned-char -fshort-wchar \

# Warnings
CFLAGS += -Wall -Wextra -Wno-pointer-sign -Werror

# Debug
CFLAGS += -ggdb

LDFLAGS += -nostdlib --warn-common --no-undefined --fatal-warnings

FORMAT := --target efi-app-$(ARCH)

TARGETS = poweroff.efi reboot.efi

EFI_DIR_         = ${EFI_DIR}

EFI_INC          = $(EFI_DIR_)/include/efi
EFI_INCS         = -I$(EFI_INC) -I$(EFI_INC)/$(ARCH) -I$(EFI_INC)/protocol

EFI_LIB          = $(EFI_DIR_)/lib

CRTOBJS         = $(EFI_LIB)/crt0-efi-$(ARCH).o
LDSCRIPT        = $(EFI_LIB)/elf_$(ARCH)_efi.lds

LDFLAGS += -znocombreloc -shared -Bsymbolic -L${EFI_LIB} $(CRTOBJS)

LOADLIBES += -lefi -lgnuefi
LOADLIBES += $(LIBGCC)
LOADLIBES += -T $(LDSCRIPT)

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
	$(CC) $(EFI_INCS) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

install:
	mkdir -p $(DESTDIR)
	$(INSTALL) -m 644 $(TARGETS) $(DESTDIR)

clean:
	rm -f $(TARGETS)

.PHONE: install
