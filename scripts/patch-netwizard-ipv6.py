#!/usr/bin/env python3
"""Keep netwizard's side-router IPv6 on one bridge without odhcpd relay loops."""
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = """            if [ "x$ipv6" = "x1" ]; then
                $UCISET network.lan6=interface
                $UCISET network.lan6.proto='dhcpv6'
                $UCISET network.lan6.delegate='1'
                $UCISET network.lan6.$ifname="@lan"
                setipv6 2
                $UCIADDLIST firewall.@zone[0].network='lan6'
            else
                setipv6 0
            fi"""
new = """            # All side-router ports and APs share the LAN bridge. Upstream
            # Router Advertisements cross that bridge directly; odhcpd relay
            # needs two distinct routed interfaces and must not run here.
            if [ "x$ipv6" = "x1" ]; then
                $UCISET network.lan6=interface
                $UCISET network.lan6.proto='dhcpv6'
                $UCISET network.lan6.$ifname='@lan'
                $UCISET network.lan6.reqprefix='no'
                $UCIADDLIST firewall.@zone[0].network='lan6'
            fi"""
if source.count(old) != 1:
    raise SystemExit("netwizard side-router IPv6 block changed; inspect upstream")
source = source.replace(old, new)
old = """    if [ -n "${wifi_ssid}" ] && [ -n "${wifi_key}" ]; then"""
new = """    if [ "$wan_proto" = "siderouter" ]; then
        # Leave upstream RA and DHCPv6 on the shared bridge untouched.
        # No local RA/DHCPv6/NDP service or delegated prefix is needed.
        $UCISET dhcp.lan.ra='disabled'
        $UCISET dhcp.lan.dhcpv6='disabled'
        $UCISET dhcp.lan.ndp='disabled'
        $UCIDEL dhcp.lan.master
        $UCIDEL dhcp.lan.ra_slaac
        $UCIDEL network.lan.ip6assign
        $UCIDEL dhcp.lan6
    fi

    if [ -n "${wifi_ssid}" ] && [ -n "${wifi_key}" ]; then"""
if source.count(old) != 1:
    raise SystemExit("netwizard wireless block changed; inspect upstream")
source = source.replace(old, new)
path.write_text(source)
print(f"Patched side-router IPv6 handling: {path}")
