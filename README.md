# Poweroff & Reset from UEFI

systemd-boot does not have built in entries for powering off/reseting from the menu. This provides two simple UEFI programs for performing those actions. Original code from [arch-wiki](https://bbs.archlinux.org/viewtopic.php?id=245434), but I made the makefile made more robust and packaged it for nix.

## Testing

```
$ cp $OVMF_DIR/OVMF.fd ./qemu/ovmf.fd
$ dd if=/dev/zero of=/path/to/uefi.img bs=512 count=93750
$ parted /path/to/uefi.img -s -a minimal mklabel gpt
$ parted /path/to/uefi.img -s -a minimal mkpart EFI FAT16 2048s 93716s
$ parted /path/to/uefi.img -s -a minimal toggle 1 boot
$ dd if=/dev/zero of=/tmp/part.img bs=512 count=91669
$ mformat -i /tmp/part.img -h 32 -t 32 -n 64 -c 1
$ make/nix build
$ mcopy -i /tmp/part.img poweroff.efi reboot.efi ::
$ dd if=/tmp/part.img of=qemu/uefi.img bs=512 count=91669 seek=2048 conv=notrunc
$ qemu-system-x86_64 \
    -bios qemu/ovmf.fd \
    -drive file=qemu/uefi.img,if=ide \
    -net none \
    -nographic
```

# UEFI Development Resources

[OSDev GNU-EFI](https://wiki.osdev.org/GNU-EFI)

* How to develop UEFI applications
* Calling conventions
    * x86-64 uses microsoft ABI for interaction with firmware
    * All else uses c decltype
    * `EFIAPI` is just a preprocessor for choosing when to use a different abi
        * **do not** use on `efi_main` as that is always a cdecltype from gnu-efi
        * Not entirely sure why so many examples have it set (bad makefiles is my guess)
        * Set by `CPPFLAGS += -DGNU_EFI_USE_MS_ABI -maccumulate-outgoing-args` on x86-64 arch as ms_abi does not work without accumulate-outgoing-args
* Non-root qemu: https://wiki.osdev.org/UEFI#Linux.2C_root_not_required

[Getting started with EFI](https://krinkinmu.github.io/2020/10/11/efi-getting-started.html)

* Expected to be position independent (no guarantee that it will be loaded at fixed address)
* Binary format is PE32+

[Debugging with GDB](https://wiki.osdev.org/Debugging_UEFI_applications_with_GDB)

* Provide `-s -S` to qemu to start gdb server
* Call `info files`, `file`, `target remote :1234`, then `add-symbol-file xxx.efi.debug 0xTEXT_LOCATION -s .data 0xDATA_LOCATION`
    * To get data location use
    ```c
      status = uefi_call_wrapper(systab->BootServices->HandleProtocol, 3, image,
                                 &LoadedImageProtocol, (void **)&loaded_image);
      if (EFI_ERROR(status)) {
        Print(L"handleprotocol: %r\n", status);
      }
      Print(L"Image base: 0x%lx\n", loaded_image->ImageBase);
    ```
    * Add the offsets to the image base location
