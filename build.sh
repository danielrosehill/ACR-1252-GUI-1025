#!/bin/bash
set -e

# Build script for ACR1252 NFC GUI
# Creates distributable packages for Ubuntu (executable, .deb, AppImage)

VERSION=${1:-"1.0.0"}
BUILD_DIR="build"
DIST_DIR="dist"
PACKAGE_NAME="acr1252-nfc-gui"
APP_NAME="ACR1252-NFC-GUI"

# Build options - set to 1 to enable
BUILD_EXECUTABLE=1
BUILD_DEB=1
BUILD_APPIMAGE=1
BUILD_SOURCE=1

echo "Building ACR1252 NFC GUI v${VERSION}..."

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf ${BUILD_DIR} ${DIST_DIR}
mkdir -p ${BUILD_DIR} ${DIST_DIR}

# Setup build environment
setup_build_env() {
    echo "Setting up build environment..."

    # Create virtual environment if it doesn't exist
    if [ ! -d "${BUILD_DIR}/.venv" ]; then
        python3 -m venv ${BUILD_DIR}/.venv
    fi

    # Activate virtual environment
    source ${BUILD_DIR}/.venv/bin/activate

    # Install build dependencies
    pip install --upgrade pip > /dev/null
    pip install -r requirements.txt > /dev/null

    if [ "$BUILD_EXECUTABLE" = "1" ]; then
        if ! python3 -c "import PyInstaller" 2>/dev/null; then
            echo "Installing PyInstaller..."
            pip install pyinstaller > /dev/null
        fi
    fi
}

# Check system dependencies
check_dependencies() {
    local missing_deps=()

    if [ "$BUILD_DEB" = "1" ]; then
        if ! command -v dpkg-deb &> /dev/null; then
            missing_deps+=("dpkg-dev")
        fi
        if ! command -v fakeroot &> /dev/null; then
            missing_deps+=("fakeroot")
        fi
    fi

    if [ "$BUILD_APPIMAGE" = "1" ]; then
        if ! command -v appimagetool &> /dev/null; then
            echo "Note: appimagetool not found. You can install it from https://appimage.github.io/appimagetool/"
            BUILD_APPIMAGE=0
        fi
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Missing dependencies: ${missing_deps[@]}"
        echo "Install with: sudo apt install ${missing_deps[@]}"
        exit 1
    fi
}

check_dependencies
setup_build_env

# Build standalone executable with PyInstaller
if [ "$BUILD_EXECUTABLE" = "1" ]; then
    echo ""
    echo "Building standalone executable..."

    # Create main entry point for PyInstaller
    cat > ${BUILD_DIR}/main.py << 'EOF'
#!/usr/bin/env python3
import sys
from nfc_gui.gui import main

if __name__ == '__main__':
    sys.exit(main())
EOF

    # Run PyInstaller
    pyinstaller --noconfirm \
        --onefile \
        --windowed \
        --name="${PACKAGE_NAME}" \
        --add-data="nfc_gui:nfc_gui" \
        --hidden-import=PyQt5 \
        --hidden-import=pyscard \
        --hidden-import=ndeflib \
        --hidden-import=pyperclip \
        ${BUILD_DIR}/main.py

    # Move executable to dist directory
    if [ -f "dist/${PACKAGE_NAME}" ]; then
        mv "dist/${PACKAGE_NAME}" "${DIST_DIR}/${PACKAGE_NAME}-${VERSION}-linux-x86_64"
        chmod +x "${DIST_DIR}/${PACKAGE_NAME}-${VERSION}-linux-x86_64"
        echo "✓ Standalone executable created: ${DIST_DIR}/${PACKAGE_NAME}-${VERSION}-linux-x86_64"
    fi
fi

# Build Debian package
if [ "$BUILD_DEB" = "1" ]; then
    echo ""
    echo "Building Debian package..."

    DEB_DIR="${BUILD_DIR}/deb"
    DEB_PACKAGE="${PACKAGE_NAME}_${VERSION}_amd64"

    mkdir -p ${DEB_DIR}/${DEB_PACKAGE}/{DEBIAN,usr/bin,usr/share/applications,usr/share/pixmaps,usr/lib/${PACKAGE_NAME}}

    # Create DEBIAN/control file
    cat > ${DEB_DIR}/${DEB_PACKAGE}/DEBIAN/control << EOF
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Depends: python3 (>= 3.8), python3-pyqt5, pcscd, libpcsclite1
Maintainer: Your Name <your.email@example.com>
Description: NFC Reader/Writer GUI for ACS ACR1252
 A PyQt5-based GUI application for reading and writing NFC tags
 using the ACS ACR1252 USB NFC Reader/Writer.
EOF

    # Copy application files
    cp -r nfc_gui ${DEB_DIR}/${DEB_PACKAGE}/usr/lib/${PACKAGE_NAME}/
    cp requirements.txt ${DEB_DIR}/${DEB_PACKAGE}/usr/lib/${PACKAGE_NAME}/

    # Create launcher script
    cat > ${DEB_DIR}/${DEB_PACKAGE}/usr/bin/${PACKAGE_NAME} << 'EOF'
#!/bin/bash
cd /usr/lib/acr1252-nfc-gui
python3 -m nfc_gui.gui "$@"
EOF
    chmod +x ${DEB_DIR}/${DEB_PACKAGE}/usr/bin/${PACKAGE_NAME}

    # Create desktop entry
    cat > ${DEB_DIR}/${DEB_PACKAGE}/usr/share/applications/${PACKAGE_NAME}.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=ACR1252 NFC GUI
Comment=NFC Reader/Writer for ACS ACR1252
Exec=${PACKAGE_NAME}
Icon=${PACKAGE_NAME}
Terminal=false
Categories=Utility;
EOF

    # Create postinst script
    cat > ${DEB_DIR}/${DEB_PACKAGE}/DEBIAN/postinst << 'EOF'
#!/bin/bash
set -e

# Install Python dependencies
pip3 install --system pyscard ndeflib pyperclip || true

# Start pcscd service
systemctl enable pcscd || true
systemctl start pcscd || true

echo "ACR1252 NFC GUI installed successfully!"
echo "Run '${PACKAGE_NAME}' to start the application"
EOF
    chmod +x ${DEB_DIR}/${DEB_PACKAGE}/DEBIAN/postinst

    # Build the package
    fakeroot dpkg-deb --build ${DEB_DIR}/${DEB_PACKAGE}
    mv ${DEB_DIR}/${DEB_PACKAGE}.deb ${DIST_DIR}/

    echo "✓ Debian package created: ${DIST_DIR}/${DEB_PACKAGE}.deb"
fi

# Build AppImage
if [ "$BUILD_APPIMAGE" = "1" ]; then
    echo ""
    echo "Building AppImage..."

    APPIMAGE_DIR="${BUILD_DIR}/appimage"
    APPDIR="${APPIMAGE_DIR}/${APP_NAME}.AppDir"

    mkdir -p ${APPDIR}/usr/{bin,lib,share/applications,share/icons/hicolor/256x256/apps}

    # Copy executable from PyInstaller build
    if [ -f "${DIST_DIR}/${PACKAGE_NAME}-${VERSION}-linux-x86_64" ]; then
        cp "${DIST_DIR}/${PACKAGE_NAME}-${VERSION}-linux-x86_64" ${APPDIR}/usr/bin/${PACKAGE_NAME}
    else
        echo "Warning: Standalone executable not found, skipping AppImage build"
        BUILD_APPIMAGE=0
    fi

    if [ "$BUILD_APPIMAGE" = "1" ]; then
        # Create AppRun
        cat > ${APPDIR}/AppRun << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/acr1252-nfc-gui" "$@"
EOF
        chmod +x ${APPDIR}/AppRun

        # Create .desktop file
        cat > ${APPDIR}/${PACKAGE_NAME}.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=ACR1252 NFC GUI
Comment=NFC Reader/Writer for ACS ACR1252
Exec=${PACKAGE_NAME}
Icon=${PACKAGE_NAME}
Terminal=false
Categories=Utility;
EOF

        # Build AppImage
        cd ${APPIMAGE_DIR}
        ARCH=x86_64 appimagetool ${APP_NAME}.AppDir ../${DIST_DIR}/${PACKAGE_NAME}-${VERSION}-x86_64.AppImage 2>&1 | grep -v "qt.qpa" | grep -v "QFont" || true
        cd ../..

        echo "✓ AppImage created: ${DIST_DIR}/${PACKAGE_NAME}-${VERSION}-x86_64.AppImage"
    fi
fi

# Create source archives
if [ "$BUILD_SOURCE" = "1" ]; then
    echo ""
    echo "Creating source archives..."

    PACKAGE_DIR="${BUILD_DIR}/${PACKAGE_NAME}-${VERSION}"
    mkdir -p ${PACKAGE_DIR}

    # Copy application files
    cp -r nfc_gui ${PACKAGE_DIR}/
    cp requirements.txt ${PACKAGE_DIR}/
    cp run-gui.sh ${PACKAGE_DIR}/
    cp README.md ${PACKAGE_DIR}/
    [ -d screenshots ] && cp -r screenshots ${PACKAGE_DIR}/

    # Remove __pycache__ directories
    find ${PACKAGE_DIR} -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

    # Create tarball
    cd ${BUILD_DIR}
    tar -czf ../${DIST_DIR}/${PACKAGE_NAME}-${VERSION}.tar.gz ${PACKAGE_NAME}-${VERSION}
    cd ..

    # Create zip archive
    cd ${BUILD_DIR}
    zip -r ../${DIST_DIR}/${PACKAGE_NAME}-${VERSION}.zip ${PACKAGE_NAME}-${VERSION} -q
    cd ..

    echo "✓ Source archives created"
fi

# Generate checksums
echo ""
echo "Generating checksums..."
cd ${DIST_DIR}
for file in *; do
    if [ -f "$file" ] && [[ "$file" != *.sha256 ]]; then
        sha256sum "$file" > "${file}.sha256"
    fi
done
cd ..

# Display results
echo ""
echo "═══════════════════════════════════════"
echo "Build complete!"
echo "═══════════════════════════════════════"
echo "Package version: ${VERSION}"
echo "Output directory: ${DIST_DIR}/"
echo ""
echo "Files created:"
ls -lh ${DIST_DIR}/
echo ""
echo "Installation instructions:"
if [ "$BUILD_EXECUTABLE" = "1" ] && [ -f "${DIST_DIR}/${PACKAGE_NAME}-${VERSION}-linux-x86_64" ]; then
    echo "• Standalone executable: ./${PACKAGE_NAME}-${VERSION}-linux-x86_64"
fi
if [ "$BUILD_DEB" = "1" ] && [ -f "${DIST_DIR}/${PACKAGE_NAME}_${VERSION}_amd64.deb" ]; then
    echo "• Debian package: sudo dpkg -i ${PACKAGE_NAME}_${VERSION}_amd64.deb"
fi
if [ -f "${DIST_DIR}/${PACKAGE_NAME}-${VERSION}-x86_64.AppImage" ]; then
    echo "• AppImage: chmod +x ${PACKAGE_NAME}-${VERSION}-x86_64.AppImage && ./${PACKAGE_NAME}-${VERSION}-x86_64.AppImage"
fi
echo ""
