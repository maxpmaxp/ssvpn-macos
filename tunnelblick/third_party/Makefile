# This Makefile builds all the third_party code
# It shouldn't be called by anything other than automated scripts

CC=gcc
MACOSX_DEPLOYMENT_TARGET=10.6
OSX_VERSION=10.7
#looking for xcode sdk in a new folder for sdks (xcode.app/...)
SDKROOT=`xcode-select -print-path`/Platforms/MacOSX.platform/Developer/SDKs/MacOSX$(OSX_VERSION).sdk
#SDKROOT=/Developer/SDKs/MacOSX10.6.sdk

CFLAGS=-isysroot $(SDKROOT) -Os -mmacosx-version-min=$(MACOSX_DEPLOYMENT_TARGET)

TOPDIR = $(PWD)
BUILD_DIR = build
THIRD_PARTY_PROJS = OPENSSL

OPENSSL_SRC_DIR = openssl-1.0.0e
OPENSSL_BUILD_DIR = $(TOPDIR)/$(BUILD_DIR)/$(OPENSSL_SRC_DIR)
OPENSSL_DEST_DIR = $(TOPDIR)/$(BUILD_DIR)/staging/$(OPENSSL_SRC_DIR)
OPENSSL_TARGET_FILES = $(foreach f, libcrypto.a libssl.a, $(OPENSSL_DEST_DIR)/lib/$(f))

PROJ_BUILD_DIRS = $(foreach proj, $(THIRD_PARTY_PROJS), $($(proj)_BUILD_DIR))

# Both lzo and openvpn should be built universally (now only for i386; ppc buildconf was removed)

LZO_DIR=lzo-2.05
PKCS11_DIR=pkcs11-helper-1.09
PKCS11_TUNNELBLICK_STAGING_DIR=$(TOPDIR)/$(PKCS11_DIR)/staging
TUNTAP_PRE_LION_DIR=tuntap-20090913
TUNTAP_LION_DIR=tuntap-20110914


all: built-tuntap built-openvpn
	@echo "Made all third_party for Tunnelblick"

clean: built-tuntap-clean built-lzo-clean built-pkcs11-helper-clean built-openvpn-clean
	rm -rf $(BUILD_DIR)

buildenv: $(PROJ_BUILD_DIRS)
$(PROJ_BUILD_DIRS):
	mkdir -p $@;
	cd $@ && /usr/X11/bin/lndir $(TOPDIR)/$$(basename $@);

built-openssl-patch:
	mkdir -p $(OPENSSL_BUILD_DIR)
	cd $(OPENSSL_BUILD_DIR); \
	/usr/X11/bin/lndir $(TOPDIR)/$$(basename $(OPENSSL_BUILD_DIR)); \
	if [ -d "$(TOPDIR)/patches/openssl" ]; then \
		for patchfile in $(TOPDIR)/patches/openssl/*.diff; do \
			patch -p0 -N --dry-run -i $$patchfile > /dev/null; \
			if [ $$? == 0 ]; then \
				patch -p0 -N -i $$patchfile; \
			fi \
		done \
	fi; \
	cd $(TOPDIR);
	touch built-openssl-patch

built-openssl: built-openssl-patch
	for a in darwin-i386-cc darwin-ppc-cc; do\
		@echo Configure OpenSSL for $$a; \
		cd $(OPENSSL_BUILD_DIR); \
		@echo Forcefully be clean; \
		$(MAKE) clean; \
		CC=$(CC) CFLAGS="$(CFLAGS)" ./Configure no-shared zlib no-krb5 --prefix="$(OPENSSL_DEST_DIR)/$$a" $$a; \
		@echo Build OpenSSL for $$a; \
		$(MAKE) build_libs build_apps openssl.pc libssl.pc libcrypto.pc; \
		@echo Install to $(OPENSSL_DEST_DIR)/$$a; \
		$(MAKE) install_sw; \
		cd -; \
	done
	ditto -v $(BUILD_DIR)/staging/$(OPENSSL_SRC_DIR)/darwin-i386-cc/include $(OPENSSL_DEST_DIR)/include/i386
	ditto -v $(BUILD_DIR)/staging/$(OPENSSL_SRC_DIR)/darwin-ppc-cc/include $(OPENSSL_DEST_DIR)/include/ppc
	mkdir -p $(OPENSSL_DEST_DIR)/lib
	for t in $(OPENSSL_TARGET_FILES); do \
		lipo $(BUILD_DIR)/staging/$(OPENSSL_SRC_DIR)/darwin*/lib/$$(basename $$t) -create -output $$t; \
	done
	rm -rf $(BUILD_DIR)/staging/$(OPENSSL_SRC_DIR)/darwin*
	touch built-openssl
	
built-pkcs11-helper:
	for a in ppc i386; do \
		@echo Configure PKCS11-Helper for $$a; \
		cd $(PKCS11_DIR); \
		@echo Forcefully be clean; \
		$(MAKE) clean; \
		OPENSSL_CFLAGS="-I$(OPENSSL_DEST_DIR)/include/$$a" OPENSSL_LIBS="-L$(OPENSSL_DEST_DIR)/lib -lssl -lcrypto -lz" CC=$(CC) CFLAGS="$(CFLAGS) -arch $$a" ./configure --enable-static --enable-shared=no --disable-dependency-tracking --prefix=$$(pwd)/staging_$$a --includedir=$$(pwd)/staging/include; \
		@echo Build PKCS11-Helper; \
		$(MAKE); \
		@echo Install to $(PKCS11_TUNNELBLICK_STAGING_DIR)_$$a; \
		$(MAKE) install; \
		cd ../; \
	done
	rm -r -f $(PKCS11_TUNNELBLICK_STAGING_DIR)/lib
	mkdir -p $(PKCS11_TUNNELBLICK_STAGING_DIR)/lib
	lipo $(PKCS11_TUNNELBLICK_STAGING_DIR)_*/lib/libpkcs11-helper.a -create -output $(PKCS11_TUNNELBLICK_STAGING_DIR)/lib/libpkcs11-helper.a
	cp  $(PKCS11_DIR)/staging_i386/lib/libpkcs11-helper.la  $(PKCS11_TUNNELBLICK_STAGING_DIR)/lib/ 
	touch built-pkcs11-helper

built-pkcs11-helper-clean:
	$(MAKE) -C $(PKCS11_DIR) clean
	rm -rf $(PKCS11_TUNNELBLICK_STAGING_DIR)*
	rm -f built-pkcs11-helper

built-lzo:
	for a in ppc i386; do \
		@echo Configure LZO for $$a; \
		cd $(LZO_DIR); \
		@echo Forcefully be clean; \
		$(MAKE) clean; \
		CC=$(CC) CFLAGS="$(CFLAGS) -arch $$a" ./configure --disable-dependency-tracking --disable-asm --prefix=$$(pwd)/staging_$$a/ --includedir=$$(pwd)/staging/include/; \
		@echo Build LZO; \
		$(MAKE); \
		@echo Install to $(LZO_DIR)/staging_$$a; \
		$(MAKE) install; \
		cd ../; \
	done
	
	# Use lipo to create a universal library
	mkdir -p $(LZO_DIR)/staging/lib
	lipo $(LZO_DIR)/staging_*/lib/liblzo2.a -create -output $(LZO_DIR)/staging/lib/liblzo2.a
	cp  $(LZO_DIR)/staging_i386/lib/liblzo2.la $(LZO_DIR)/staging/lib/ 
	touch built-lzo
	
built-lzo-clean:
	$(MAKE) -C $(LZO_DIR) clean
	rm -rf $(LZO_DIR)/staging*
	rm -f built-lzo

built-openvpn-patch:
	for openvpndir in `ls openvpn`; do \
		cd openvpn/$$openvpndir/openvpn; \
		if [ -d ../patches ]; then \
			for patchfile in `ls ../patches/*.diff`; do \
				patch -p1 -N --dry-run -i $$patchfile > /dev/null; \
				if [ $$? == 0 ]; then \
					patch -p1 -N -i $$patchfile; \
					if [ $$? == 0 ]; then \
					    touch "$${patchfile}.patch-applied" ; \
						echo "OpenVPN patch applied: $$openvpndir/openvpn/$${patchfile}" ; \
					else \
						echo "error: OpenVPN patch failed: $$openvpndir/openvpn/$${patchfile}" ; \
					fi \
				else \
					if [ -e "$${patchfile}.patch-applied" ] ; then \
						echo "warning: OpenVPN patch skipped; it has apparently already been applied: $$openvpndir/openvpn/$${patchfile}" ; \
					else \
						echo "error: OpenVPN patch has not been applied previously and could not be applied now: $$openvpndir/openvpn/$${patchfile}" ; \
					fi \
				fi \
			done; \
		else \
			echo "No OpenVPN patches for $$openvpndir" ; \
		fi; \
		cd ../../../; \
	done
	touch built-openvpn-patch
	
built-openvpn: built-lzo built-openssl built-pkcs11-helper built-openvpn-patch
	for openvpndir in `ls openvpn`; do \
		for a in i386; do \
			cd openvpn/$$openvpndir/openvpn; \
			$(MAKE) clean; \
			autoreconf -i -v; \
			CC=$(CC) CFLAGS="$(CFLAGS) -arch $$a" ./configure --with-lzo-headers=../../../$(LZO_DIR)/staging/include --with-lzo-lib=../../../$(LZO_DIR)/staging/lib --with-pkcs11-helper-headers=../../../$(PKCS11_DIR)/staging/include --with-pkcs11-helper-lib=../../../$(PKCS11_DIR)/staging/lib --with-ssl-headers=$(OPENSSL_DEST_DIR)/include/$$a --with-ssl-lib=$(OPENSSL_DEST_DIR)/lib --disable-dependency-tracking; \
			$(MAKE) LIBS="$(OPENSSL_TARGET_FILES) -lpkcs11-helper -llzo2 -lz"; \
			mv openvpn openvpn_tblk_$$a; \
			cd ../../../; \
		done; \
		$(MAKE) -C openvpn/$$openvpndir/openvpn/plugin/down-root; \
		lipo openvpn/$$openvpndir/openvpn/openvpn_tblk_* -create -output openvpn/$$openvpndir/openvpn/openvpn; \
	done
	touch built-openvpn
	
built-openvpn-clean:
	for openvpndir in `ls openvpn`; do \
		$(MAKE) -C openvpn/$$openvpndir/openvpn/ clean; \
		$(MAKE) -C openvpn/$$openvpndir/openvpn/plugin/down-root clean; \
		rm -f openvpn/$$openvpndir/openvpn/openvpn_tblk_*; \
		rm -f openvpn/$$openvpndir/openvpn/openvpn; \
		rm -f openvpn/$$openvpndir/openvpn/plugin/down-root/openvpn-down-root.so; \
	done
	rm -f built-openvpn

.PHONY : tuntap

built-tuntap-patch:
	for tuntapdir in `ls tuntap`; do \
		cd tuntap/$$tuntapdir/tuntap; \
		for patchfile in ../patches/*.diff; do \
			patch -p0 -N --dry-run -i $$patchfile > /dev/null; \
			if [ $$? == 0 ]; then \
				patch -p0 -N -i $$patchfile; \
			fi \
		done; \
		cd ../../../; \
	done
	touch built-tuntap-patch

built-tuntap: built-tuntap-patch
	$(MAKE) -C tuntap/$(TUNTAP_PRE_LION_DIR)/tuntap/; \
	mv tuntap/$(TUNTAP_PRE_LION_DIR)/tuntap/tap.kext tap-pre-lion.kext; \
	mv tuntap/$(TUNTAP_PRE_LION_DIR)/tuntap/tun.kext tun-pre-lion.kext; \
	$(MAKE) -C tuntap/$(TUNTAP_LION_DIR)/tuntap/; \
	mv tuntap/$(TUNTAP_LION_DIR)/tuntap/tap.kext tap.kext; \
	mv tuntap/$(TUNTAP_LION_DIR)/tuntap/tun.kext tun.kext
	touch built-tuntap

built-tuntap-clean:
	$(MAKE) -C tuntap/$(TUNTAP_PRE_LION_DIR)/tuntap/ clean; \
	rm -f -R tap-pre-lion.kext; \
	rm -f -R tun-pre-lion.kext; \
	$(MAKE) -C tuntap/$(TUNTAP_LION_DIR)/tuntap/ clean; \
	rm -f -R tap.kext; \
	rm -f -R tun.kext
	rm -f built-tuntap
