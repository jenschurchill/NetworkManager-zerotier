#!/bin/sh
# Build installable RPMs from this repository without a Makefile:
#
#   ./packaging/build-rpm.sh
#
# Produces a source tarball and binary RPMs under dist/ (rpmbuild does the
# work; this script only stages the tarball and redirects output dirs):
#   dist/x86_64/network-manager-zerotier-<ver>*.rpm        backend (Requires zerotier-one)
#   dist/x86_64/network-manager-zerotier-gtk-<ver>*.rpm    GTK4 editor plugin
set -eu

cd "$(dirname "$0")/.."

NAME=network-manager-zerotier
VERSION=$(sed -n "s/^  version: '\([^']*\)',/\1/p" meson.build)
DIST=dist
SPEC=packaging/${NAME}.spec

test -f "${SPEC}" || { echo "missing ${SPEC}" >&2; exit 1; }

mkdir -p "${DIST}/${NAME}-${VERSION}"
tar cf - \
    --exclude="./build" \
    --exclude="./${DIST}" \
    --exclude="./.git" \
    . | tar xf - -C "${DIST}/${NAME}-${VERSION}"
tar czf "${DIST}/${NAME}-${VERSION}.tar.gz" -C "${DIST}" "${NAME}-${VERSION}"
rm -rf "${DIST}/${NAME}-${VERSION}"

rpmbuild -bb \
    --define "_sourcedir $(pwd)/${DIST}" \
    --define "_srcrpmdir $(pwd)/${DIST}" \
    --define "_rpmdir $(pwd)/${DIST}" \
    --define "_builddir $(pwd)/${DIST}/BUILD" \
    "${SPEC}"

echo
echo "RPMs written to ${DIST}/:"
find "${DIST}" -name '*.rpm' -not -name '*debuginfo*' -not -name '*debugsource*' -printf '  %f\n'
