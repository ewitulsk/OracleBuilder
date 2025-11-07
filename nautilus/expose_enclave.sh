# Copyright (c), Mysten Labs, Inc.
# SPDX-License-Identifier: Apache-2.0
#!/bin/bash

# Check if port 3000 is in use and kill the process
if lsof -ti:3000 >/dev/null 2>&1; then
    echo "Killing process on port 3000..."
    kill -9 $(lsof -ti:3000) 2>/dev/null || true
fi

# Gets the enclave id and CID
# expects there to be only one enclave running
ENCLAVE_ID=$(nitro-cli describe-enclaves | jq -r ".[0].EnclaveID")
ENCLAVE_CID=$(nitro-cli describe-enclaves | jq -r ".[0].EnclaveCID")

# Validate enclave variables
if [ -z "$ENCLAVE_ID" ] || [ -z "$ENCLAVE_CID" ]; then
    echo "Error: Failed to get enclave information. ENCLAVE_ID or ENCLAVE_CID is null."
    exit 1
fi

sleep 5
# Secrets-block
SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id arn:aws:secretsmanager:us-east-1:502186568577:secret:weather-api-key-HFZ6nA --region us-east-1 | jq -r .SecretString)
echo "$SECRET_VALUE" | jq -R '{"API_KEY": .}' > secrets.jsoncat secrets.json | socat - VSOCK-CONNECT:$ENCLAVE_CID:7777
socat TCP4-LISTEN:3000,reuseaddr,fork VSOCK-CONNECT:$ENCLAVE_CID:3000 &

# Additional port configurations will be added here by configure_enclave.sh if needed
