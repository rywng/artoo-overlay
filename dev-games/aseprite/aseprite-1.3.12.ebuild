# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=(python3_{10..13})

inherit cmake desktop flag-o-matic python-any-r1 xdg-utils

SKIA_VER="m102"
# Latest release in aseprite's skia fork: https://github.com/aseprite/skia/releases/latest
# Don't use skia.googlesource.com, it produces non-reproducible tarballs
SKIA_REV="m102-861e4743af"
SKIA_DIR="skia-${SKIA_REV}"

DESCRIPTION="Animated sprite editor & pixel art tool"
HOMEPAGE="https://www.aseprite.org"
SRC_URI="
	https://github.com/aseprite/aseprite/releases/download/v${PV}/Aseprite-v${PV}-Source.zip
	https://github.com/aseprite/skia/releases/download/${SKIA_REV}/Skia-Linux-Release-x64-libstdc++.zip -> ${SKIA_DIR}.zip"

S="${WORKDIR}"

# See https://github.com/aseprite/aseprite#license
LICENSE="Aseprite-EULA MIT"
SLOT="0"
KEYWORDS="~amd64"

IUSE="kde test"
RESTRICT="bindist mirror !test? ( test )"

# These are currently removed
# app-arch/libarchive:=
# dev-libs/tinyxml
# webp? ( media-libs/libwebp:= )"
#
CDEPEND="
	app-text/cmark:=
	dev-cpp/json11
	dev-libs/libfmt
	dev-libs/tinyxml
	media-libs/fontconfig:=
	media-libs/freetype
	media-libs/giflib:=
	media-libs/harfbuzz
	media-libs/libjpeg-turbo:=
	media-libs/libpng:=
	media-libs/libwebp:=
	net-misc/curl
	sys-libs/zlib:=
	virtual/opengl
	x11-libs/libX11
	x11-libs/libXcursor
	x11-libs/libXi
	x11-libs/libxcb:=
	kde? (
		dev-qt/qtcore:5
		dev-qt/qtgui:5
		kde-frameworks/kio:5
	) "
RDEPEND="
	${CDEPEND}
	gnome-extra/zenity
"
DEPEND="
	${CDEPEND}
	x11-base/xorg-proto"
BDEPEND="
	${PYTHON_DEPS}
	test? ( dev-cpp/gtest )
	app-arch/unzip
	dev-build/gn
	virtual/pkgconfig"

DOCS=(
	docs/ase-file-specs.md
	docs/gpl-palette-extension.md
	README.md
)

PATCHES=(
	# "${FILESDIR}/skia-${SKIA_VER}_remove_angle2.patch"
	"${FILESDIR}/${PN}-1.3.10_shared_libarchive.patch"
	"${FILESDIR}/${PN}-1.3.2_shared_json11.patch"
	# "${FILESDIR}/${PN}-1.3.2_shared_webp.patch"
	# "${FILESDIR}/${PN}-1.2.35_laf_fixes.patch"
	"${FILESDIR}/${PN}-1.3.2_shared_fmt.patch"
	"${FILESDIR}/${PN}-tinyexif-link-system-tinyxml.patch"
	# "${FILESDIR}/${PN}-1.3.2_strict-aliasing.patch"
	# "${FILESDIR}/${PN}-1.3.5_laf-strict-aliasing.patch"
)

src_prepare() {
	cmake_src_prepare
	# Skia: remove custom optimizations
	# sed -i -e 's:"\/\/gn\/skia\:optimize",::g' \
	# 	"skia-${SKIA_REV}/gn/BUILDCONFIG.gn" || die
	# Aseprite: don't install tga bundled library
	sed -i -e '/install/d' src/tga/CMakeLists.txt || die
	# Aseprite: don't use bundled gtest
	sed -i -e '/add_subdirectory(googletest)/d' \
		laf/third_party/CMakeLists.txt || die
	# Fix shebang in thumbnailer
	sed -i -e 's:#!/usr/bin/sh:#!/bin/sh:' \
		src/desktop/linux/aseprite-thumbnailer || die
}

src_configure() {
	# -Werror=strict-aliasing, -Werror=odr, -Werror=lto-type-mismatch
	# https://bugs.gentoo.org/924692
	# https://github.com/aseprite/aseprite/issues/4413
	#
	# There is a bundled skia that fails with ODR errors. When excluding just
	# skia from testing, aseprite itself failed with strict-aliasing (before
	# upstream PR#84), and when that is disabled, fails again with ODR and
	# lto-type-mismatch issues.
	#
	# There are a lot of issues, so don't trust any fixes without thorough
	# testing.
	filter-lto
	filter-flags "-Werror=strict-aliasing" "-Werror=odr" "-Werror=lto-type-mismatch"

	einfo "Aseprite configuration"
	cd "${WORKDIR}" || die

	local mycmakeargs=(
		-DENABLE_CCACHE=OFF
		-DENABLE_DESKTOP_INTEGRATION=ON
		-DENABLE_STEAM=OFF
		-DENABLE_TESTS="$(usex test)"
		-DENABLE_QT_THUMBNAILER="$(usex kde)"
		-DENABLE_UPDATER=OFF
		# -DENABLE_WEBP="$(usex webp)"
		-DLAF_WITH_EXAMPLES=OFF
		-DLAF_WITH_TESTS="$(usex test)"
		-DFULLSCREEN_PLATFORM=ON
		-DLAF_BACKEND=skia
		-DSKIA_DIR="${WORKDIR}/${SKIA_DIR}/"
		-DSKIA_LIBRARY_DIR="${WORKDIR}/${SKIA_DIR}/out/Release-x64/"
		-DSKIA_LIBRARY="${WORKDIR}/${SKIA_DIR}/out/Release-x64/libskia.a"
		-DSKSHAPER_LIBRARY="${WORKDIR}/${SKIA_DIR}/out/Release-x64/libskshaper.a"
		-DUSE_SHARED_JSON11=OFF # Custom methods added to bundled version
		-DUSE_SHARED_LIBARCHIVE=ON
		# -DUSE_SHARED_WEBP=ON
		-DUSE_SHARED_CMARK=ON
		-DUSE_SHARED_CURL=ON
		-DUSE_SHARED_FMT=ON
		-DUSE_SHARED_FREETYPE=ON
		-DUSE_SHARED_GIFLIB=ON
		-DUSE_SHARED_HARFBUZZ=ON
		-DUSE_SHARED_JPEGLIB=ON
		-DUSE_SHARED_LIBPNG=ON
		-DUSE_SHARED_PIXMAN=ON
		-DUSE_SHARED_TINYXML=ON
		-DUSE_SHARED_ZLIB=ON
	)
	cmake_src_configure
}

src_compile() {
	# einfo "Skia compilation"
	# cd "${WORKDIR}/${SKIA_DIR}" || die
	# eninja -C out/Static
	#
	einfo "Aseprite compilation"
	cd "${WORKDIR}" || die
	cmake_src_compile
}

src_unpack() {
	unzip -q "${DISTDIR}/${SKIA_DIR}.zip" -d "${SKIA_DIR}" || die
	unpack "Aseprite-v${PV}-Source.zip"
}

src_install() {
	newicon -s 64 "${S}/data/icons/ase64.png" "${PN}.png"
	cmake_src_install

	einfo "Removing unnecessary headers and object files"
	# Strip static opject files and headers
	rm "${ED}/usr/lib64/libTinyEXIF.a" || die
	rm "${ED}/usr/include/TinyEXIF.h" || die
	rm "${ED}/usr/lib/pkgconfig/libarchive.pc" || die
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update
	xdg_mimeinfo_database_update
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
	xdg_mimeinfo_database_update
}
