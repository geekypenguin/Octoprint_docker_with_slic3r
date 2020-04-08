
# alexrj's slic3r, the original
# SLIC3R_REPO="https://github.com/alexrj/Slic3r.git"
# SLIC3R_VERSION="master"
# SLIC3R_DIR=~/Slic3r

#prusa3d, version 1.33.8 (without Intel Threading Building Blocks)
#SLIC3R_REPO="https://github.com/prusa3d/Slic3r.git"
#SLIC3R_VERSION="version_1.33.8"
#SLIC3R_DIR=~/Slic3r

#prusa3d, latest (with Intel Threading Building Blocks).
SLIC3R_REPO="https://github.com/alexrj/Slic3r.git"
SLIC3R_VERSION="master"
SLIC3R_DIR=/Slic3r
TBB_RELEASE="https://github.com/01org/tbb/archive/2017_U5.tar.gz"
TBB_DIR=/tbb
TBB_VERSION="5"
YOUR_NAME="Your Name"
YOUR_EMAIL="email address"

if [ ! -z "${TBB_DIR}" ]; then
mkdir -p ${TBB_DIR}
cd ${TBB_DIR}
wget ${TBB_RELEASE}
tar xzvf $(basename ${TBB_RELEASE})
cd tbb*
make tbb CXXFLAGS="-DTBB_USE_GCC_BUILTINS=1 -D__TBB_64BIT_ATOMICS=0"
cd ${TBB_DIR}
mkdir libtbb-dev_${TBB_VERSION}_armhf
cd libtbb-dev_${TBB_VERSION}_armhf
mkdir -p usr/local/lib/pkgconfig
mkdir -p usr/local/include
mkdir DEBIAN

cd ${TBB_DIR}/libtbb-dev_${TBB_VERSION}_armhf/DEBIAN
cat > control << EOF
Package: libtbb-dev
Priority: extra
Section: universe/libdevel
Maintainer: ${YOUR_NAME} <${YOUR_EMAIL}>
Architecture: armhf
Version: ${TBB_VERSION}
Homepage: http://threadingbuildingblocks.org/
Description: parallelism library for C++ - development files
 TBB is a library that helps you leverage multi-core processor
 performance without having to be a threading expert. It represents a
 higher-level, task-based parallelism that abstracts platform details
 and threading mechanism for performance and scalability.
 .
 (Note: if you are a user of the i386 architecture, i.e., 32-bit Intel
 or compatible hardware, this package only supports Pentium4-compatible
 and higher processors.)
 .
 This package includes the TBB headers, libs and pkg-config
EOF

cd ${TBB_DIR}/libtbb-dev_${TBB_VERSION}_armhf/usr/local/lib
cp ${TBB_DIR}/tbb*/build/*_release/libtbb.so.2 .
ln -s libtbb.so.2 libtbb.so

cd ${TBB_DIR}/tbb*/include
cp -r serial tbb ${TBB_DIR}/libtbb-dev_${TBB_VERSION}_armhf/usr/local/include

cd ${TBB_DIR}/libtbb-dev_${TBB_VERSION}_armhf/usr/local/lib/pkgconfig
cat > tbb.pc << EOF
# Manually added pkg-config file for tbb - START
prefix=/usr/local
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
Name: tbb
Description: thread building block
Version: ${TBB_VERSION}
Cflags: -I\${includedir} -DTBB_USE_GCC_BUILTINS=1 -D__TBB_64BIT_ATOMICS=0
Libs: -L\${libdir} -ltbb
# Manually added pkg-config file for tbb - END
EOF

cd ${TBB_DIR}
sudo chown -R root:staff libtbb-dev_${TBB_VERSION}_armhf
sudo dpkg-deb --build libtbb-dev_${TBB_VERSION}_armhf

sudo dpkg -i ${TBB_DIR}/libtbb-dev_${TBB_VERSION}_armhf.deb
sudo ldconfig
fi
git clone ${SLIC3R_REPO} ${SLIC3R_DIR}
cd ${SLIC3R_DIR}
git checkout ${SLIC3R_VERSION}
sudo perl Build.PL
