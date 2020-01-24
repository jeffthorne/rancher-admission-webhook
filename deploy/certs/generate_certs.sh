SERVICE_FQDN=$1
if [ -z "$SERVICE_FQDN" ]; then
    echo "ERROR: First parameter must be service FQDN"
    exit 1
fi

openssl genrsa -out /certs/ca.key 2048
openssl req -x509 -new -nodes -key /certs/ca.key -days 100000 -out /certs/ca.crt -subj "/CN=admission_ca"
cat >/certs/server.conf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
EOF
openssl genrsa -out /certs/server.key 2048
openssl req -new -key /certs/server.key -out /certs/server.csr -subj "/CN=$SERVICE_FQDN" -config /certs/server.conf
openssl x509 -req -in /certs/server.csr -CA /certs/ca.crt -CAkey /certs/ca.key -CAcreateserial -out /certs/server.crt -days 100000 -extensions v3_req -extfile /certs/server.conf

# make the keys mode 644 so the build script can read it as a non-root user
chmod 644 /certs/server.key /certs/ca.key
