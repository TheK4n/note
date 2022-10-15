# Maintainer: thek4n

pkgname='note'
pkgver=0.1.1
pkgrel=1
pkgdesc=""
arch=('any')
license=('MIT')
depends=(
  'git'
)
optdepends=(
  'python3: for python-grip'
  'python-grip: render tips in browser'
  'glow: render tips in terminal'
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
