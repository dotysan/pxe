#! /bin/bash -ex
#
# Brief: notes on creating a bootable floppy image for use updating BIOS and whatnot using PXE
#
cat >/dev/null <<EOF

	Rant: This was initially done because I was too lazy to go
	rummage in my office for a USB stick to temporarily use for
	booting/installing a BIOS update on my Haswell / Supermicro
	C7Z87-OCE motherboard. Since I always have a PXE environment
	readily available, it was "easier" to build it on the fly.

	This script is really just _documentation_ of the process.

EOF
#

bios_mobo=C7Z87OC3
bios_rev=718
bios=${bios_mobo}_${bios_rev}

trap bail EXIT
bail() {
#	find -mindepth 1 -maxdepth 1 -type d \( -name "$bios" -o -name fd11src \) |xargs -r sudo umount -v
	find -mindepth 1 -maxdepth 1 -type d -name "$bios" |xargs -r sudo umount -v
	find . -empty -delete
}

# make a fat12 filesystem just barely big enough
dd if=/dev/zero of=$bios.img bs=1MB count=18
mkdosfs -F12 -n$bios_mobo $bios.img

# use latest syslinux-4 for the boot sector and chain boot module
wget -O- --no-check-certificate https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-4.07.tar.bz2 \
	|tar -xjf - syslinux-4.07/{mtools/syslinux,com32/chain/chain.c32}

# make it bootable
rpm -q mtools
syslinux-4.07/mtools/syslinux -i $bios.img

# mount 'er up
mkdir $bios
sudo mount -o loop,uid=$USER $bios.img $bios

# add they chain-loader
cp -p syslinux-4.07/com32/chain/chain.c32 $bios/
# all done with syslinux now
rm syslinux-4.07/{mtools/syslinux,com32/chain/chain.c32}
find syslinux-4.07 -empty -delete

## fetch, mount, and extract FreeDOS
##wget -N http://www.freedos.org/download/download/fd11src.iso
#wget -N http://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.1/fd11src.iso
#mkdir fd11src
#sudo mount -o loop,ro fd11src.iso fd11src
#unzip -o fd11src/freedos/packages/base/kernelx.zip bin/kernel.sys
#unzip -o fd11src/freedos/packages/base/commandx.zip bin/command.com
#mv bin/{kernel.sys,command.com} $bios/
# aha! slightly newer version not buried inside giant ISO...
wget -N	http://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.1/repos/base/kernel.zip \
	http://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.1/repos/base/command.zip
unzip -o kernel.zip bin/kernl386.sys
unzip -o command.zip bin/command.com
mv bin/{kernl386.sys,command.com} $bios/
rmdir bin

# old wget doesn't know about Content-Disposition:filename=C7Z87OC3_718.zip header, so hard-code it here
wget -O$bios.zip 'http://www.supermicro.com/support/resources/getfile.aspx?ID=2299'
unzip -o $bios.zip $bios_mobo.$bios_rev/{AFUDOS.smc,$bios_mobo.$bios_rev}
mv $bios_mobo.$bios_rev/AFUDOS.smc $bios/AFUDOS.exe
mv $bios_mobo.$bios_rev/$bios_mobo.$bios_rev $bios/
rmdir $bios_mobo.$bios_rev

# boot directives
cat >$bios/syslinux.cfg <<-EOF
	TIMEOUT 10
	PROMPT 1
	DEFAULT $bios_mobo
	SAY Press ENTER to flash $bios_mobo BIOS
	LABEL $bios_mobo
	 COM32 chain.c32
	 APPEND freedos=kernl386.sys
EOF
#	@ECHO OFF
#	PROMPT $P$G
cat >$bios/autoexec.bat <<-EOF
	AFUDOS $bios_mobo.$bios_rev /P /B /N /K /R /ME
EOF

echo 'All done!'
