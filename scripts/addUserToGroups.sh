set -euo pipefail

# Get actual user even when run with sudo
ACTUAL_USER="${SUDO_USER:-$USER}"

echo "Adding $ACTUAL_USER to input group..."
sudo usermod -aG input "$ACTUAL_USER"
echo "✓ User $ACTUAL_USER added to input group"
echo "⚠ You may need to log out and back in for changes to take effect"
```
