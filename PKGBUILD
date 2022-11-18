# Maintainer: thek4n

pkgname='note'
pkgver=1.4.6
pkgrel=2
pkgdesc="Simple CLI notes manager"
arch=('any')
license=('MIT')
depends=(
  'git'
)
optdepends=(
  'python3: for python-grip'
  'python-grip: render tips in browser'
  'glow: render tips in terminal'
  'tree: tree of notes'
)
makedepends=('git')
url='https://github.com/thek4n/note'
conflicts=('note')
source=("$pkgname::git+https://github.com/thek4n/note.git#branch=master")
sha256sums=('SKIP')

package() {
    cd "$srcdir"/"$pkgname"
    make DESTDIR="$pkgdir" PREFIX="/usr" install
}
