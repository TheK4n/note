DESTDIR :=
PREFIX := /usr/local
SCRIPTNAME = note.sh
BINARY = note
BASHCOMPDIR ?= $(PREFIX)/share/bash-completion/completions
MANDIR ?= $(PREFIX)/share/man

.PHONY: all install uninstall

all: install

install:
	install -Dm755 $(SCRIPTNAME) $(DESTDIR)$(PREFIX)/bin/$(BINARY)
	install -vd "$(DESTDIR)$(BASHCOMPDIR)" && install -m 0644 note.bash-completion "$(DESTDIR)$(BASHCOMPDIR)/note"
	install -vd "$(DESTDIR)$(MANDIR)/man1" && install -m 0644 manpage "$(DESTDIR)$(MANDIR)/man1/note.1"

uninstall:
	rm "$(DESTDIR)$(PREFIX)/bin/$(BINARY)"
	rm "$(DESTDIR)$(BASHCOMPDIR)/note"
	rm "$(DESTDIR)$(MANDIR)/man1/note.1"
