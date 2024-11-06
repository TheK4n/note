

<h1 align="center">Note</h1>

<p align="center">
  <a href="https://github.com/TheK4n">
    <img src="https://img.shields.io/github/followers/TheK4n?label=Follow&style=social">
  </a>
  <a href="https://github.com/TheK4n/note">
    <img src="https://img.shields.io/github/stars/TheK4n/note?style=social">
  </a>
</p>

* [Features](#features)
* [Installation](#installation)
* [Usage](#usage)
* [Roadmap](#roadmap)

---

Simple notes storage mechanism

## Features

* Simple synchronization via git
* FZF Integration
* Friendly zsh and bash completions
* Saving all notes changes with git
* It respects widely used environment variables such as `VISUAL` and `PAGER`


> [!NOTE]
>
> It is highly recommended to use the [neovim](https://github.com/neovim/neovim) as editor and [peek.nvim](https://github.com/toppair/peek.nvim) plugin as markdown previewer


## Installation

### Dependencies

Dependencies:
* git

Optional dependencies:
* bat - For render notes in terminal
* tree - Show tree of notes
* fzf - Beauty notes search
* rg - Search notes by content


### Install from source:
```sh
git clone https://github.com/thek4n/note.git
cd note
make install
```

### Install from [AUR](https://aur.archlinux.org/packages/note-manager) (recommended):
```sh
yay -S note-manager
```

### Run tests
```sh
make test
```


## Usage
```sh
export PAGER=less
export VISUAL=nvim
note init -p ~/.notes -r ssh://remote/home/user/.notes-storage
note edit someNote.md
note show someNote.md
note git push
```

---

```sh
note sync  # to automaticly pull and merge remote changes
```

> [!NOTE]
>
> You can also check out `man note` for documentation.


### Other markdown previewers

[Grip](https://github.com/joeyespo/grip)
```sh
NOTEPAGER="grip -b" note show someNote.md
```
[Glow](https://github.com/charmbracelet/glow)
```sh
NOTEPAGER="glow" note show someNote.md
```

## Roadmap

* [ ] Graph building based on markdown links
* [X] ~~Rewrite on posix shell~~
* [X] ~~Lock-file~~
* [X] ~~Synchronization~~
* [X] ~~Search by notes~~
* [X] ~~Directories~~
* [X] ~~Tree of notes~~


<h1 align="center"><a href="#top">▲</a></h1>