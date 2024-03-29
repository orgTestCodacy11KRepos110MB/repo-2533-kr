OS ?= $(shell ./install/os.sh)
UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Linux)
	PREFIX ?= /usr
	SUDO = sudo
endif
ifeq ($(UNAME_S),Darwin)
	PREFIX ?= /usr/local

	OSXRELEASE := $(shell uname -r | sed 's/\..*//')
	ifeq ($(OSXRELEASE), 17)
		OSXVER = "High Sierra"
	endif
	ifeq ($(OSXRELEASE), 16)
		OSXVER = "Sierra"
	endif
	ifeq ($(OSXRELEASE), 15)
		OSXVER = "El Capitan"
	endif
	ifeq ($(OSXRELEASE), 14)
		OSXVER = "Yosemite"
	endif
	ifeq ($(OSXRELEASE), 13)
		OSXVER = "Maverick"
	endif
	ifeq ($(OSXRELEASE), 12)
		OSXVER = "Mountain Lion"
	endif
	ifeq ($(OSXRELEASE), 11)
		OSXVER = "Lion"
	endif
	ifeq ($(shell expr $(OSXRELEASE) \>= 16), 1)
		CGO_LDFLAGS += -F$(PWD)/lib -Wl,-rpath -Wl,$(PREFIX)/Frameworks -Wl,-rpath -Wl,$(PWD)/lib -framework krbtle
	else
		GO_TAGS = -tags nobluetooth
	endif
endif
ifeq ($(UNAME_S),FreeBSD)
	PREFIX ?= /usr/local
endif

SRCBIN = $(PWD)/bin
DSTBIN = $(PREFIX)/bin

SRCLIB = $(PWD)/lib
DSTLIB = $(PREFIX)/lib

DSTFRAMEWORK = $(PREFIX)/Frameworks

CONFIGURATION ?= Release

all:
	-mkdir -p bin
	-mkdir -p lib
ifeq ($(UNAME_S),Darwin)
ifeq ($(shell expr $(OSXRELEASE) \>= 16), 1)
		cd krbtle && xcodebuild -configuration $(CONFIGURATION) -archivePath $(SRCLIB) -scheme krbtle-Package
		-rm -rf $(SRCLIB)/krbtle.framework
		cp -R krbtle/build/$(CONFIGURATION)/krbtle.framework $(SRCLIB)/krbtle.framework
endif
endif
	cd kr; go build $(GO_TAGS) -o ../bin/kr
	cd krd/main; CGO_LDFLAGS="$(CGO_LDFLAGS)" go build $(GO_TAGS) -o ../../bin/krd
	cd pkcs11shim; make; cp target/release/kr-pkcs11.so ../lib/
	cd krssh; CGO_LDFLAGS="$(CGO_LDFLAGS)" go build $(GO_TAGS) -o ../bin/krssh
	cd krgpg; go build $(GO_TAGS) -o ../bin/krgpg

clean:
	rm -rf bin/

check: vet
	CGO_LDFLAGS="$(CGO_LDFLAGS)" go test $(GO_TAGS) github.com/kryptco/kr github.com/kryptco/kr/krd github.com/kryptco/kr/krd/main github.com/kryptco/kr/krdclient github.com/kryptco/kr/kr github.com/kryptco/kr/krssh github.com/kryptco/kr/krgpg
	cd pkcs11shim; cargo test

vet:
	go vet github.com/kryptco/kr github.com/kryptco/kr/krd github.com/kryptco/kr/krdclient github.com/kryptco/kr/kr github.com/kryptco/kr/krssh github.com/kryptco/kr/krgpg

install: all
	mkdir -p $(DSTBIN)
	mkdir -p $(DSTLIB)
ifeq ($(UNAME_S),Darwin)
	mkdir -p $(DSTFRAMEWORK)
	$(SUDO) ln -sf $(SRCLIB)/krbtle.framework $(DSTFRAMEWORK)/krbtle.framework
endif
	$(SUDO) ln -sf $(SRCBIN)/kr $(DSTBIN)/kr
	$(SUDO) ln -sf $(SRCBIN)/krd $(DSTBIN)/krd
	$(SUDO) ln -sf $(SRCBIN)/krssh $(DSTBIN)/krssh
	$(SUDO) ln -sf $(SRCBIN)/krgpg $(DSTBIN)/krgpg
	$(SUDO) ln -sf $(SRCLIB)/kr-pkcs11.so $(DSTLIB)/kr-pkcs11.so
	mkdir -m 700 -p ~/.ssh
	touch ~/.ssh/config
	chmod 0600 ~/.ssh/config
	perl -0777 -ne '/# Added by Kryptonite\nHost \*\n\tPKCS11Provider $(subst /,\/,$(PREFIX))\/lib\/kr-pkcs11.so\n\tProxyCommand $(subst /,\/,$(PREFIX))\/bin\/krssh %h %p\n\tIdentityFile ~\/.ssh\/id_kryptonite\n\tIdentityFile ~\/.ssh\/id_ed25519\n\tIdentityFile ~\/.ssh\/id_rsa\n\tIdentityFile ~\/.ssh\/id_ecdsa\n\tIdentityFile ~\/.ssh\/id_dsa/ || exit(1)' ~/.ssh/config || printf '\n# Added by Kryptonite\nHost *\n\tPKCS11Provider $(PREFIX)/lib/kr-pkcs11.so\n\tProxyCommand $(PREFIX)/bin/krssh %%h %%p\n\tIdentityFile ~/.ssh/id_kryptonite\n\tIdentityFile ~/.ssh/id_ed25519\n\tIdentityFile ~/.ssh/id_rsa\n\tIdentityFile ~/.ssh/id_ecdsa\n\tIdentityFile ~/.ssh/id_dsa' >> ~/.ssh/config

start:
ifeq ($(UNAME_S),Darwin)
	mkdir -p ~/Library/LaunchAgents
	cp share/co.krypt.krd.plist ~/Library/LaunchAgents/co.krypt.krd.plist
endif
	kr restart

uninstall:
	killall krd
	$(SUDO) rm -f $(DSTBIN)/kr
	$(SUDO) rm -f $(DSTBIN)/krd
	$(SUDO) rm -f $(DSTBIN)/krssh
	$(SUDO) rm -f $(DSTBIN)/krgpg
	$(SUDO) rm -f $(DSTLIB)/kr-pkcs11.so
	perl -0777 -p -i.kr.bak -e 's/\s*# Added by Kryptonite\nHost \*\n\tPKCS11Provider $(subst /,\/,$(PREFIX))\/lib\/kr-pkcs11.so\n\tProxyCommand $(subst /,\/,$(PREFIX))\/bin\/krssh %h %p\n\tIdentityFile ~\/.ssh\/id_kryptonite\n\tIdentityFile ~\/.ssh\/id_ed25519\n\tIdentityFile ~\/.ssh\/id_rsa\n\tIdentityFile ~\/.ssh\/id_ecdsa\n\tIdentityFile ~\/.ssh\/id_dsa//g' ~/.ssh/config 
	kr uninstall
