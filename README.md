# Virtual iBoot Fun

This is just another **Virtualization.framework** sample project (WIP), but with focus on iBoot (iOS/macOS/tvOS/etc. bootloader)

*For a more canonical example of a VM (with GUI, instllation and etc.), look into @\_saagarjha's **VirtualApple** project*

The code is written in **Objective-C**, quite well commented and this README serves as a little documentaion as well

This far I've managed to boot up to a patched **iBootStage1** with **GDB server** and **debug UART** enabled, as well as many platform properties controlled (BDID, production mode and etc.)

Only tested under Monterey 12.0.1

![](repo/demo.png)


## Usage
### Requirements

* **Apple Silicon Mac** booted with `amfi_get_out_of_my_way=1` boot-arg - the last bit is required because otherwise macOS won't accept `com.apple.private.virtualization` entitlement (we'll call it "the *private* entitlement" from now on). And if it won't - the most interesting functions will be restricted. Setting such boot-arg is only allowed with many security feautures disabled, so be careful!
* **iRecovery** - to send images and commands to bootloaders
* **img4lib** - to create Image4s


### Options

```
usage: virtualization_test [OPTIONS]
        -r      path to custom ROM
        -a      path to auxiliary storage, default - /tmp/aux.bin
        -d      debug port, default - disabled
        -v      platform version, default - 2
        -c      count of CPUs, default - 1
        -m      memory size in GiBs, default - 2
        -b      board ID, default - defined by platform version
        -e      ECID, default - random
        -p      demote production mode
```

* `-r` - path to custom ROM, aka **AVPBooter** - the new iBoot flavor - usually can be found at `/System/Library/Frameworks/Virtualization.framework/Versions/A/Resources/AVPBooter.vmapple2.bin`. There're no signature checks for it, but it requires the *private* entitlement
* `-a` - path to auxiliary storage, (apparently) used for storing non-FS things (flashed firmware, NVRAM, etc.). If the file you provide doesn't exist, it will create it on its' own
* `-d` - debug port for GDB server. Requires the *private* entitlement. Note that debugging works real bad when VM runs **AVPBooter**
* `-v` - platform version. Valid values are 1 and 2. The first makes it use BDID:F8 (only works when using custom ROM), the second - BDID:20 and it's a default value
* `-c`, `-m`, `-b`, `-e` - various properties that speak for themselves. The only caveat here is that **iBootStage1** will panic if RAM size is below 2 GiBs (or near enough - definitely doesn't work with just one)
* `-p` - demote production mode, makes it run with CPFM:01 instead of 03. Currently unclear what this is useful for - **GDB** debug will work either way. Requires the *private* entitlement


## Booting iBootStage1
### Patching AVPBooter

First of all, we have to modify the **AVPBooter** with the canonical signature check patch, which is in essence the following:

* Find `image4_validate_property_callback()` - by searching for `0x4345` (ASCII `CE` as in `CEPO`)
* Make it always return 0 - by replacing the beginning of the function to `000080D2 C0035FD6` (`MOV X0, #0x0` `RET`)

This way, whenever `libImg4Decode` tries to validate some **Image4 Manifest** property, it will always think it was validated successfully

For `AVPBooter-7429.41.5` (shipped with Monterey 12.0.1) this patch' position is at `0xBAC`


### Constructing iBSS IMG4

**IM4P** files (**IM**age**4****P**ayload) you can find in an **IPSW** are not enough to be loaded by **AVPBooter**. First, one has to extend them with **IM4M** (**IM**age**4****M**anifest). Quite easy with `img4lib`:

```
img4 -i iBSS.vma2.RELEASE.im4p -o iBSS.vma2.RELEASE.img4 -M tickets/vma2_ticket.der
```

***Warning**: do not use manifests provided by an IPSW - for the reasons yet to be found it will fail to boot and AVPBooter will hang somewhere. Use one provided by TSS, such as the one provided by this repository*


### Booting!

Launch the program with your freshly patched ROM:

```
noone@noones-Air ~ % virtualization_test -r AVPBooter.vmapple2.patched.bin
VM is running!
```

If everything's fine, you'll see a green text "VM is running!" and new DFU-device on USB, such as this - `SDOM:01 CPID:FE00 CPRV:00 CPFM:03 SCEP:01 BDID:20 ECID:CAD01AC095BA1AD8 IBFL:3C SRTG:[iBoot-7429.41.5]`

Then send the **iBootStage1**/**iBSS** (from another terminal):

```
noone@noones-Air ~ % irecovery -f iBSS.vma2.RELEASE.img4
[==================================================] 100.0%
```

You should see something like this in the log (yes, it also serves as serial monitor):

```
noone@noones-Air ~ % virtualization_test -r AVPBooter.vmapple2.patched.bin
VM is running!
89994699affdef:132
133c360a905c0b0:28
20bae82b9d19aab:38
628547459a59420:312
9526cec925bde03:111
ae71af5ee32b84:116


=======================================
::
:: Supervisor iBootStage1 for vma2, Copyright 2007-2021, Apple Inc.
::
::      Remote boot, Board 0x20 (vma2ap)/Rev 0x0
::
::      BUILD_TAG: iBoot-7429.41.5
::
::      BUILD_STYLE: RELEASE
::
::      USB_SERIAL_NUMBER: SDOM:01 CPID:FE00 CPRV:00 CPFM:03 SCEP:01 BDID:20 ECID:CAD01AC095BA1AD8 IBFL:FD
::
=======================================

1aad73bb1002bf0:985
aborting autoboot due to remote boot.
Entering iBootStage1 recovery mode, starting command prompt
337a834f05a86eb:356
```

...as well as `Apple Mobile Device (Recovery Mode)` (`SDOM:01 CPID:FE00 CPRV:00 CPFM:03 SCEP:01 BDID:20 ECID:CAD01AC095BA1AD8 IBFL:FD`) device on USB

You can interact with it using **iRecovery** in the same way as if it was a real device:

```
noone@noones-Air ~ % irecovery -s


=======================================
::
:: Supervisor iBootStage1 for vma2, Copyright 2007-2021, Apple Inc.
::
::      Remote boot, Board 0x20 (vma2ap)/Rev 0x0
::
::      BUILD_TAG: iBoot-7429.41.5
::
::      BUILD_STYLE: RELEASE
::
::      USB_SERIAL_NUMBER: SDOM:01 CPID:FE00 CPRV:00 CPFM:03 SCEP:01 BDID:20 ECID:CAD01AC095BA1AD8 IBFL:FD
::
=======================================

1aad73bb1002bf0:985
aborting autoboot due to remote boot.
Entering iBootStage1 recovery mode, starting command prompt
> 
```

### Problems booting iBootStage2

Booting **iBootStage2** requires additional work, for now the best I could get is a panic somewhere early in it:

```
Entering iBootStage1 recovery mode, starting command prompt
337a834f05a86eb:356
ea0f64a4253252:448
7fe2bd288924c06:1158
7fe2bd288924c06:1186
10d9a6f0bc00891:515
133c360a905c0b0:75
======== End of iBootStage1 serial output. ========
89994699affdef:160
133c360a905c0b0:28
20bae82b9d19aab:38
628547459a59420:312


iBoot Panic: : ARM synchronous abort at 0x000000007008b964:
 esr 0x92000007 (ec: 0x24 (Data Abort (EL0)), iss: 0x00000007) far 0x0000000000000014
 x0 0x00000000acb1ac40 0x0000000000000010 0x0000000000000038 0x000000007008c940
 x4 0x000000007008c940 0x0000000000000000 0x73626d7572636461 0x0000000070086ce0
 x8 0x00000000aca0d6c0 0x0000000000000110 0x0000000000000010 0x0000000000000000
 x12 0xce36d9ee48ba8dc8 0x3800000000000000 0x0000000000000000 0x0000000000000000
 x16 0x0000000090195dc0 0x0000000070091c18 0x0000000000000000 0x0000000000000000
 x20 0x0000000000000000 0x0000000000000000 0x0000000002006b00 0x000000003c504944
 x24 0x0000000000000000 0x0000000000000000 0x0000000000000000 0x0000000000000000
 x28 0x0000000000000000 sp 0x0000000f74bdff10 lr 0x000000007008b94c spsr 0x60000000

Board: vma2ap:0x0 
Chip: fe00:0x0 
Build: RELEASE:iBoot-7429.41.5 
```

That's probably because of the new feautures in macOS iBoots related to boot poilicies - need to figure out how they work and how to bypass

**To Be Continued** (maybe...)


## Credits

* @\_saagarjha
* @s1guza
* @pimskeks and other people behind libirecovery
* @xerub
