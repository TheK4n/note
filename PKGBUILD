# Maintainer: thek4n

pkgname='note'
pkgver=1.12.1
pkgrel=1
pkgdesc="Simple CLI notes manager"
arch=('any')
url='https://github.com/thek4n/note'
license=('MIT')
depends=(
  'git'
)
optdepends=(
  'python-grip: render tips in browser'
  'glow: render tips in terminal'
  'tree: tree of notes'
  'fzf: find notes'
)
conflicts=('note')
source=("$pkgname::git+https://github.com/thek4n/note.git#branch=release")
sha256sums=('SKIP')

package() {
    cd "$srcdir"/"$pkgname"
    make DESTDIR="$pkgdir" PREFIX="/usr" install
}
