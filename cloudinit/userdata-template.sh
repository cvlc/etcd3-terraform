#!/usr/bin/env bash

## Install ETCD
useradd -U -M -s /dev/null etcd

mkdir -p /etc/ssl/etcd; chown -R etcd:etcd /etc/ssl/etcd; chmod -R 700 /etc/ssl/etcd
curl -L -o /tmp/etcd-v${etcd_version}-linux-amd64.tar.gz https://github.com/etcd-io/etcd/releases/download/v${etcd_version}/etcd-v${etcd_version}-linux-amd64.tar.gz

tar xvf /tmp/etcd-v${etcd_version}-linux-amd64.tar.gz -C /tmp

mv /tmp/etcd-v${etcd_version}-linux-amd64/{etcd,etcdctl,etcdutl} /usr/local/bin

mkdir -p /var/lib/etcd/
mkdir -p /etc/etcd

## Create systemd units
cat << EOT > /etc/systemd/system/etcd-bootstrap.service
${etcd_bootstrap_unit} 
EOT

cat << EOT > /etc/systemd/system/etcd-member.service
${etcd_member_unit}
EOT

## Create certificate files
cat << EOT > /etc/ssl/etcd/ca.pem
${ca_file}
EOT

cat << EOT > /etc/ssl/etcd/server.pem
${server_cert_file}
EOT

cat << EOT > /etc/ssl/etcd/server-key.pem
${server_key_file}
EOT

cat << EOT > /etc/ssl/etcd/peer.pem
${peer_cert_file}
EOT

cat << EOT > /etc/ssl/etcd/peer-key.pem
${peer_key_file}
EOT

## Obtain local IPv4 address and replace placeholders in systemd etcd unit file
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
local_ipv4=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-ipv4)
sed -e "s/~private_ipv4/$local_ipv4/g" -i /etc/systemd/system/etcd-member.service

## Create a cronjob to defrag etcd data, but be careful to spread out the time across all nodes to maintain service availability
cat <<EOT> /etc/cron.d/defrag-etcd
5 3 ${maintenance_day_of_the_month} * * admin /usr/bin/sudo -u etcd ETCDCTL_API=3 ETCDCTL_CERT=/etc/ssl/etcd/server.pem ETCDCTL_KEY=/etc/ssl/etcd/server-key.pem ETCDCTL_ENDPOINTS="https://$local_ipv4:2379" etcdctl defrag
EOT

## Install CA certificate
mkdir -p /usr/local/share/ca-certificates
cp /etc/ssl/etcd/ca.pem /usr/local/share/ca-certificates/my-ca.crt
chmod 755 /usr/local/share/ca-certificates/my-ca.crt
update-ca-certificates

## Enable and start services
systemctl enable etcd-bootstrap.service
systemctl enable etcd-member.service

systemctl start etcd-bootstrap.service
systemctl start etcd-member.service
