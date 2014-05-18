#! /bin/bash -e
#
# Brief: notes on creating a bootable floppy/PXE image for use updating Supermicro BIOS
#
# usage: supermicro.sh <file num>
#	where <file num> is the ID linked from http://www.supermicro.com/support/bios/
#
# Currently, only tested with C7Z87-OCE motherboard.
#

#-----------------------------------------------------------------------

sl=syslinux-4.07
# use latest syslinux-4 for the boot sector and chain boot module
if [ ! -e $sl.tar.bz2 ]
then wget -N --no-check-certificate https://www.kernel.org/pub/linux/utils/boot/syslinux/$sl.tar.bz2
fi
if [ ! -e $sl/mtools/syslinux -o ! -e $sl/com32/chain/chain.c32 ]
then tar -xjf $sl.tar.bz2 $sl/{mtools/syslinux,com32/chain/chain.c32}
fi

#-----------------------------------------------------------------------

if [ ! -e kernel.zip -o ! -e command.zip ]
then wget -N http://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.1/repos/base/{kernel,command}.zip
fi
if [ ! -e bin/kernl386.sys -o ! -e bin/command.com ]
then	unzip -o kernel.zip bin/kernl386.sys
	unzip -o command.zip bin/command.com
fi

#-----------------------------------------------------------------------

# you must know their getfile.aspx?ID= number linked from http://www.supermicro.com/support/bios/
supermicro_fnum=${1-2720}
bios_zip=$supermicro_fnum.zip
test -e $bios_zip ||wget -O$bios_zip \
    "http://www.supermicro.com/support/resources/getfile.aspx?ID=$supermicro_fnum"

# set the zipfile mtime to that of the newest file inside
newest=`zipinfo -lT $bios_zip |sort -k7r |awk '{print$8;exit}'`
touch -t${newest::8}${newest:9:4}.${newest:13} $bios_zip

# the largest file in the zip is presumed to be the ROM
bios_rom=`zipinfo -lT $bios_zip |sort -k4nr |awk '{print$9;exit}'`

# extract the EXE and the ROM
if [ ! -e AFUDOS.smc -o ! -e $bios_rom ]
then unzip -o $bios_zip AFUDOS.smc $bios_rom
fi

# extract the magic command for later use in autoexec.bat
autoexec=`unzip -p $bios_zip ami.bat |sed -nre "/^AFUDOS/{s/%1/$bios_rom/;p;q}"`

#-----------------------------------------------------------------------

bios_img=$bios_rom.img

getblocks8k() {
    brsize=`stat -c%s $1`
    if [ $[brsize%8192] -gt 1 ]
    then echo $[brsize/8192+1]
    else echo $[brsize/8192]
    fi
}
# attempting to precisely estimate the filesystem size 100% full
declare -i totblocks=3 # fat12 root
totblocks+=5 # TODO: how to properly size syslinux -i (ldlinux.sys)?
totblocks+=`getblocks8k $sl/com32/chain/chain.c32`
totblocks+=`getblocks8k bin/kernl386.sys`
totblocks+=`getblocks8k bin/command.com`
totblocks+=`getblocks8k AFUDOS.smc`
totblocks+=`getblocks8k $bios_rom`
totblocks+=1 # syslinux.cfg
totblocks+=1 # autoexec.bat
dd if=/dev/zero of=$bios_img bs=8K count=$totblocks
mkdosfs -F12 -n$bios_rom $bios_img

# make it bootable
rpm -q mtools
$sl/mtools/syslinux -i $bios_img

# mount 'er up
mkdir mnt
sudo mount -o loop,uid=$USER $bios_img mnt

# add the chain-loader
cp -p $sl/com32/chain/chain.c32 mnt/
# FreeDOS
cp -p bin/{kernl386.sys,command.com} mnt/
# finally the Supermicro BIOS and utility
cp -p AFUDOS.smc mnt/AFUDOS.exe
cp -p $bios_rom mnt/

# boot directives
cat >mnt/syslinux.cfg <<-EOF
	TIMEOUT 10
	PROMPT 1
	DEFAULT $bios_rom
	SAY Press ENTER to flash $bios_rom BIOS
	LABEL $bios_rom
	 COM32 chain.c32
	 APPEND freedos=kernl386.sys
EOF
cat >mnt/autoexec.bat <<-EOF
	$autoexec
	@echo Now you must hard power-cycle this system.
EOF

df -h mnt
ls -oha mnt |grep -v ' \.\.$'

#-----------------------------------------------------------------------

cat <<-EOF
All done!

If you are using PXE, make sure you have memdisk on your tftp server,
then copy $bios_img to it too and add the following menu entry:

LABEL Supermicro-BIOS
    MENU LABEL Update Supermicro Motherboard BIOS
    KERNEL syslinux/memdisk
    APPEND initrd=supermicro/$bios_img

EOF

sudo umount -v mnt
rmdir mnt
