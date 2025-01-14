#!/bin/bash
set -e

pkgname=cartesi-machine-emulator
pkgver=0.18.2
pkgrel=1
_pkgver=${pkgver}-test1
sources=("${pkgname}_${pkgver}.orig.tar.gz::https://github.com/cartesi/machine-emulator/archive/refs/tags/v${_pkgver}.tar.gz"
         "add-generated-files.diff::https://github.com/cartesi/machine-emulator/releases/download/v${_pkgver}/add-generated-files.diff")
sha256sums=("9d5fb1139f0997f665a2130ab4a698080d7299d29d5e69494764510587ca9566  ${pkgname}_${pkgver}.orig.tar.gz"
            "8f513f065e94e6ab969cd27186421e28db0091b3a563cd87280c3bb51671669e  add-generated-files.diff")
pkgdeb=${pkgname}_${pkgver}-${pkgrel}_$(dpkg --print-architecture).deb
pkgsigner="Cartesi Deb Builder <cartesi-deb-builder@builder>"

# Maybe skip build
if [ "$(find . -type f -printf '%T@\n' | sort -n | tail -1 | cut -d. -f1)" -lt "$(stat -c %Y /apt/${REPO_NAME}/${pkgdeb})" ]; then
    echo "${pkgname}: Package is up to date"; exit 0
fi

# Download
for f in ${sources[*]}; do wget -O $(echo $f | sed 's/::/ /'); done
echo "${sha256sums}" | sha256sum --check

# Extract
tar -xf ${pkgname}_${pkgver}.orig.tar.gz
mv machine-emulator-${_pkgver} ${pkgname}-${pkgver}
cd ${pkgname}-${pkgver}

# Patch
mv ../debian debian
cat <<EOF > debian/changelog
${pkgname} (${pkgver}-${pkgrel}) RELEASED; urgency=low

  * Please read the project sources for release change logs.

 -- ${pkgsigner}  $(date -R -u)
EOF
mv ../add-generated-files.diff debian/patches/
cp -a COPYING debian/copyright
if grep Ubuntu /etc/issue > /dev/null; then
    sed -i 's/libboost1.81/libboost1.83/' debian/control
fi
patch -Np1 < debian/patches/add-generated-files.diff

# Ensure reproducibility
export SOURCE_DATE_EPOCH=$(stat -c %Y ../build.sh) DEB_BUILD_OPTIONS="reproducible=+all"
touch -r ../build.sh **/**

# Package
apt-get build-dep --no-install-recommends -y .
dpkg-buildpackage --unsigned-source --unsigned-changes

# Update repository
mv ../*.{deb,orig.tar.gz,debian.tar.xz,dsc,buildinfo,changes} /apt/${REPO_NAME}/
/work/gen-index.sh
