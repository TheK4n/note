

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


<a id="chapter-1"></a>
## Installation


### Dependencies

Dependencies:
* git

Optional dependencies:
* grip - For render note in browser
* glow - For render note in terminal
* tree - Show tree of notes


### Install from source:
```bash
git clone https://github.com/thek4n/note.git
cd note
make install
```

### Install by pacman (Recommended):
```bash
git clone https://github.com/thek4n/note.git
cd note
makepkg -sic && git clean -df
```


<a id="chapter-2"></a>
## Usage

```bash
note init -p ~/.notes -r ssh://remote/home/user/.notes-storage
note sync
note edit someNote.md
note render so<Tab>  # open localhost:6751 in browser
note git push
```


<a id="chapter-3"></a>
## Roadmap

* [ ] Lock-file
* [X] ~~Synchronization~~
* [X] ~~Search by notes~~
* [X] ~~Directories~~
* [X] ~~Tree of notes~~


<h1 align="center"><a href="#top">▲</a></h1>
