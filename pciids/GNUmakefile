#

.SILENT: pci.ids

pci.ids: FORCE
	wget -N http://pci-ids.ucw.cz/v2.2/$@.bz2
	bunzip2 -kf $@.bz2

FORCE:
