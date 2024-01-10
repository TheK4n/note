

<h1 align="center">Note</h1>

<p align="center">
  <a href="https://github.com/TheK4n">
    <img src="https://img.shields.io/github/followers/TheK4n?label=Follow&style=social">
  </a>
</p>

* [Project description](#chapter-0)
* [Installation](#chapter-1)
* [Usage](#chapter-2)
* [Roadmap](#chapter-3)


<a id="chapter-0"></a>
## Project description 

Simple notes storage mechanism

### Features

* Simple synchronization via git
* Logging all notes changes with git
* You can use your favorite editor: `EDITOR=nvim note edit something.md`
* You can use your favorite previewer: `PAGER='grip -b' note show something.md`
* Beautiful zsh and bash completions

**It is highly recommended to use the neovim + peek.nvim plugin.**


<a id="chapter-1"></a>
## Installation

### Dependencies

Dependencies:
* git

Optional dependencies:
* bat - For render note in terminal
* tree - Show tree of notes
* fzf - Beauty note search


### Install from source:
```bash
git clone https://github.com/thek4n/note.git
cd note
make install
```

### Install from AUR:
```bash
yay -S note-manager
```

### Run tests
```bash
make test
```


<a id="chapter-2"></a>
## Usage

```bash
export PAGER=less
export EDITOR=nvim
note init -p ~/.notes -r ssh://remote/home/user/.notes-storage
note edit someNote.md
note show someNote.md
note git push
```

```bash
note sync  # to automaticly pull and merge remote changes
```


<a id="chapter-3"></a>
## Roadmap

* [ ] Graph building based on markdown links
* [X] ~~Lock-file~~
* [X] ~~Synchronization~~
* [X] ~~Search by notes~~
* [X] ~~Directories~~
* [X] ~~Tree of notes~~


<h1 align="center"><a href="#top">▲</a></h1>
