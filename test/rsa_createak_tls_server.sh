#!/bin/bash
set -eufx

function cleanup()
{
    kill -term $SERVER
    wait $SERVER 2>/dev/null

    # release persistent handle
    tpm2_evictcontrol --object-context=${HANDLE}

    rm ek_rsa.ctx ak_rsa.ctx testcert.conf testcert.pem
}

# create EK
tpm2_createek -G rsa -c ek_rsa.ctx

# create AK with defined scheme/hash
tpm2_createak -C ek_rsa.ctx -G rsa -g sha256 -s rsapss -c ak_rsa.ctx

# load the AK to persistent handle
HANDLE=$(tpm2_evictcontrol --object-context=ak_rsa.ctx | cut -d ' ' -f 2 | head -n 1)

cat > testcert.conf << EOF
[ req ]
default_bits        = 2048
encrypt_key         = no
prompt              = no

distinguished_name  = cert_dn
x509_extensions     = cert_ext

[ cert_dn ]
countryName         = GB
commonName          = Common Name

[ cert_ext ]
basicConstraints    = critical, CA:FALSE
subjectAltName      = @alt_names

[ alt_names ]
DNS.1               = localhost
EOF

# create a private key and then generate a self-signed certificate for it
openssl req -provider tpm2 -x509 -config testcert.conf -key handle:${HANDLE} -out testcert.pem

# start SSL server
openssl s_server -provider tpm2 -provider default -propquery ?provider=tpm2,tpm2.digest!=yes \
                 -accept 4443 -www -key handle:${HANDLE} -cert testcert.pem &
SERVER=$!
trap "cleanup" EXIT
sleep 1

# start SSL client
curl --cacert testcert.pem https://localhost:4443/
