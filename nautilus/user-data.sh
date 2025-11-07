#!/bin/bash
# Update the instance and install Nitro Enclaves tools, Docker and other utilities
sudo yum update -y
sudo yum install -y aws-nitro-enclaves-cli-devel aws-nitro-enclaves-cli docker nano socat git make

# Add the current user to the docker group (so you can run docker without sudo)
sudo usermod -aG docker ec2-user

# Start and enable Nitro Enclaves allocator and Docker services
sudo systemctl start nitro-enclaves-allocator.service && sudo systemctl enable nitro-enclaves-allocator.service
sudo systemctl start docker && sudo systemctl enable docker
sudo systemctl enable nitro-enclaves-vsock-proxy.service

# Install Squid proxy for unrestricted internet access
sudo yum install -y squid

# Configure Squid to allow all traffic from localhost
sudo tee /etc/squid/squid.conf > /dev/null <<'SQUID_EOF'
# Allow localhost connections
acl localnet src 127.0.0.0/8

# Allow CONNECT for HTTPS
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl CONNECT method CONNECT

# Deny CONNECT to non-SSL ports
http_access deny CONNECT !SSL_ports

# Allow localhost
http_access allow localnet
http_access allow localhost

# Deny all other access
http_access deny all

# Squid listening port
http_port 3128

# Leave coredumps in the first cache dir
coredump_dir /var/spool/squid
SQUID_EOF

# Start and enable Squid
sudo systemctl start squid && sudo systemctl enable squid

# Stop the allocator so we can modify its configuration
sudo systemctl stop nitro-enclaves-allocator.service

# Adjust the enclave allocator memory (default set to 3072 MiB)
ALLOCATOR_YAML=/etc/nitro_enclaves/allocator.yaml
MEM_KEY=memory_mib
DEFAULT_MEM=3072
sudo sed -r "s/^(\s*${MEM_KEY}\s*:\s*).*/\1${DEFAULT_MEM}/" -i "${ALLOCATOR_YAML}"

# Restart the allocator with the updated memory configuration
sudo systemctl start nitro-enclaves-allocator.service && sudo systemctl enable nitro-enclaves-allocator.service

# Start single vsock-proxy to forward traffic to Squid proxy
vsock-proxy 8100 127.0.0.1 3128 --config /etc/nitro_enclaves/vsock-proxy.yaml &
