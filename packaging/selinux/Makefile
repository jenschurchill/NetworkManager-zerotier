# Build and install the nm-zerotier SELinux policy module.
# Requires: selinux-policy-devel, make.
#
#   make                compile nm-zerotier.pp
#   sudo make install   load the module and relabel /var/lib/zerotier-one
#   sudo make uninstall remove the module

TARGET := nm-zerotier
SHAREDIR := $(shell pkg-config --variable=sharedir selinux_policy 2>/dev/null || echo /usr/share/selinux)

.PHONY: all install uninstall clean

all: $(TARGET).pp

$(TARGET).pp: $(TARGET).te $(TARGET).fc
	make -f $(SHAREDIR)/devel/Makefile $@

install: $(TARGET).pp
	semodule -i $(TARGET).pp
	restorecon -Rv /var/lib/zerotier-one

uninstall:
	semodule -r $(TARGET)

clean:
	rm -f $(TARGET).pp
	rm -rf tmp
