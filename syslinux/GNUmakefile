#

sl=syslinux-4.07
#sl=syslinux-6.02

.SILENT: $(sl)

$(sl):
	wget https://www.kernel.org/pub/linux/utils/boot/syslinux/$(sl).tar.bz2 \
		-O- --no-check-certificate |tar -xjf -
