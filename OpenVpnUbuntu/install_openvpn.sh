#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Step 1: Update and Upgrade Packages
echo "Updating and upgrading packages..."
apt update -y
apt upgrade -y

# Step 2: Install OpenVPN and easy-rsa
echo "Installing OpenVPN and easy-rsa..."
apt install openvpn easy-rsa -y

# Step 3: Set Up Certificate Authority
echo "Setting up Certificate Authority..."
make-cadir ~/openvpn-ca
cd ~/openvpn-ca

# Source the vars file and clear any previous keys
source vars
./clean-all

# Build the CA
echo "Building the CA..."
./build-ca

# Step 4: Generate Server Certificate and Key
echo "Generating Server Certificate and Key..."
./build-key-server server

# Step 5: Generate Diffie-Hellman Parameters
echo "Generating Diffie-Hellman Parameters..."
./build-dh

# Step 6: Configure OpenVPN
echo "Configuring OpenVPN..."
cd ~/openvpn-ca/keys
cp ca.crt ca.key server.crt server.key dh2048.pem /etc/openvpn

# Create server.conf file
cat <<EOL > /etc/openvpn/server.conf
port 1194
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh2048.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
log-append  /var/log/openvpn.log
verb 3
EOL

# Step 7: Enable IP Forwarding
echo "Enabling IP Forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Step 8: Update UFW Firewall
echo "Updating UFW Firewall..."
ufw allow 1194/tcp
ufw allow OpenSSH

# Step 9: Start OpenVPN
echo "Starting OpenVPN..."
systemctl start openvpn@server
systemctl enable openvpn@server

echo "OpenVPN setup completed!"
