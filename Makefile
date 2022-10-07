DESTDIR :=
PREFIX := /usr/local
SCRIPTNAME = tip.sh
BINARY = tip

.PHONY: all install

all: install

install:
	install -Dm755 $(SCRIPTNAME) $(DESTDIR)$(PREFIX)/bin/$(BINARY)

uninstall:
	rm $(DESTDIR)$(PREFIX)/bin/$(BINARY)
