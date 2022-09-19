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
AUX_FILES_SHA256="2e0c79a5024c1ac2ea8752980bbd4ee8c53297abc583d72f315ad0b5bd4c2e26 da4a6f48fbe5ac8cdf652f6dc6a0625dd583ca52a5ad8357398e1d6980fe8b2e aefd0cce553f24945ce1c692c3c4f9fda581f078ba82977845715cd18565b3bd 1f04b84a30932b4cc33dc9dad93dabeed757cc30b09be6dfb310922b82b24a79"

DEPENDENCIES="strip lintian"

echo Finding dependencies: $DEPENDENCIES
for i in $DEPENDENCIES; do
  which $i >/dev/null
done

umask 022

cd "$BASEDIR"

echo "$BINPKG_SHA256 *$BINPKG_FILE" | sha256sum -c --quiet || wget -c "$BINPKG_URL"
gzip -dc "$BINPKG_FILE" | tar xv

strip nebula nebula-cert

for i in $(seq $(echo $AUX_FILES | wc -w)); do
  FILE_NAME=$(echo $AUX_FILES | cut -f $i -d ' ')
  FILE_SHA256=$(echo $AUX_FILES_SHA256 | cut -f $i -d ' ')
  echo "$FILE_SHA256 *$FILE_NAME" | sha256sum -c --quiet \
    || wget -c https://github.com/$GITHUB_ORG/$GITHUB_PRJ/raw/v$VERSION/$FILE_NAME
done

mkdir -p "${BASEDIR}/${PKG_DIR}/data"
cd "${BASEDIR}"

install -Dt "${BASEDIR}/${PKG_DIR}/data/usr/bin" -m755 nebula nebula-cert
install -Dt "${BASEDIR}/${PKG_DIR}/data/lib/systemd/system" -m644 files/nebula.service files/nebula@.service
install -Dt "${BASEDIR}/${PKG_DIR}/data/usr/share/doc/${PKG_NAME}" -m644 $AUX_FILES

(cd "${BASEDIR}/${PKG_DIR}/data" && tar c --owner=0 --group=0 *) | xz -c9 >"${BASEDIR}/${PKG_DIR}/data.tar.xz"


cp -r "${BASEDIR}/files/control" "${BASEDIR}/${PKG_DIR}/"
cp -r "${BASEDIR}/files/debian-binary" "${BASEDIR}/${PKG_DIR}/"
sed -i "${BASEDIR}/${PKG_DIR}/control/control" -e "s,@VERSION@,${VERSION}-${DEBVERSION}," -e "s,@ARCH@,${DEBIAN_ARCH},"

(cd "${BASEDIR}/${PKG_DIR}/control" && tar c --owner=0 --group=0 *) | xz -c9 >"${BASEDIR}/${PKG_DIR}/control.tar.xz"

(cd "$PKG_DIR" && ar r "$BASEDIR/$PKG_FILE" debian-binary control.tar.xz data.tar.xz)

lintian "$BASEDIR/$PKG_FILE" --no-tag-display-limit --suppress-tags statically-linked-binary,debian-changelog-file-missing,no-copyright-file,extended-description-is-empty

