#!/bin/sh

set -e

BASEDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

VERSION=1.6.0
DEBVERSION=1

ARCH=amd64
DEBIAN_ARCH=amd64
#ARCH=arm
#DEBIAN_ARCH=armhf
#ARCH=arm64
#DEBIAN_ARCH=arm64

PKG_NAME=nebula
PKG_DIR=${PKG_NAME}_${VERSION}-${DEBVERSION}_${DEBIAN_ARCH}
PKG_FILE=${PKG_DIR}.deb

GITHUB_ORG=slackhq
GITHUB_PRJ=nebula
GITHUB_OS=linux
GITHUB_ARCH=amd64
BINPKG_EXT=tar.gz
BINPKG_FILE=$GITHUB_PRJ-$GITHUB_OS-$GITHUB_ARCH.$BINPKG_EXT
BINPKG_URL=https://github.com/$GITHUB_ORG/$GITHUB_PRJ/releases/download/v$VERSION/$BINPKG_FILE
BINPKG_SHA256=f1a82c27624bf319c35f3bb4c136d5b82f26b014e8f5d16f64b3b0089f60220c

AUX_FILES="AUTHORS CHANGELOG.md LICENSE README.md"
AUX_FILES_SHA256="1d6a39a70c7160249d971ce629e5d3955404e9ca9b56a03f4ea5724a2db8d53f
 7457d1db03569b93358e8a55fd825e1dd3ecc31c88e7022c115c08f2ae6f41c1
 bc73ab7f000da78230eb9e674b34fbd42f4a0ce1c748e4124ca3a6458fb4b2fa
 4fce853dddcb4af26a67f2f5d5a0b2f3f12a0fd5b4a89792198348840e407109"


which strip >/dev/null
which upx >/dev/null

umask 022

cd "$BASEDIR"

echo "$BINPKG_SHA256 *$BINPKG_FILE" | sha256sum -c --quiet || wget -c "$BINPKG_URL"
gzip -dc "$BINPKG_FILE" | tar xv

strip nebula nebula-cert
#upx -9 nebula nebula-cert

for i in $(seq $(echo $AUX_FILES | wc -w)); do
  FILE_NAME=$(echo $AUX_FILES | cut -f $i -d ' ')
  FILE_SHA256=$(echo $AUX_FILES_SHA256 | cut -f $i -d ' ')
  echo "$FILE_SHA256 *$FILE_NAME" | sha256sum -c --quiet \
    || wget -c https://github.com/$GITHUB_ORG/$GITHUB_PRJ/blob/v$VERSION/$FILE_NAME
done

mkdir -p "${BASEDIR}/${PKG_DIR}/data"
cd "${BASEDIR}"

install -Dm755 nebula "${BASEDIR}/${PKG_DIR}/data/usr/bin/"
install -Dm755 nebula-cert "${BASEDIR}/${PKG_DIR}/data/usr/bin/nebula-cert"

install -Dm644 files/nebula.service "${BASEDIR}/${PKG_DIR}/data/lib/systemd/system/nebula.service"
install -Dm644 files/nebula@.service "${BASEDIR}/${PKG_DIR}/data/lib/systemd/system/nebula@.service"

for i in $AUX_FILES; do
  install -Dm644 $i "${BASEDIR}/${PKG_DIR}/data/usr/share/doc/${PKG_NAME}/$i"
done

install -dm755 "${BASEDIR}/${PKG_DIR}/data/etc/nebula"

(cd "${BASEDIR}/${PKG_DIR}/data" && tar c --owner=0 --group=0 *) | xz -c9 >"${BASEDIR}/${PKG_DIR}/data.tar.xz"



cp -r "${BASEDIR}/files/control" "${BASEDIR}/${PKG_DIR}/"
cp -r "${BASEDIR}/files/debian-binary" "${BASEDIR}/${PKG_DIR}/"
sed -i "${BASEDIR}/${PKG_DIR}/control/control" -e "s,@VERSION@,${VERSION}-${DEBVERSION}," -e "s,@ARCH@,${DEBIAN_ARCH},"

(cd "${BASEDIR}/${PKG_DIR}/control" && tar c --owner=0 --group=0 *) | xz -c9 >"${BASEDIR}/${PKG_DIR}/control.tar.xz"

(cd "$PKG_DIR" && ar r "$BASEDIR/$PKG_FILE" debian-binary control.tar.xz data.tar.xz)

lintian "$BASEDIR/$PKG_FILE" --no-tag-display-limit --suppress-tags statically-linked-binary,debian-changelog-file-missing,no-copyright-file,extended-description-is-empty

