# Poweroff & Reset from UEFI

systemd-boot does not have built in entries for powering off/reseting from the menu. This provides two simple UEFI programs for performing those actions. Original code from [arch-wiki](https://bbs.archlinux.org/viewtopic.php?id=245434), but I made the makefile made more robust and packaged it for nix.

## Testing

**x86-64**

*x86_64-unknown-linux-gnu*

```
$ cp $OVMF_DIR/OVMF.fd ./qemu/ovmf.fd
$ make/nix build
$ cp XXX.efi root/XXX.efi
$ qemu-system-x86_64 \
    -bios qemu/ovmf.fd \
    -drive format=raw,file=fat:rw:root \
    -net none \
    -nographic
```

**aarch64**

Help from: http://cdn.kernel.org/pub/linux/kernel/people/will/docs/qemu/qemu-arm64-howto.html

*aarch64-unknown-linux-gnu*

```
$ cp $OVMF_DIR/QEMU_EFI.fd ./qemu/efi.img
$ truncate -s 64m efi.img
$ truncate -s 64m varstore.img
$ dd if=$OVMF_DIR/QEMU_EFI.fd of=efi.img conv=notrunc
$ make/nix build
$ cp XXX.efi root/XXX.efi
$ qemu-system-aarch64 -M virt -cpu cortex-a57 \
    -drive file=qemu/efi.img,if=pflash,format=raw,readonly=true \
    -drive file=qemu/varstore.img,if=pflash,format=raw \
    -net none -nographic \
    -drive format=raw,file=fat:rw:root
```

**


## Automated Testing

See boot tests for inspiration:

https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/boot.nix

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
