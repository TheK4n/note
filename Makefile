DESTDIR :=
PREFIX := /usr/local
SCRIPTNAME = ./note.sh
BINARY = note
BASHCOMPDIR ?= $(PREFIX)/share/bash-completion/completions
ZSHCOMPDIR ?= $(PREFIX)/share/zsh/site-functions
MANDIR ?= $(PREFIX)/share/man

.PHONY: all install uninstall

all: install

install:
	install -Dm755 $(SCRIPTNAME) $(DESTDIR)$(PREFIX)/bin/$(BINARY)
	install -vd "$(DESTDIR)$(MANDIR)/man1" && install -m 0644 manpage "$(DESTDIR)$(MANDIR)/man1/note.1"
	@if which zsh &>/dev/null; then \
        install -vd "$(DESTDIR)$(ZSHCOMPDIR)" && install -m 0644 note.zsh-completion "$(DESTDIR)$(ZSHCOMPDIR)/_note"; \
    fi
	@if which bash &>/dev/null; then \
		install -vd "$(DESTDIR)$(BASHCOMPDIR)" && install -m 0644 note.bash-completion "$(DESTDIR)$(BASHCOMPDIR)/note"; \
    fi

test:
	@bash -c 'set -e; for file in ./tests/*.sh; do $(SCRIPTNAME) init -p $$(mktemp -td "note.XXXXX"); bash "$$file"; done'
	@$(SCRIPTNAME) init >/dev/null

clean-test:
	rm -rf /tmp/note.*

uninstall:
	rm "$(DESTDIR)$(PREFIX)/bin/$(BINARY)"
	rm "$(DESTDIR)$(MANDIR)/man1/note.1"
	test -e "$(DESTDIR)$(BASHCOMPDIR)/note" && rm "$(DESTDIR)$(BASHCOMPDIR)/note"
	test -e "$(DESTDIR)$(ZSHCOMPDIR)/_note" && rm "$(DESTDIR)$(ZSHCOMPDIR)/_note"
