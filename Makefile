DESTDIR :=
PREFIX := /usr/local
SCRIPTNAME = tip.sh
BINARY = tip
BASHCOMPDIR ?= $(PREFIX)/share/bash-completion/completions

.PHONY: all install uninstall

all: install

install:
	install -Dm755 $(SCRIPTNAME) $(DESTDIR)$(PREFIX)/bin/$(BINARY)
	install -vd "$(DESTDIR)$(BASHCOMPDIR)" && install -m 0644 tip.bash-completion "$(DESTDIR)$(BASHCOMPDIR)/tip"

uninstall:
	rm "$(DESTDIR)$(PREFIX)/bin/$(BINARY)"
	rm "$(DESTDIR)$(BASHCOMPDIR)/tip"
