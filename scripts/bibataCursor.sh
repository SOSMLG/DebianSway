#!/usr/bin/env bash
set -euo pipefail

# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"

# Check dependencies
for cmd in curl tar; do
  if ! command -v "$cmd" &> /dev/null; then
    echo -e "${RED}✗ Missing dependency: $cmd${RESET}"
    echo "Install with: sudo apt install curl tar"
    exit 1
  fi
done

CURSOR_DIR="$HOME/.local/share/icons"
mkdir -p "$CURSOR_DIR"

# Available styles and colors
STYLES=("Modern" "Original")
COLORS=("Amber" "Classic" "Ice")

echo -e "${BLUE}🖱️  Bibata Cursor Theme Installer${RESET}"
echo "================================="
echo

# Step 1: Choose style
echo "Choose a style:"
for i in "${!STYLES[@]}"; do
  printf "%2d) %s\n" $((i+1)) "${STYLES[$i]}"
done
printf "%2d) Install ALL themes\n" $((${#STYLES[@]}+1))
ALL_OPTION=$((${#STYLES[@]}+1))

read -rp "Style number: " SN

if [[ "$SN" == "$ALL_OPTION" ]]; then
  echo -e "${GREEN}🎯 Installing ALL Bibata cursor themes...${RESET}"
  echo
  
  # Download all combinations
  declare -a ALL_THEMES=(
    "Bibata-Modern-Amber"
    "Bibata-Modern-Classic" 
    "Bibata-Modern-Ice"
    "Bibata-Original-Amber"
    "Bibata-Original-Classic"
    "Bibata-Original-Ice"
  )
  
  success_count=0
  for theme in "${ALL_THEMES[@]}"; do
    echo -e "${CYAN}📥 Downloading $theme...${RESET}"
    
    TEMP_DIR="/tmp/bibata-${theme}-$$"
    mkdir -p "$TEMP_DIR"
    
    # Try to download from GitHub releases
    URL="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/${theme}.tar.xz"
    
    if curl -L -o "$TEMP_DIR/${theme}.tar.xz" "$URL" --progress-bar --fail; then
      echo -e "${CYAN}📦 Extracting $theme...${RESET}"
      cd "$TEMP_DIR"
      
      if tar -xf "${theme}.tar.xz"; then
        # Find extracted directory
        EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "*Bibata*" | head -1)
        
        if [[ -n "$EXTRACTED_DIR" ]]; then
          DEST_DIR="$CURSOR_DIR/$theme"
          
          if [[ -d "$DEST_DIR" ]]; then
            rm -rf "$DEST_DIR"
          fi
          
          mv "$EXTRACTED_DIR" "$DEST_DIR"
          echo -e "${GREEN}✅ Installed: $theme${RESET}"
          ((success_count++))
        else
          echo -e "${RED}✗ Could not find extracted directory for $theme${RESET}"
        fi
      else
        echo -e "${RED}✗ Failed to extract $theme${RESET}"
      fi
    else
      echo -e "${RED}✗ Failed to download $theme${RESET}"
    fi
    
    rm -rf "$TEMP_DIR"
    echo
  done
  
  echo -e "${GREEN}🎉 Installation complete!${RESET}"
  echo "   Successfully installed: $success_count/${#ALL_THEMES[@]} themes"
  
else
  # Single theme selection
  if [[ "$SN" -lt 1 ]] || [[ "$SN" -gt ${#STYLES[@]} ]]; then
    echo -e "${RED}✗ Invalid style selection${RESET}"
    exit 1
  fi
  
  STYLE="${STYLES[$((SN-1))]}"
  echo
  
  # Step 2: Choose color
  echo "Choose a color:"
  for i in "${!COLORS[@]}"; do
    printf "%2d) %s\n" $((i+1)) "${COLORS[$i]}"
  done
  read -rp "Color number: " CN
  
  if [[ "$CN" -lt 1 ]] || [[ "$CN" -gt ${#COLORS[@]} ]]; then
    echo -e "${RED}✗ Invalid color selection${RESET}"
    exit 1
  fi
  
  COLOR="${COLORS[$((CN-1))]}"
  echo
  
  # Step 3: Download and install
  THEME_NAME="Bibata-${STYLE}-${COLOR}"
  echo -e "${CYAN}📥 Downloading $THEME_NAME...${RESET}"
  
  TEMP_DIR="/tmp/bibata-${THEME_NAME}-$$"
  mkdir -p "$TEMP_DIR"
  
  # Download from GitHub releases
  URL="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/${THEME_NAME}.tar.xz"
  
  if ! curl -L -o "$TEMP_DIR/${THEME_NAME}.tar.xz" "$URL" --progress-bar --fail; then
    echo -e "${RED}✗ Failed to download $THEME_NAME${RESET}"
    echo "   URL: $URL"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
  
  echo -e "${CYAN}📦 Extracting $THEME_NAME...${RESET}"
  cd "$TEMP_DIR"
  
  if ! tar -xf "${THEME_NAME}.tar.xz"; then
    echo -e "${RED}✗ Failed to extract $THEME_NAME${RESET}"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
  
  # Find extracted directory
  EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "*Bibata*" | head -1)
  
  if [[ -z "$EXTRACTED_DIR" ]]; then
    echo -e "${RED}✗ Could not find extracted theme directory${RESET}"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
  
  # Install theme
  DEST_DIR="$CURSOR_DIR/$THEME_NAME"
  
  if [[ -d "$DEST_DIR" ]]; then
    echo -e "${YELLOW}⚠️  Overwriting existing theme: $THEME_NAME${RESET}"
    rm -rf "$DEST_DIR"
  fi
  
  mv "$EXTRACTED_DIR" "$DEST_DIR"
  
  echo -e "${GREEN}✅ Done! Theme '$THEME_NAME' installed to:${RESET}"
  echo "   $DEST_DIR"
  
  # Cleanup
  rm -rf "$TEMP_DIR"
fi

echo
echo -e "${CYAN}🔧 Next steps:${RESET}"
echo "1. Open your system settings"
echo "2. Go to Mouse & Touchpad (or Appearance) settings" 
echo "3. Select your new Bibata cursor theme"
echo "4. Log out and back in if the cursors don't change immediately"
echo
echo -e "${CYAN}🎨 Cursor themes are installed in:${RESET}"
echo "   $CURSOR_DIR"
