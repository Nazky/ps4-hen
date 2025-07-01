#!/bin/bash
set -e

# Check if the script is run as root
if [ "$(id -u)" -eq 0 ]; then
  # Running as root: perform package installation only
  if [ -f /etc/os-release ]; then
    . /etc/os-release
  else
    echo "Cannot detect the distribution." >&2
    exit 1
  fi

  PKGS="ca-certificates curl unzip xxd make gcc"  # build tools

  echo "Installing packages as root..."
  case "$ID" in
    ubuntu|debian)
      apt-get update
      apt-get install -y --no-install-recommends $PKGS
      ;;
    fedora)
      dnf install -y $PKGS
      ;;
    arch)
      pacman -Sy --noconfirm $PKGS
      ;;
    *)
      echo "Unsupported distribution: $ID" >&2
      exit 1
      ;;
  esac
  echo "Packages installed. Please run the script again as your user to build."
  exit 0
fi

# If not root, run everything as the current user
echo "Running build steps as user $(whoami)..."

# Proceed with build process
cd kpayload
make clean
make
cd ..

mkdir -p tmp
cd tmp

# known bundled plugins
PRX_FILES="plugin_bootloader.prx plugin_loader.prx plugin_server.prx"

SKIP_DOWNLOAD=false
if [ -f plugins.zip ]; then
  SKIP_DOWNLOAD=true
else
  for prx in "${PRX_FILES[@]}"; do
    if [ -f "$prx" ]; then
      SKIP_DOWNLOAD=true
      break
    fi
  done
fi

if [ "$SKIP_DOWNLOAD" = false ]; then
  f="plugins.zip"
  rm -f $f
  curl -fLJO https://github.com/Scene-Collective/ps4-hen-plugins/releases/latest/download/$f
  unzip $f
fi

# need to use translation units to force rebuilds
# including as headers doesn't do it
for file in *.prx; do
  echo $file
  xxd -i "$file" | sed 's/^unsigned /static const unsigned /' > "../installer/source/${file}.inc.c"
done

cd ..

cd installer
make clean
make
cd ..

rm -f hen.bin
cp installer/installer.bin hen.bin

echo "Build process completed."
