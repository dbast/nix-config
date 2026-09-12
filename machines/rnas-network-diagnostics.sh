#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
export LC_ALL=C TZ=UTC
umask 077

root=${STATE_DIRECTORY:-/var/lib/rnas-network-diagnostics}
mkdir -p "$root"
# Also serialize direct invocations against the systemd service.
exec 9>"$root/.lock"
flock -n 9 || {
  printf 'A collection is already running\n' >&2
  exit 1
}
boot_id=$(cat /proc/sys/kernel/random/boot_id)
run=$(mktemp -d "$root/$(date -u +%Y%m%dT%H%M%SZ)_${boot_id}_XXXXXX")
printf 'Collecting into %s\n' "$run"
exec > >(tee "$run/collector.log") 2>&1
trap 'rc=$?; printf "%s\n" "$rc" > "$run/collector.exit"' EXIT
printf 'file\texit\n' >"$run/status.tsv"

# Unsupported features, absent interfaces and timeouts are evidence, not fatal.
# Raw output stays separate from command metadata for useful directory diffs.
capture() {
  local file=$1 rc=0
  shift
  {
    printf '%s ' "$file"
    printf '%q ' "$@"
    printf '\n'
  } >>"$run/commands.log"
  timeout --kill-after=2s 10s "$@" >"$run/$file" 2>"$run/$file.stderr" || rc=$?
  printf '%s\n' "$rc" >"$run/$file.exit"
  printf '%s\t%s\n' "$file" "$rc" >>"$run/status.tsv"
}

read_files() {
  local output=$1
  shift
  # shellcheck disable=SC2016 # Expanded by the child shell, not this shell.
  capture "$output" bash -c '
    for file do
      printf "\n### %s\n" "$file"
      cat "$file" || :
    done
  ' bash "$@"
}

snapshot() {
  local phase=$1 iface base
  mkdir -p "$run/$phase"
  capture "$phase/addresses.json" ip -j -d address show
  capture "$phase/links.txt" ip -s -s -d link show
  capture "$phase/routes-v4.json" ip -j -4 route show table all
  capture "$phase/routes-v6.txt" ip -6 route show table all
  capture "$phase/rules-v4.txt" ip -4 rule show
  capture "$phase/rules-v6.txt" ip -6 rule show
  capture "$phase/neighbours.txt" ip -s neighbour show
  capture "$phase/mdio-devices.txt" ls -l /sys/bus/mdio_bus/devices
  read_files "$phase/kernel-counters.txt" /proc/interrupts /proc/softirqs /proc/net/softnet_stat /proc/net/snmp /proc/net/netstat
  read_files "$phase/irq-affinity.txt" /proc/irq/*/{smp_affinity_list,effective_affinity_list}
  read_files "$phase/cpu-power.txt" \
    /sys/devices/system/cpu/{online,offline} \
    /sys/devices/system/cpu/cpufreq/policy*/{scaling_driver,scaling_governor,scaling_min_freq,scaling_max_freq,scaling_cur_freq,cpuinfo_cur_freq,stats/time_in_state} \
    /sys/class/thermal/thermal_zone*/{type,temp}
  read_files "$phase/platform-debug.txt" /sys/kernel/debug/{clk/clk_summary,regulator/regulator_summary,pm_genpd/pm_genpd_summary,gpio}
  for iface in end0 enu1; do
    base=/sys/class/net/$iface
    mkdir -p "$run/$phase/$iface"
    # modinfo shows availability; these links show the driver actually bound.
    capture "$phase/$iface/mac-driver-binding.txt" readlink -e "$base/device/driver"
    capture "$phase/$iface/phy-device.txt" readlink -e "$base/phydev"
    capture "$phase/$iface/phy-driver-binding.txt" readlink -e "$base/phydev/driver"
    capture "$phase/$iface/link.txt" ethtool "$iface"
    capture "$phase/$iface/statistics.txt" ethtool -S "$iface"
    capture "$phase/$iface/phy-statistics.txt" ethtool --phy-statistics "$iface"
    capture "$phase/$iface/registers.txt" ethtool -d "$iface"
    read_files "$phase/$iface/sysfs.txt" \
      "$base"/{address,operstate,carrier,carrier_changes,carrier_up_count,carrier_down_count,speed,duplex,flags,mtu,ifindex} \
      "$base"/statistics/* "$base"/device/power/* \
      "$base"/phydev/{phy_id,phy_interface,phy_has_fixups,uevent} "$base"/phydev/statistics/* \
      "$base"/phydev/power/*
    read_files "$phase/$iface/packet-steering.txt" \
      "$base"/queues/rx-*/{rps_cpus,rps_flow_cnt} "$base"/queues/tx-*/{xps_cpus,xps_rxqs}
    read_files "$phase/$iface/debugfs.txt" \
      /sys/kernel/debug/stmmaceth/"$iface"/{dma_cap,descriptors_status}
  done
}

{
  printf 'label=%s\nboot_id=%s\nstarted_utc=%s\n' "${LABEL:-unlabelled}" "$boot_id" "$(date -u --iso-8601=seconds)"
  printf 'settle_seconds=%s\nrequested_target_ipv4=%s\n' "${SETTLE_SECONDS:-120}" "${TARGET_IPV4:-}"
  printf 'collector=%s\n' "$0"
  uname -a
} >"$run/metadata.txt"
capture cmdline.txt cat /proc/cmdline
capture uptime-start.txt cat /proc/uptime
capture system-generation.txt readlink -f /run/current-system
capture booted-generation.txt readlink -f /run/booted-system
capture extlinux.conf cat /boot/extlinux/extlinux.conf
capture u-boot-version.txt bash -c 'tr -d "\000" < /proc/device-tree/chosen/u-boot,version'
capture os-release.txt cat /etc/os-release
capture dmesg-before.txt dmesg --color=never
capture kernel-journal-before.txt journalctl -b -k --no-pager -o short-monotonic

settle=${SETTLE_SECONDS:-120}
if [[ ! $settle =~ ^[0-9]{1,3}$ ]] || ((10#$settle > 300)); then
  printf 'SETTLE_SECONDS must be an integer from 0 to 300\n' >&2
  exit 1
fi
sleep "$settle"

capture device-tree.dts dtc -I fs -O dts /sys/firmware/devicetree/base
capture device-tree.dtb cat /sys/firmware/fdt
capture modules.txt lsmod
for module in stmmac stmmac_platform dwmac_rk motorcomm r8152; do
  capture "module-$module.txt" modinfo "$module"
  read_files "parameters-$module.txt" /sys/module/"$module"/parameters/*
done
capture usb.txt lsusb
capture usb-tree.txt lsusb -t
capture network-services.txt systemctl --no-pager --full status dhcpcd.service systemd-networkd.service systemd-udevd.service
capture network-config.txt networkctl --no-pager status --all
read_files network-config-files.txt /etc/dhcpcd.conf /etc/systemd/network/* /run/systemd/network/*
capture network-sysctls.txt sysctl -a -r '^net\.(ipv4\.(conf|neigh)|ipv6\.conf)\.'
capture nftables.txt nft list ruleset
capture iptables.txt iptables-save -c
capture ip6tables.txt ip6tables-save -c
capture irqbalance.txt systemctl --no-pager --full status irqbalance.service
for iface in end0 enu1; do
  mkdir -p "$run/$iface"
  capture "$iface/driver.txt" ethtool -i "$iface"
  capture "$iface/dhcp-lease.txt" dhcpcd --dumplease "$iface"
  capture "$iface/udev.txt" udevadm info --query=all --path="/sys/class/net/$iface"
  capture "$iface/parents.txt" udevadm info --attribute-walk --path="/sys/class/net/$iface"
  for option in --show-eee --show-pause --show-offload --show-ring --show-coalesce --show-channels --show-priv-flags; do
    capture "$iface/${option#--show-}.txt" ethtool "$option" "$iface"
  done
done
snapshot before

target=${TARGET_IPV4:-}
if [[ -z $target ]]; then
  # enu1 can supply the router address even when end0 has no DHCP lease/route.
  capture discovered-target.txt jq -r '[.[] | select(.dst == "default" and .gateway != null and (.dev == "end0" or .dev == "enu1"))] | sort_by(.metric // 0) | .[0].gateway // empty' "$run/before/routes-v4.json"
  target=$(cat "$run/discovered-target.txt")
fi
if [[ -n $target ]]; then
  if [[ ! $target =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    printf 'TARGET_IPV4 must be a numeric IPv4 address\n' >&2
    exit 1
  fi
  IFS=. read -r -a octets <<<"$target"
  for octet in "${octets[@]}"; do
    if ((10#$octet > 255)); then
      printf 'TARGET_IPV4 octet exceeds 255\n' >&2
      exit 1
    fi
  done
fi
printf 'selected_target_ipv4=%s\n' "$target" >>"$run/metadata.txt"

# Capture both NICs to expose replies arriving on the other same-subnet NIC.
# Bounded time, packet count and snaplen; -p avoids promiscuous mode.
timeout --kill-after=2s 70s tcpdump -i any -p -nn -U -s 128 -c 2000 \
  -w "$run/probes.pcap" 'arp or icmp or icmp6 or (udp and (port 67 or port 68))' \
  >"$run/tcpdump.log" 2>&1 &
capture_pid=$!
timeout --kill-after=2s 70s ip -ts monitor link address route neigh >"$run/link-events.txt" 2>&1 &
monitor_pid=$!
sleep 1
for iface in end0 enu1; do
  if [[ -z $target ]]; then
    printf 'SKIPPED: no IPv4 router found; set TARGET_IPV4\n' >"$run/$iface/probes-skipped.txt"
    continue
  fi
  capture "$iface/route-to-target.txt" ip -4 route get "$target" oif "$iface"
  capture "$iface/arping.txt" arping -I "$iface" -c 3 -w 5 "$target"
  capture "$iface/ping.txt" ping -4 -n -I "$iface" -c 4 -W 1 -w 6 "$target"
done
wait "$capture_pid" && capture_rc=0 || capture_rc=$?
wait "$monitor_pid" && monitor_rc=0 || monitor_rc=$?
printf '%s\n' "$capture_rc" >"$run/probes.pcap.exit"
printf '%s\n' "$monitor_rc" >"$run/link-events.txt.exit"
printf 'probes.pcap\t%s\nlink-events.txt\t%s\n' "$capture_rc" "$monitor_rc" >>"$run/status.tsv"
capture packets.txt tcpdump -nn -e -tttt -r "$run/probes.pcap"
snapshot after
capture dmesg-after.txt dmesg --color=never
capture kernel-journal-after.txt journalctl -b -k --no-pager -o short-monotonic
capture network-journal.txt journalctl -b --no-pager -o short-monotonic \
  -u dhcpcd -u 'dhcpcd@*' -u systemd-networkd -u systemd-udevd -u network-setup -u firewall
capture uptime-end.txt cat /proc/uptime
date -u --iso-8601=seconds >"$run/COMPLETE"
printf 'Collection complete: %s\n' "$run"
