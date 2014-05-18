pxe
===

PXE boot server hacks, snippets, scripts &amp; whatnot

supermicro/mkbiosupdate.sh
--------------------------

How to use?

1. Run it to create a bootable image file.

2. Add a new LABLE to your pxelinux.cfg with:

    KERNEL syslinux/memdisk
    APPEND initrd=supermicro/C7Z87OC4.423.img

3. Then PXE boot your system to this image. And either:
	* A. Watch your BIOS upgrade successfully.
	* B. Get ready to fill out an RMA request.

So far, only tested with the C7Z87-OCE motherboard.
