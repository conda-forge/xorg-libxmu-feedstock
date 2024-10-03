#!/bin/bash

set -e

# Adopt a Unix-friendly path if we're on Windows (see bld.bat).
[ -n "$PATH_OVERRIDE" ] && export PATH="$PATH_OVERRIDE"

# On Windows we want $LIBRARY_PREFIX in both "mixed" (C:/Conda/...) and Unix
# (/c/Conda) forms, but Unix form is often "/" which can cause problems.
if [ -n "$LIBRARY_PREFIX_M" ] ; then
    mprefix="$LIBRARY_PREFIX_M"
    if [ "$LIBRARY_PREFIX_U" = / ] ; then
        uprefix=""
    else
        uprefix="$LIBRARY_PREFIX_U"
    fi
else
    mprefix="$PREFIX"
    uprefix="$PREFIX"
fi

configure_args=(
    --prefix=$mprefix
    --disable-static
    --disable-dependency-tracking
    --disable-selective-werror
    --disable-silent-rules
)

# On Windows we need to regenerate the configure scripts.
if [ -n "$CYGWIN_PREFIX" ] ; then
    am_version=1.16 # keep sync'ed with meta.yaml
    export ACLOCAL=aclocal-$am_version
    export AUTOMAKE=automake-$am_version
    autoreconf_args=(
        --force
        --verbose
        --install
        -I "$mprefix/share/aclocal"
        -I "$BUILD_PREFIX_M/Library/usr/share/aclocal"
    )
    autoreconf "${autoreconf_args[@]}"

    # And we need to add the search path that lets libtool find the
    # msys2 stub libraries for ws2_32.
    platlibs=$(cd $(dirname $($CC --print-prog-name=ld))/../sysroot/usr/lib && pwd -W)
    test -f $platlibs/libws2_32.a || { echo "error locating libws2_32" ; exit 1 ; }
    export LDFLAGS="$LDFLAGS -L$platlibs"
else
    # Get an updated config.sub and config.guess
    cp $BUILD_PREFIX/share/gnuconfig/config.* .

    autoreconf_args=(
        --force
        --verbose
        --install
        -I "${PREFIX}/share/aclocal"
        -I "${BUILD_PREFIX}/share/aclocal"
    )
    autoreconf "${autoreconf_args[@]}"

    configure_args+=("--build=${BUILD}")
fi

export PKG_CONFIG_LIBDIR=$uprefix/lib/pkgconfig:$uprefix/share/pkgconfig

if [[ "${CONDA_BUILD_CROSS_COMPILATION}" == "1" ]] ; then
    configure_args+=(
        --enable-malloc0returnsnull
    )
fi

./configure "${configure_args[@]}"
make -j$CPU_COUNT
make install

rm -rf $uprefix/share/man $uprefix/share/doc/${PKG_NAME#xorg-}
