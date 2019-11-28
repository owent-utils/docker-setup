#!/bin/bash

# IP http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest

cat delegated-apnic-latest | awk 'BEGIN{FS="|"}{if($2 == "CN" && $3 != "asn"){print $3 " " $4 " " $5}}'
# ipv4 <start> <count> => ipv4 58.42.0.0 65536
# ipv6 <prefix> <bits> => ipv6 2407:c380:: 32

curl -L -o generate_dnsmasq_chinalist.sh https://github.com/cokebar/openwrt-scripts/raw/master/generate_dnsmasq_chinalist.sh
chmod +x generate_dnsmasq_chinalist.sh
sh generate_dnsmasq_chinalist.sh -d 114.114.114.114 -p 53 -s ss_spec_dst_bp -o /etc/dnsmasq.d/accelerated-domains.china.conf



## proxy
### Setup - kernel
modprobe nf_tproxy_ipv4
modprobe nf_tproxy_ipv6
modprobe nf_socket_ipv4
modprobe nf_socket_ipv6
modprobe nft_tproxy         # require kernel 4.19 or upper, see https://wiki.nftables.org/wiki-nftables/index.php/Supported_features_compared_to_xtables#TPROXY
echo "
nf_tproxy_ipv4
nf_tproxy_ipv6
nf_socket_ipv4
nf_socket_ipv6
nft_tproxy
" > /etc/modules-load.d/tproxy

nft add table mangle

### See https://toutyrater.github.io/app/tproxy.html

### Setup - ipv4
#### just like iptables -t mangle -N v2ray && iptables -t mangle -A PREROUTING -j v2ray
nft add chain mangle v2ray { type filter hook prerouting priority 1 \; }

### ipv4 - skip private network
nft add rule mangle v2ray ip daddr 127.0.0.1/32 return
nft add rule mangle v2ray ip daddr 224.0.0.0/4 return
nft add rule mangle v2ray ip daddr 255.255.255.255/32 return
nft add rule mangle v2ray meta l4proto tcp ip daddr 172.18.0.0/16 return
nft add rule mangle v2ray ip daddr 172.18.0.0/16 udp dport != 53 return

### ipv4 - forward to v2ray's listen address if not marked by v2ray
nft add rule mangle v2ray meta mark 255 return # make sure v2ray's outbounds.*.streamSettings.sockopt.mark = 255
nft add rule mangle v2ray meta l4proto tcp tproxy to :$V2RAY_PORT meta mark set 1 accept # -j TPROXY --on-port $V2RAY_PORT  # mark tcp package with 1 and forward to $V2RAY_PORT
nft add rule mangle v2ray meta l4proto udp tproxy to :$V2RAY_PORT meta mark set 1 accept # -j TPROXY --on-port $V2RAY_PORT  # mark udp package with 1 and forward to $V2RAY_PORT

## Setup - ipv6
nft add chain ip6 mangle v2ray { type filter hook prerouting priority 1 \; }