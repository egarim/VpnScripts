#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Check if curl is installed, and install it if it's not
if ! command -v curl &> /dev/null; then
    echo "curl is not installed. Installing now..."
    apt update
    apt install curl -y
fi

# Fetch the current public IP address
CURRENT_IP=$(curl -s ifconfig.me)

# Check if client name is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <CLIENT_NAME>"
    exit 1
fi

CLIENT_NAME=$1

# Prompt for server IP
read -rp "Enter the VPN server IP [$CURRENT_IP]: " SERVER_IP
SERVER_IP=${SERVER_IP:-$CURRENT_IP}

# Navigate to the CA directory
cd ~/openvpn-ca || { echo "Could not navigate to CA directory. Exiting."; exit 1; }

# Source the vars file if it exists
if [ ! -f "vars" ]; then
    echo "vars file not found in CA directory. Exiting."
    exit 1
fi

source vars

# Generate the client certificate and key
echo "Generating client certificate and key..."
./build-key $CLIENT_NAME

# Create a client configuration directory if it doesn't exist
mkdir -p ~/client-configs/files

# Create the .ovpn file
cat <<EOL > ~/client-configs/files/${CLIENT_NAME}.ovpn
client
dev tun
proto tcp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-CBC
key-direction 1
remote-cert-tls server
auth-nocache
verb 3

<ca>
$(cat ~/openvpn-ca/keys/ca.crt)
</ca>

<cert>
$(sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' ~/openvpn-ca/keys/${CLIENT_NAME}.crt)
</cert>

<key>
$(cat ~/openvpn-ca/keys/${CLIENT_NAME}.key)
</key>
EOL

echo "Client configuration has been written to ~/client-configs/files/${CLIENT_NAME}.ovpn"
echo "Copy this .ovpn file to your client device to use it with an OpenVPN client application."
