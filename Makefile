DESTDIR :=
PREFIX := /usr/local
SCRIPTNAME = note.sh
BINARY = note
BASHCOMPDIR ?= $(PREFIX)/share/bash-completion/completions

.PHONY: all install uninstall

all: install

install:
	install -Dm755 $(SCRIPTNAME) $(DESTDIR)$(PREFIX)/bin/$(BINARY)
	install -vd "$(DESTDIR)$(BASHCOMPDIR)" && install -m 0644 note.bash-completion "$(DESTDIR)$(BASHCOMPDIR)/note"

uninstall:
	rm "$(DESTDIR)$(PREFIX)/bin/$(BINARY)"
	rm "$(DESTDIR)$(BASHCOMPDIR)/note"
