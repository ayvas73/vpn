#!/bin/bash

IP='1.1.1.1'
USERNAME='ayvas'
PASSWORD='123'

sudo apt update
sudo apt install strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins

mkdir -p ~/pki/{cacerts,certs,private}
chmod 700 ~/pki
pki --gen --type rsa --size 4096 --outform pem > ~/pki/private/ca-key.pem
pki --self --ca --lifetime 3650 --in ~/pki/private/ca-key.pem \
    --type rsa --dn "CN=VPN Frankfurt" --outform pem > ~/pki/cacerts/ca-cert.pem

pki --gen --type rsa --size 4096 --outform pem > ~/pki/private/server-key.pem
pki --pub --in ~/pki/private/server-key.pem --type rsa \
    | pki --issue --lifetime 1825 \
        --cacert ~/pki/cacerts/ca-cert.pem \
        --cakey ~/pki/private/ca-key.pem \
        --dn "CN=$IP" --san @$IP --san $IP \
        --flag serverAuth --flag ikeIntermediate --outform pem \
    >  ~/pki/certs/server-cert.pem

sudo cp -r ~/pki/* /etc/ipsec.d/

sudo mv /etc/ipsec.conf{,.original}


cat << EOF > /etc/ipsec.conf
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=$IP
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.10.0/24
    rightdns=8.8.8.8,8.8.4.4
    rightsendcert=never
    eap_identity=%identity
    ike=chacha20poly1305-sha512-curve25519-prfsha512,aes256gcm16-sha384-prfsha384-ecp384,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024!
    esp=chacha20poly1305-sha512,aes256gcm16-ecp384,aes256-sha256,aes256-sha1,3des-sha1!
EOF

echo ": RSA \"server-key.pem\"" >> /etc/ipsec.secrets
echo "$USERNAME : EAP \"$PASSWORD\"" >> /etc/ipsec.secrets
sudo systemctl restart strongswan-starter