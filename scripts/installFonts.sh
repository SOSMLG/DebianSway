#!/usr/bin/env bash
# Arabic + English Noto Fonts + JetBrainsMono Nerd Font setup on Debian (Colorful Version)

set -e

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
BOLD="\e[1m"
RESET="\e[0m"

info()    { echo -e "${BLUE}${BOLD}➤${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}✔${RESET} $1"; }
warn()    { echo -e "${YELLOW}${BOLD}⚠${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}✖${RESET} $1"; }

# Step 1: Install Noto Fonts
info "Installing Font Awesome and Noto fonts (English + Arabic)..."
sudo apt update
sudo apt install -y fonts-font-awesome fonts-noto-core fonts-noto-unhinted curl
success "Noto fonts installed."

# Step 2: Create fontconfig directory
info "Creating fontconfig directory..."
mkdir -p ~/.config/fontconfig
success "~/.config/fontconfig ready."

# Step 3: Write fonts.conf
FONTCONF=~/.config/fontconfig/fonts.conf
info "Writing fonts.conf..."
cat > "$FONTCONF" <<'EOF'
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <!-- Defaults -->
  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Serif</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>
  <alias>
    <family>sans</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>JetBrainsMono Nerd Font Mono</family>
      <family>Noto Sans Mono</family>
    </prefer>
  </alias>
  <!-- Arial -->
  <alias>
    <family>Arial</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>
</fontconfig>
EOF
success "fonts.conf written to $FONTCONF"
# Step 4: Install JetBrainsMono Nerd Font
info "Installing JetBrainsMono Nerd Font..."
mkdir -p ~/.local/share/fonts
pushd ~/.local/share/fonts > /dev/null

# Try GitHub first
GITHUB_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
SOURCEFORGE_URL="https://sourceforge.net/projects/nerd-fonts.mirror/files/v3.4.0/JetBrainsMono.zip/download"

if curl -sLO "$GITHUB_URL"; then
    # Extract .tar.xz file
    if ! tar -xf JetBrainsMono.tar.xz; then
        error "Failed to extract JetBrainsMono Nerd Font"
        popd > /dev/null
        exit 1
    fi
    rm -f JetBrainsMono.tar.xz
else
    warn "GitHub download failed, trying SourceForge..."
    if curl -sLO "$SOURCEFORGE_URL"; then
        # Extract .zip file
        if ! unzip JetBrainsMono.zip; then
            error "Failed to extract JetBrainsMono Nerd Font"
            popd > /dev/null
            exit 1
        fi
        rm -f JetBrainsMono.zip
    else
        error "Failed to download JetBrainsMono Nerd Font from both sources"
        error "Please download manually from:"
        error "  $GITHUB_URL"
        error "  $SOURCEFORGE_URL"
        error "Place the file in ~/.local/share/fonts and extract it"
        popd > /dev/null
        exit 1
    fi
fi

popd > /dev/null
success "JetBrainsMono Nerd Font installed."

# Step 5: Refresh font cache
info "Refreshing font cache..."
if ! fc-cache -fv > /dev/null; then
    error "Failed to update font cache"
    error "Try running 'fc-cache -fv' manually"
    exit 1
fi
success "Font cache updated."

echo -e "\n${GREEN}${BOLD}✅ Setup complete!${RESET}"
echo -e "🔍 Test with:\n  fc-match 'Noto Sans Arabic'\n  fc-match 'JetBrainsMono Nerd Font Mono'\n"
