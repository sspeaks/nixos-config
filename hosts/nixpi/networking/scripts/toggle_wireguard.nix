{pkgs, ...}:
pkgs.writeShellScriptBin "toggle_wireguard" ''
# Define the file path
FILE="/home/sspeaks/osConfig/hosts/nixpi/networking/networkd.nix"

# Check if the file exists
if [[ ! -f "$FILE" ]]; then
    echo "File not found: $FILE"
    exit 1
fi

# Use sed to toggle the enableWireguard line
if grep -q "enableWireguard = true;" "$FILE"; then
    sed -i 's/enableWireguard = true;/enableWireguard = false;/g' "$FILE"
    echo "Toggled enableWireguard to false."
elif grep -q "enableWireguard = false;" "$FILE"; then
    sed -i 's/enableWireguard = false;/enableWireguard = true;/g' "$FILE"
    echo "Toggled enableWireguard to true."
else
    echo "No enableWireguard setting found in the file."
    exit 1
fi
exit 0
''
