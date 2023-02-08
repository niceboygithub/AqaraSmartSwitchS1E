# Enable Telnet of S1E

## Easy way, but you may need to wait for a long time
1. Call or Email to Aqara for did and key of the S1E
2. Run generate_pswd.sh
```
scripts/generate_pswd.sh s1e_did s1e_mac s1e_key
```
example:

<img src="/images/s1e2ha_generate_pswd.png" alt="uart" height="170" width="850">

3. Then you can get the password of telnet
4. Run telnet to S1E, the username is 'root' and the password is the one you got in step 2
5. Reset the password
```
passwd -d root
```

## Hard way (High Risk, do it at your own risk) (works till 2.0.5_1032)
1. Open the case
2. Connect to UART, reference to the picture. Suggestion use soldering.
<img src="/images/s1e_uart.png" alt="uart" height="520" width="460">

3. Interrupt uboot.
  - Use putty to open COM port. Baud Rate is 115200.
  - While boot up, keep pressed the key "enter". If not stop uboot, please try again.

4. If it stopped on uboot cli, enter the following command

```
nand info
```
 Check if nand is properly initialized.
```
Device 0: nand0, sector size 128 KiB
  Page size      2048 b
  OOB size         64 b
  Erase size   131072 b
```
If NAND is initialized, run the next command to continue.
```
printenv bootargs
```
   Save the bootargs to note, then replace the string "/linuxrc" to "/bin/sh".
   For example, the new bootargs as below
```
setenv bootargs root=/dev/mtdblock7 rootfstype=squashfs ro init=/bin/sh loglevel=8 LX_MEM=0x3FE0000 mma_heap=mma_heap_name0,miu=0,sz=0x2B0000 cma=2M highres=on mmap_reserved=fb,miu=0,sz=0x300000,max_start_off=0x3300000,max_end_off=0x3600000 mtdparts=nand0:1664k@0x140000(BOOT0),1664k(BOOT1),256k(ENV),256k(ENV1),128k(KEY_CUST),3m(KERNEL),3m(KERNEL_BAK),20m(rootfs),20m(rootfs_bak),1m(factory),1m(MISC),10m(RES),10m(RES_BAK),-(UBI)
```
   Then enter the following commands
```
run bootcmd
```
5. It will continue to boot kernel and stops shell console. Then enter the following command.
```
/bin/fwfs --block_size=131072 --subblock_size=32768 --block_cycles=500 --read_size=2048 --prog_size=2048 --cache_size=32768 --file_cache_size=32768 --cache_pool_size=2 --block_count=8 --lookahead_size=8 /dev/mtd10 /misc
```
6. Then delete the 'passwd' file.
```
rm /misc/passwd
```
7. After deleted, restar the S1E. Then you can telnet to the S1E with empty password.
    After login, you can clear the password with the command
```
passwd -d root
```
