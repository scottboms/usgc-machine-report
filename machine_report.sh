#!/bin/bash
# TR-100 Machine Report
# Copyright © 2024, U.S. Graphics, LLC. BSD-3-Clause License.
# Modified in 2026 by Scott Boms for mac OS 27

# Global variables
MIN_NAME_LEN=5
MAX_NAME_LEN=13

MIN_DATA_LEN=20
MAX_DATA_LEN=32

BORDERS_AND_PADDING=7

# Basic configuration, change as needed
report_title="Scott Boms MacBook Pro"
last_login_ip_present=0
zfs_present=0
zfs_filesystem="zroot/ROOT/os"

# Utilities
max_length() {
    local max_len=0
    local len

    for str in "$@"; do
        len=${#str}
        if (( len > max_len )); then
            max_len=$len
        fi
    done

    if [ $max_len -lt $MAX_DATA_LEN ]; then
        printf '%s' "$max_len"
    else
        printf '%s' "$MAX_DATA_LEN"
    fi
}

# All data strings must go here
set_current_len() {
    CURRENT_LEN=$(max_length                                     \
        "$report_title"                                          \
        "$os_name"                                               \
        "$os_kernel"                                             \
        "$net_hostname"                                          \
        "$net_machine_ip"                                        \
        "$net_client_ip"                                         \
        "$net_current_user"                                      \
        "$cpu_model"                                             \
        "$cpu_core_summary"                                     \
        "$cpu_hypervisor"                                        \
        "$cpu_freq${cpu_freq_unit:+ $cpu_freq_unit}"             \
        "$cpu_1min_bar_graph"                                    \
        "$cpu_5min_bar_graph"                                    \
        "$cpu_15min_bar_graph"                                   \
        "$zfs_used_gb/$zfs_available_gb GB [$disk_percent%]"     \
        "$disk_bar_graph"                                        \
        "$zfs_health"                                            \
        "$root_used_gb/$root_total_gb GB [$disk_percent%]"       \
        "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]"   \
        "${mem_bar_graph}"                                       \
        "$last_login_time"                                       \
        "$last_login_ip"                                         \
        "$last_login_ip"                                         \
        "$sys_uptime"                                            \
    )
}

PRINT_HEADER() {
    local length=$((CURRENT_LEN+MAX_NAME_LEN+BORDERS_AND_PADDING))

    local top="┌"
    local bottom="├"
    for (( i = 0; i < length - 2; i++ )); do
        top+="┬"
        bottom+="┴"
    done
    top+="┐"
    bottom+="┤"

    printf '%s\n' "$top"
    printf '%s\n' "$bottom"
}

PRINT_CENTERED_DATA() {
    local max_len=$((CURRENT_LEN+MAX_NAME_LEN-BORDERS_AND_PADDING))
    local text="$1"
    local total_width=$((max_len + 12))

    local text_len=${#text}
    local padding_left=$(( (total_width - text_len) / 2 ))
    local padding_right=$(( total_width - text_len - padding_left ))

    printf "│%${padding_left}s%s%${padding_right}s│\n" "" "$text" ""
}

PRINT_DIVIDER() {
    # either "top" or "bottom", no argument means middle divider
    local side="$1"
    case "$side" in
        "top")
            local left_symbol="├"
            local middle_symbol="┬"
            local right_symbol="┤"
            ;;
        "bottom")
            local left_symbol="└"
            local middle_symbol="┴"
            local right_symbol="┘"
            ;;
        *)
            local left_symbol="├"
            local middle_symbol="┼"
            local right_symbol="┤"
    esac

    local length=$((CURRENT_LEN+MAX_NAME_LEN+BORDERS_AND_PADDING))
    local divider="$left_symbol"
    for (( i = 0; i < length - 3; i++ )); do
        divider+="─"
        if [ "$i" -eq 14 ]; then
            divider+="$middle_symbol"
        fi
    done
    divider+="$right_symbol"
    printf '%s\n' "$divider"
}

PRINT_DATA() {
    local name="$1"
    local data="$2"
    local max_data_len=$CURRENT_LEN

    # Pad name
    local name_len=${#name}
    if (( name_len < MIN_NAME_LEN )); then
        name=$(printf "%-${MIN_NAME_LEN}s" "$name")
    elif (( name_len > MAX_NAME_LEN )); then
        name=$(echo "$name" | cut -c 1-$((MAX_NAME_LEN-3)))...
    else
        name=$(printf "%-${MAX_NAME_LEN}s" "$name")
    fi

    # Truncate or pad data
    local data_len=${#data}
    if (( data_len > MAX_DATA_LEN )); then
        data=$(echo "$data" | cut -c 1-$((MAX_DATA_LEN-3)))...
    else
        data=$(printf "%-${max_data_len}s" "$data")
    fi

    printf "│ %-${MAX_NAME_LEN}s │ %s │\n" "$name" "$data"
}

PRINT_FOOTER() {
    local length=$((CURRENT_LEN+MAX_NAME_LEN+BORDERS_AND_PADDING))
    local footer="└"
    for (( i = 0; i < length - 3; i++ )); do
        footer+="─"
        if [ "$i" -eq 14 ]; then
            footer+="┴"
        fi
    done
    footer+="┘"
    printf '%s\n' "$footer"
}

bar_graph() {
    local percent
    local num_blocks
    local width=$CURRENT_LEN
    local graph=""
    local used=$1
    local total=$2

    if (( total == 0 )); then
        percent=0
    else
        percent=$(awk -v used="$used" -v total="$total" 'BEGIN { printf "%.2f", (used / total) * 100 }')
    fi

    num_blocks=$(awk -v percent="$percent" -v width="$width" 'BEGIN { printf "%d", (percent / 100) * width }')
    (( num_blocks > width )) && num_blocks=$width

    for (( i = 0; i < num_blocks; i++ )); do
        graph+="█"
    done
    for (( i = num_blocks; i < width; i++ )); do
        graph+="░"
    done
    printf "%s" "${graph}"
}

get_ip_addr() {
    # Initialize variables
    ipv4_address=""
    ipv6_address=""

    # Check if ifconfig command exists
    if command -v ifconfig &> /dev/null; then
        # Try to get IPv4 address using ifconfig
        ipv4_address=$(ifconfig | awk '
            /^[a-zA-Z0-9]/ {iface=$1; sub(/:$/, "", iface)}
            iface !~ /^lo/ && iface !~ /^docker/ && /inet / && !found_ipv4 {found_ipv4=1; print $2}')

        # If IPv4 address not available, try IPv6 using ifconfig
        if [ -z "$ipv4_address" ]; then
            ipv6_address=$(ifconfig | awk '
                /^[a-zA-Z0-9]/ {iface=$1; sub(/:$/, "", iface)}
                iface !~ /^lo/ && iface !~ /^docker/ && /inet6 / && !found_ipv6 {found_ipv6=1; print $2}')
        fi
    elif command -v ip &> /dev/null; then
        # Try to get IPv4 address using ip addr
        ipv4_address=$(ip -o -4 addr show | awk '
            $2 != "lo" && $2 !~ /^docker/ {split($4, a, "/"); if (!found_ipv4++) print a[1]}')

        # If IPv4 address not available, try IPv6 using ip addr
        if [ -z "$ipv4_address" ]; then
            ipv6_address=$(ip -o -6 addr show | awk '
                $2 != "lo" && $2 !~ /^docker/ {split($4, a, "/"); if (!found_ipv6++) print a[1]}')
        fi
    fi

    # If neither IPv4 nor IPv6 address is available, assign "No IP found"
    if [ -z "$ipv4_address" ] && [ -z "$ipv6_address" ]; then
        ip_address="No IP found"
    else
        # Prioritize IPv4 if available, otherwise use IPv6
        ip_address="${ipv4_address:-$ipv6_address}"
    fi

    printf '%s' "$ip_address"
}

# Operating System Information
platform=$(uname -s)
os_kernel="$platform $(uname -r)"

if [ "$platform" = "Darwin" ]; then
    os_name="$(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
elif [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    os_name="${PRETTY_NAME:-$NAME}"
else
    os_name="$platform $(uname -r)"
fi

# Network Information
net_current_user=$(whoami)
if ! [ "$(command -v hostname)" ]; then
    net_hostname=$(grep -w "$(uname -n)" /etc/hosts | awk '{print $2}' | head -n 1)
else
    net_hostname=$(hostname -f)
fi

if [ -z "$net_hostname" ]; then net_hostname="Not Defined"; fi

net_machine_ip=$(get_ip_addr)
net_client_ip=$(who am i | awk '{print $5}' | tr -d '()')
if [ -z "$net_client_ip" ]; then
    net_client_ip="Not connected"
fi
net_dns_ip=($(grep '^nameserver [0-9.]' /etc/resolv.conf 2>/dev/null | awk '{print $2}'))

# CPU Information
if [ "$platform" = "Darwin" ]; then
    hardware_info=$(system_profiler SPHardwareDataType -detailLevel mini 2>/dev/null)
    cpu_model=$(printf '%s\n' "$hardware_info" | awk -F': ' '/^[[:space:]]*(Chip|Processor Name):/ {print $2; exit}')
    cpu_cores=$(sysctl -n hw.logicalcpu 2>/dev/null)
    [ -n "$cpu_cores" ] || cpu_cores=$(printf '%s\n' "$hardware_info" | awk -F': ' '/Total Number of Cores:/ {print $2; exit}' | awk '{print $1}')
    cpu_physical_cores=$(sysctl -n hw.physicalcpu 2>/dev/null)
    [ -n "$cpu_physical_cores" ] || cpu_physical_cores="$cpu_cores"
    cpu_core_summary="$cpu_cores logical / $cpu_physical_cores physical"

    cpu_freq_hz=$(sysctl -n hw.cpufrequency_max 2>/dev/null)
    [ -n "$cpu_freq_hz" ] || cpu_freq_hz=$(sysctl -n hw.cpufrequency 2>/dev/null)
    if [ -n "$cpu_freq_hz" ]; then
        cpu_freq=$(awk -v hz="$cpu_freq_hz" 'BEGIN {printf "%.2f", hz / 1000000000}')
        cpu_freq_unit="GHz"
    else
        # Apple Silicon uses dynamic clocks and does not publish a nominal frequency.
        cpu_freq="N/A (dynamic)"
        cpu_freq_unit=""
    fi

    if [ "$(sysctl -n kern.hv_vmm_present 2>/dev/null)" = "1" ]; then
        cpu_hypervisor="Apple Hypervisor"
    else
        cpu_hypervisor="Bare Metal"
    fi
else
    cpu_model="$(lscpu | awk -F: '/Model name/ && $0 !~ /BIOS/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}')"
    cpu_hypervisor="$(lscpu | awk -F: '/Hypervisor vendor/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}')"
    [ -n "$cpu_hypervisor" ] || cpu_hypervisor="Bare Metal"
    cpu_cores="$(nproc --all)"
    cpu_physical_cores="$(lscpu | awk -F: '/^Core\(s\) per socket/ {cores=$2} /^Socket\(s\)/ {sockets=$2} END {gsub(/ /, "", cores); gsub(/ /, "", sockets); print cores * sockets}')"
    cpu_core_summary="$cpu_cores logical / $cpu_physical_cores physical"
    cpu_freq="$(awk -F: '/cpu MHz/ {gsub(/ /, "", $2); printf "%.2f", $2 / 1000; exit}' /proc/cpuinfo)"
    cpu_freq_unit="GHz"
fi

load_averages=$(uptime | awk '{gsub(/,/, ""); print $(NF-2), $(NF-1), $NF}')
load_avg_1min=$(printf '%s\n' "$load_averages" | awk '{print $1}')
load_avg_5min=$(printf '%s\n' "$load_averages" | awk '{print $2}')
load_avg_15min=$(printf '%s\n' "$load_averages" | awk '{print $3}')

# Memory Information
if [ "$platform" = "Darwin" ]; then
    mem_total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    [ -n "$mem_total_bytes" ] || mem_total_bytes=$(printf '%s\n' "$hardware_info" | awk -F': ' '/^[[:space:]]*Memory:/ {print $2 * 1024 * 1024 * 1024; exit}')
    page_size=$(vm_stat | awk 'NR==1 {gsub(/[^0-9]/, "", $8); print $8}')
    available_pages=$(vm_stat | awk '/Pages free:|Pages inactive:|Pages speculative:/ {gsub(/\./, "", $3); pages += $3} END {print pages}')
    mem_total=$((mem_total_bytes / 1024))
    mem_available=$((available_pages * page_size / 1024))
else
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
fi
mem_used=$((mem_total - mem_available))
mem_percent=$(awk -v used="$mem_used" -v total="$mem_total" 'BEGIN { printf "%.2f", (used / total) * 100 }')
mem_percent=$(printf "%.2f" "$mem_percent")
mem_total_gb=$(echo "$mem_total" | awk '{ printf "%.2f", $1 / (1024 * 1024) }') # (From Ki to Gi units)
mem_available_gb=$(echo "$mem_available" | awk '{ printf "%.2f", $1 / (1024 * 1024) }') # (From Ki to Gi units) Not used currently
mem_used_gb=$(echo "$mem_used" | awk '{ printf "%.2f", $1 / (1024 * 1024) }')

# Disk Information
if [ "$platform" != "Darwin" ] && command -v zfs >/dev/null 2>&1 && grep -q "zfs" /proc/mounts; then
    zfs_present=1
    zfs_health=$(zpool status -x zroot | grep -q "is healthy" && echo  "HEALTH O.K.")
    zfs_available=$(zfs get -o value -Hp available "$zfs_filesystem")
    zfs_used=$(zfs get -o value -Hp used "$zfs_filesystem")
    zfs_available_gb=$(echo "$zfs_available" | awk '{ printf "%.2f", $1 / (1024 * 1024 * 1024) }') # (To G units)
    zfs_used_gb=$(echo "$zfs_used" | awk '{ printf "%.2f", $1 / (1024 * 1024 * 1024) }') # (To G units)
    disk_percent=$(awk -v used="$zfs_used" -v available="$zfs_available" 'BEGIN { printf "%.2f", (used / available) * 100 }')
else
    # Thanks https://github.com/AnarchistHoneybun
    root_partition="/"
    [ "$platform" = "Darwin" ] && [ -d /System/Volumes/Data ] && root_partition="/System/Volumes/Data"
    root_used=$(df -k "$root_partition" | awk 'NR==2 {print $3}')
    root_total=$(df -k "$root_partition" | awk 'NR==2 {print $2}')
    root_total_gb=$(awk -v total="$root_total" 'BEGIN { printf "%.2f", total / (1024 * 1024) }')
    root_used_gb=$(awk -v used="$root_used" 'BEGIN { printf "%.2f", used / (1024 * 1024) }')
    disk_percent=$(awk -v used="$root_used" -v total="$root_total" 'BEGIN { printf "%.2f", (used / total) * 100 }')
fi

# Last login and Uptime
if [ "$platform" = "Darwin" ]; then
    last_login=$(last -1 "$USER" | awk 'NR==1')
    last_login_ip=$(printf '%s\n' "$last_login" | awk '{for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {print $i; exit}}')
    last_login_time=$(printf '%s\n' "$last_login" | awk '{for (i=1; i<=NF; i++) if ($i ~ /^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$/) {print $i, $(i+1), $(i+2), $(i+3); exit}}')
    [ -n "$last_login_time" ] || last_login_time="Never logged in"
else
    last_login=$(lastlog -u "$USER")
    last_login_ip=$(echo "$last_login" | awk 'NR==2 {print $3}')

# Check if last_login_ip is an IP address
    if [[ "$last_login_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        last_login_time=$(echo "$last_login" | awk 'NR==2 {print $6, $7, $10, $8}')
    else
        last_login_time=$(echo "$last_login" | awk 'NR==2 {print $4, $5, $8, $6}')
        if [ "$last_login_time" = "in**" ]; then
            last_login_time="Never logged in"
        fi
    fi
fi

if [[ "$last_login_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    last_login_ip_present=1
fi

if [ "$platform" = "Darwin" ]; then
    boot_epoch=$(sysctl -n kern.boottime 2>/dev/null | awk -F'[=,]' '{gsub(/ /, "", $2); print $2}')
    if [ -z "$boot_epoch" ]; then
        # Useful fallback for restricted environments where sysctl is unavailable.
        boot_description=$(who -b | awk '{print $3, $4, $5}')
        boot_year=$(date +%Y)
        boot_epoch=$(date -j -f '%b %e %H:%M %Y' "$boot_description $boot_year" +%s 2>/dev/null)
        if [ -n "$boot_epoch" ] && (( boot_epoch > $(date +%s) )); then
            boot_year=$((boot_year - 1))
            boot_epoch=$(date -j -f '%b %e %H:%M %Y' "$boot_description $boot_year" +%s 2>/dev/null)
        fi
    fi

    if [ -n "$boot_epoch" ]; then
        uptime_seconds=$(($(date +%s) - boot_epoch))
        uptime_days=$((uptime_seconds / 86400))
        uptime_hours=$(((uptime_seconds % 86400) / 3600))
        uptime_minutes=$(((uptime_seconds % 3600) / 60))
        if (( uptime_days > 0 )); then
            sys_uptime="${uptime_days}d ${uptime_hours}h ${uptime_minutes}m"
        else
            sys_uptime="${uptime_hours}h ${uptime_minutes}m"
        fi
    else
        sys_uptime="Unavailable"
    fi
else
    sys_uptime=$(uptime -p | sed 's/up\s*//; s/\s*day\(s*\)/d/; s/\s*hour\(s*\)/h/; s/\s*minute\(s*\)/m/')
fi

# Set current length before graphs get calculated
set_current_len

# Create graphs
cpu_1min_bar_graph=$(bar_graph "$load_avg_1min" "$cpu_cores")
cpu_5min_bar_graph=$(bar_graph "$load_avg_5min" "$cpu_cores")
cpu_15min_bar_graph=$(bar_graph "$load_avg_15min" "$cpu_cores")

mem_bar_graph=$(bar_graph "$mem_used" "$mem_total")

if [ $zfs_present -eq 1 ]; then
    disk_bar_graph=$(bar_graph "$zfs_used" "$zfs_available")
else
    disk_bar_graph=$(bar_graph "$root_used" "$root_total")
fi

# Machine Report
PRINT_HEADER
PRINT_CENTERED_DATA "$report_title"
PRINT_CENTERED_DATA "TR-100 MACHINE REPORT"
PRINT_DIVIDER "top"
PRINT_DATA "OS" "$os_name"
PRINT_DATA "KERNEL" "$os_kernel"
PRINT_DIVIDER
PRINT_DATA "HOSTNAME" "$net_hostname"
PRINT_DATA "MACHINE IP" "$net_machine_ip"
PRINT_DATA "CLIENT  IP" "$net_client_ip"

for dns_num in "${!net_dns_ip[@]}"; do
    PRINT_DATA "DNS  IP $(($dns_num + 1))" "${net_dns_ip[dns_num]}"
done

PRINT_DATA "USER" "$net_current_user"
PRINT_DIVIDER
PRINT_DATA "PROCESSOR" "$cpu_model"
PRINT_DATA "CORES" "$cpu_core_summary"
PRINT_DATA "HYPERVISOR" "$cpu_hypervisor"
PRINT_DATA "CPU FREQ" "$cpu_freq${cpu_freq_unit:+ $cpu_freq_unit}"
PRINT_DATA "LOAD  1m" "$cpu_1min_bar_graph"
PRINT_DATA "LOAD  5m" "$cpu_5min_bar_graph"
PRINT_DATA "LOAD 15m" "$cpu_15min_bar_graph"

if [ $zfs_present -eq 1 ]; then
    PRINT_DIVIDER
    PRINT_DATA "VOLUME" "$zfs_used_gb/$zfs_available_gb GB [$disk_percent%]"
    PRINT_DATA "DISK USAGE" "$disk_bar_graph"
    PRINT_DATA "ZFS HEALTH" "$zfs_health"
else
    PRINT_DIVIDER
    PRINT_DATA "VOLUME" "$root_used_gb/$root_total_gb GB [$disk_percent%]"
    PRINT_DATA "DISK USAGE" "$disk_bar_graph"
fi

PRINT_DIVIDER
PRINT_DATA "MEMORY" "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]"
PRINT_DATA "USAGE" "${mem_bar_graph}"
PRINT_DIVIDER
PRINT_DATA "LAST LOGIN" "$last_login_time"

if [ $last_login_ip_present -eq 1 ]; then
    PRINT_DATA "" "$last_login_ip"
fi

PRINT_DATA "UPTIME" "$sys_uptime"
PRINT_DIVIDER "bottom"
