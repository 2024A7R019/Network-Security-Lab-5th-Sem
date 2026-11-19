# EXPERIMENT 9: SET UP AN IPsec VPN IN TUNNEL MODE USING STRONGSWAN
#
# This file contains the commands used to configure, establish,
# and verify an IKEv2 IPsec VPN tunnel between two Kali Linux gateways.
#
# Gateway A:
# Outer IP: 192.168.229.128
# Inner IP: 10.10.1.1/32
# Identity: gw-a
#
# Gateway B:
# Outer IP: 192.168.229.129
# Inner IP: 10.20.1.1/32
# Identity: gw-b
#
# IMPORTANT:
# Run Gateway A commands on Gateway A and Gateway B commands on Gateway B.
# Replace placeholders with the actual lab values where required.
# Never store or publish the actual Pre-Shared Key (PSK).


# ============================================================
# 1. NETWORK CONFIGURATION AND CONNECTIVITY
# ============================================================

# Display network interfaces and assigned IP addresses on both gateways.
ip -br address

# Gateway A: Verify connectivity with Gateway B.
ping -c 3 192.168.229.129

# Gateway B: Verify connectivity with Gateway A.
ping -c 3 192.168.229.128

# Check the route used to reach the other gateway.
# Gateway A:
ip route get 192.168.229.129

# Gateway B:
ip route get 192.168.229.128


# ============================================================
# 2. INSTALL AND START STRONGSWAN
# ============================================================

# Run the following commands on both gateways.

# Update the package repository information.
sudo apt update

# Install the modern strongSwan service, swanctl utility,
# and tcpdump packet capture utility.
sudo apt install charon-systemd strongswan-swanctl tcpdump

# Enable and start the strongSwan service.
sudo systemctl enable --now strongswan

# Check whether the strongSwan service is running.
sudo systemctl status strongswan --no-pager

# Display the installed swanctl version.
sudo swanctl --version

# Verify communication with the strongSwan daemon.
sudo swanctl --version --daemon


# ============================================================
# 3. ASSIGN INNER TUNNEL IP ADDRESSES
# ============================================================

# Gateway A: Assign the inner tunnel address to the loopback interface.
sudo ip address add 10.10.1.1/32 dev lo

# Gateway B: Assign the inner tunnel address to the loopback interface.
sudo ip address add 10.20.1.1/32 dev lo

# Verify the assigned loopback addresses.
ip -br address show dev lo


# ============================================================
# 4. INSPECT FIREWALL CONFIGURATION
# ============================================================

# Run on both gateways before changing firewall rules.

# Check the UFW firewall status.
sudo ufw status

# Display the existing nftables ruleset.
sudo nft list ruleset

# IPsec requires UDP port 500 for IKE,
# UDP port 4500 for NAT traversal when applicable,
# and IP protocol 50 for native ESP traffic.
# Inspect existing rules before making any changes.


# ============================================================
# 5. GENERATE A RANDOM PRE-SHARED KEY
# ============================================================

# Generate a strong random Base64-encoded PSK on one gateway.
openssl rand -base64 33

# Use the same generated PSK on both gateways.
# Add the 0s prefix before the Base64 value in swanctl.conf.
# Do not write the actual PSK in this file or upload it to GitHub.


# ============================================================
# 6. CONFIGURE THE IPsec CONNECTION
# ============================================================

# Open the strongSwan configuration file on both gateways.
sudo nano /etc/swanctl/swanctl.conf

# GATEWAY A CONFIGURATION:
#
# connections {
#   lab-vpn {
#     version = 2
#     local_addrs = 192.168.229.128
#     remote_addrs = 192.168.229.129
#     proposals = aes256gcm16-prfsha256-modp3072
#     local {
#       auth = psk
#       id = gw-a
#     }
#     remote {
#       auth = psk
#       id = gw-b
#     }
#     children {
#       lab-net {
#         local_ts = 10.10.1.1/32
#         remote_ts = 10.20.1.1/32
#         esp_proposals = aes256gcm16
#       }
#     }
#   }
# }
# secrets {
#   ike-lab {
#     secret = 0sREPLACE_WITH_GENERATED_PSK
#   }
# }
#
# GATEWAY B CONFIGURATION:
#
# connections {
#   lab-vpn {
#     version = 2
#     local_addrs = 192.168.229.129
#     remote_addrs = 192.168.229.128
#     proposals = aes256gcm16-prfsha256-modp3072
#     local {
#       auth = psk
#       id = gw-b
#     }
#     remote {
#       auth = psk
#       id = gw-a
#     }
#     children {
#       lab-net {
#         local_ts = 10.20.1.1/32
#         remote_ts = 10.10.1.1/32
#         esp_proposals = aes256gcm16
#       }
#     }
#   }
# }
# secrets {
#   ike-lab {
#     secret = 0sREPLACE_WITH_GENERATED_PSK
#   }
# }
#
# NOTE:
# Both gateways must use the same PSK, connection name,
# CHILD SA name, and cryptographic proposals.
# Local and remote addresses, identities, and traffic selectors
# must be reversed between the two gateways.


# ============================================================
# 7. LOAD AND VERIFY THE VPN CONFIGURATION
# ============================================================

# Run on both gateways.

# Restrict access to the configuration file.
sudo chmod 600 /etc/swanctl/swanctl.conf

# Load the configured connections and authentication credentials.
sudo swanctl --load-all

# Display the loaded IPsec connections.
sudo swanctl --list-conns


# ============================================================
# 8. ESTABLISH THE IPsec VPN TUNNEL
# ============================================================

# Gateway A: Initiate the CHILD SA to establish the VPN tunnel.
sudo swanctl --initiate --child lab-net

# Gateway B: Optionally monitor the strongSwan service logs.
sudo journalctl -u strongswan -f

# Check the established IKE SA and CHILD SA on both gateways.
sudo swanctl --list-sas


# ============================================================
# 9. VERIFY IPsec XFRM STATES AND POLICIES
# ============================================================

# Display installed IPsec security states.
sudo ip xfrm state

# Display the installed IPsec security policies.
sudo ip xfrm policy


# ============================================================
# 10. TEST PROTECTED COMMUNICATION
# ============================================================

# Gateway A: Send four ping requests through the IPsec tunnel.
ping -I 10.10.1.1 -c 4 10.20.1.1

# Gateway B: Send four ping requests in the reverse direction.
ping -I 10.20.1.1 -c 4 10.10.1.1

# Check the IPsec Security Association counters after communication.
sudo swanctl --list-sas


# ============================================================
# 11. OPTIONAL PACKET CAPTURE AND ANALYSIS
# ============================================================

# Identify the outer network interface on the gateway.
ip -br address

# Replace <OUTER_IF> with the actual outer network interface name.
# Start packet capture on the outer interface.
sudo tcpdump -ni <OUTER_IF> -w exp9-ipsec.pcap 'udp port 500 or udp port 4500 or proto 50 or proto 51'

# Stop the capture using Ctrl+C.
# Open exp9-ipsec.pcap in Wireshark.
#
# Wireshark display filter:
# isakmp || esp || ah
#
# UDP 500: IKEv2 negotiation.
# UDP 4500: NAT traversal traffic, when applicable.
# ESP (IP protocol 50): Encrypted IPsec traffic.
# AH (IP protocol 51): Not expected in this ESP-based experiment.


# ============================================================
# 12. CLEANUP AND RESTORE LAB CONFIGURATION
# ============================================================

# Terminate the established CHILD SA.
sudo swanctl --terminate --child lab-net

# Gateway A: Remove the temporary inner tunnel address.
sudo ip address del 10.10.1.1/32 dev lo

# Gateway B: Remove the temporary inner tunnel address.
sudo ip address del 10.20.1.1/32 dev lo

# Remove or securely store any temporary configuration
# and credential files according to the lab requirements.
