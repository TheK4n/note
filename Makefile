DESTDIR :=
PREFIX := /usr/local
SCRIPTNAME = ./note.sh
BINARY = note
BASHCOMPDIR ?= $(PREFIX)/share/bash-completion/completions
ZSHCOMPDIR ?= $(PREFIX)/share/zsh/site-functions
MANDIR ?= $(PREFIX)/share/man
VERSION = $(shell grep pkgver PKGBUILD | sed 's/pkgver=//')

.PHONY: all install uninstall

all: install

install:
	sed -i 's/%%VERSION%%/$(VERSION)/' manpage note.sh
	install -vDm755 $(SCRIPTNAME) $(DESTDIR)$(PREFIX)/bin/$(BINARY)
	install -vDm 0644 manpage "$(DESTDIR)$(MANDIR)/man1/note.1"
	@if command -v zsh &>/dev/null; then \
        install -vDm 0644 note.zsh-completion "$(DESTDIR)$(ZSHCOMPDIR)/_note"; \
    fi
	@if command -v bash &>/dev/null; then \
		install -vDm 0644 note.bash-completion "$(DESTDIR)$(BASHCOMPDIR)/note"; \
    fi

test:
	@bash -c 'set -e; for file in ./tests/*_test_*.sh; do $(SCRIPTNAME) init -p $$(mktemp -td "note.XXXXX"); bash "$$file"; done'
	@$(SCRIPTNAME) init >/dev/null

clean-test:
	rm -rf /tmp/note.*

uninstall:
	rm "$(DESTDIR)$(PREFIX)/bin/$(BINARY)"
	rm "$(DESTDIR)$(MANDIR)/man1/note.1"
	test -e "$(DESTDIR)$(BASHCOMPDIR)/note" && rm "$(DESTDIR)$(BASHCOMPDIR)/note"
	test -e "$(DESTDIR)$(ZSHCOMPDIR)/_note" && rm "$(DESTDIR)$(ZSHCOMPDIR)/_note"
