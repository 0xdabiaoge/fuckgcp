#!/bin/bash
# ============================================================
# CDN 屏蔽管理工具
# 用途：在 GCP 免费服务器上屏蔽 CDN 提供商的 IP 段
#       防止 CDN 回源流量消耗免费出站配额
# 支持：Cloudflare / Fastly / Akamai (含 Linode)
# ============================================================

IPSET_NAME_V4="cdn_ips"
IPSET_NAME_V6="cdn_ips_v6"
SERVICE_NAME="cdn-block"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_PATH="$(readlink -f "$0")"
SOURCES_LIST="/etc/apt/sources.list"
SOURCES_BACKUP="/etc/apt/sources.list.bak.cdn-block"

# 流量监控相关
TRAFFIC_DIR="/var/lib/cdn-block"
TRAFFIC_STATE="${TRAFFIC_DIR}/traffic_state"
TRAFFIC_HISTORY="${TRAFFIC_DIR}/traffic_history"
TRAFFIC_LIMIT_GB=200
TRAFFIC_LIMIT_BYTES=$((TRAFFIC_LIMIT_GB * 1073741824))  # 200GB in bytes
CRON_TAG="cdn-block-traffic"

# ============================================================
# 内嵌 CDN IPv4 列表
# ============================================================
generate_ipv4_list() {
cat << 'EOF'
# Cloudflare
173.245.48.0/20
103.21.244.0/22
103.22.200.0/22
103.31.4.0/22
141.101.64.0/18
108.162.192.0/18
190.93.240.0/20
188.114.96.0/20
197.234.240.0/22
198.41.128.0/17
162.158.0.0/15
104.16.0.0/13
104.24.0.0/14
172.64.0.0/13
131.0.72.0/22
# Fastly
23.235.32.0/20
43.249.72.0/22
103.244.50.0/24
103.245.222.0/23
103.245.224.0/24
104.156.80.0/20
140.248.64.0/18
140.248.128.0/17
146.75.0.0/17
151.101.0.0/16
157.52.64.0/18
167.82.0.0/17
167.82.128.0/20
167.82.160.0/20
167.82.224.0/20
172.111.64.0/18
185.31.16.0/22
199.27.72.0/21
199.232.0.0/16
# Akamai
2.16.0.0/13
4.77.205.0/24
8.28.5.0/24
8.31.234.0/24
8.38.97.0/24
23.0.0.0/12
23.32.0.0/11
23.64.0.0/14
23.72.0.0/13
23.92.16.0/20
23.192.0.0/11
23.239.0.0/19
27.116.32.0/24
27.116.33.0/24
43.249.213.0/24
43.254.120.0/22
45.33.0.0/17
45.56.64.0/18
45.79.0.0/18
45.79.64.0/18
45.79.128.0/17
45.118.132.0/22
49.231.112.0/24
49.231.116.0/23
50.116.0.0/18
59.151.128.0/18
60.87.0.0/24
60.87.1.0/24
60.87.2.0/24
60.87.3.0/24
60.87.4.0/24
60.87.5.0/24
60.87.6.0/24
60.87.7.0/24
60.87.8.0/24
60.87.9.0/24
60.87.10.0/24
60.87.11.0/24
60.87.12.0/24
60.87.13.0/24
60.87.14.0/24
60.87.15.0/24
60.254.128.0/18
61.19.5.0/24
61.19.8.0/24
61.19.11.0/24
61.19.12.0/24
61.19.13.0/24
63.84.59.0/24
63.85.36.0/24
63.116.109.0/24
63.119.76.0/24
63.126.84.0/24
63.141.194.0/25
63.141.196.0/25
63.141.196.128/25
63.146.70.0/24
63.150.12.0/25
63.150.12.128/25
63.208.195.0/24
63.210.173.0/24
63.215.198.96/32
63.217.232.0/24
63.233.60.0/23
63.233.112.0/24
63.233.126.0/24
63.233.224.0/24
63.235.20.0/23
63.238.251.0/24
63.239.232.0/23
63.247.71.192/26
64.5.53.0/24
64.22.71.0/24
64.22.84.0/24
64.22.103.0/24
64.22.109.0/24
64.22.124.0/23
64.62.190.0/24
64.62.228.0/24
64.62.231.0/24
64.71.152.0/24
64.89.224.0/20
64.124.214.0/24
64.157.40.192/26
64.208.48.0/25
64.208.187.0/24
64.212.114.0/23
65.19.178.0/24
65.49.60.0/24
65.116.164.0/23
65.118.123.128/26
65.123.23.0/28
65.158.180.0/24
65.158.184.0/24
65.202.32.0/22
66.160.141.0/24
66.171.231.0/25
66.175.208.0/20
66.220.1.0/24
66.228.32.0/19
66.246.75.0/24
66.246.76.0/24
66.246.138.0/24
67.18.89.0/24
67.18.92.0/24
67.18.176.0/24
67.18.186.0/23
67.18.208.0/24
67.131.232.0/24
67.132.55.128/25
69.22.150.0/23
69.27.160.0/20
69.31.20.0/24
69.31.21.0/25
69.31.106.0/23
69.31.112.0/23
69.31.118.0/24
69.31.119.0/25
69.31.119.128/25
69.31.121.0/25
69.31.122.0/24
69.45.79.0/24
69.45.84.0/23
69.45.86.0/24
69.56.173.0/24
69.56.251.0/24
69.93.127.0/24
69.164.192.0/19
69.192.0.0/16
70.39.139.0/25
70.47.152.0/21
70.85.16.0/24
70.85.31.0/24
70.85.129.0/24
70.87.222.0/24
72.14.176.0/20
72.52.0.0/24
72.52.62.0/24
72.200.254.0/24
72.200.255.0/24
72.246.0.0/15
74.82.2.0/23
74.82.5.0/24
74.121.124.0/22
74.207.224.0/20
74.207.240.0/20
75.127.72.0/24
75.127.96.0/23
80.67.64.0/19
80.85.84.0/22
81.200.64.0/20
84.53.128.0/18
85.90.244.0/22
85.159.208.0/21
88.80.184.0/21
88.221.0.0/16
92.122.0.0/15
95.100.0.0/15
96.6.0.0/15
96.16.0.0/15
96.126.96.0/19
97.107.128.0/20
103.3.56.0/23
103.3.60.0/22
103.5.215.0/24
103.6.180.0/24
103.11.223.0/24
103.12.23.0/24
103.13.37.0/24
103.15.143.0/24
103.16.77.0/24
103.16.197.0/24
103.18.190.0/23
103.29.68.0/22
103.74.6.0/23
103.74.12.0/23
103.95.84.0/22
103.104.76.0/22
103.224.140.0/23
103.228.80.0/23
103.231.198.0/23
103.238.148.0/22
103.243.12.0/22
103.249.58.0/23
103.252.85.0/24
104.64.0.0/10
104.200.16.0/20
104.237.128.0/19
106.186.16.0/20
109.74.192.0/20
109.237.24.0/22
115.69.232.0/22
118.214.0.0/15
119.119.222.0/24
121.78.191.0/24
122.155.239.0/24
122.252.32.0/19
122.252.128.0/20
124.40.52.208/28
124.158.25.0/24
125.56.128.0/17
125.252.192.0/18
126.147.252.0/22
128.241.91.0/24
128.241.217.0/24
128.241.218.0/24
131.203.4.0/22
139.144.0.0/16
139.162.0.0/18
139.162.64.0/19
139.162.96.0/19
139.162.128.0/19
139.162.160.0/19
139.162.192.0/18
139.177.176.0/20
139.177.192.0/20
143.42.0.0/21
143.42.8.0/21
143.42.16.0/20
143.42.32.0/20
143.42.48.0/20
143.42.64.0/20
143.42.80.0/20
143.42.96.0/20
143.42.112.0/20
143.42.128.0/20
143.42.144.0/20
143.42.160.0/20
143.42.176.0/20
143.42.192.0/19
143.42.224.0/20
143.42.240.0/20
146.82.98.0/24
151.122.128.0/17
151.236.216.0/21
157.238.74.0/23
157.238.91.0/25
159.180.64.0/19
162.216.16.0/22
165.254.2.0/24
165.254.27.64/26
165.254.40.0/23
165.254.44.0/23
165.254.50.0/23
165.254.52.0/24
165.254.107.0/24
165.254.139.0/24
165.254.150.0/24
165.254.215.0/24
165.254.245.0/25
166.90.150.0/24
166.90.208.166/32
168.143.214.0/24
168.143.240.0/22
168.143.254.0/23
170.187.128.0/17
172.104.0.0/15
172.224.0.0/12
172.247.176.0/20
173.205.69.0/24
173.205.76.0/23
173.205.78.0/23
173.222.0.0/15
173.230.128.0/20
173.230.144.0/20
173.255.192.0/19
173.255.224.0/20
173.255.240.0/20
176.58.96.0/19
178.79.128.0/18
182.50.0.0/20
182.50.16.0/20
182.50.32.0/20
182.51.200.0/22
184.24.0.0/13
184.50.0.0/15
184.84.0.0/14
184.214.32.0/20
185.3.92.0/22
185.89.20.0/22
185.225.250.0/24
185.225.251.0/24
189.247.204.0/23
189.247.206.0/24
189.247.207.0/24
189.247.216.0/24
190.94.188.0/24
190.98.153.0/24
190.98.160.0/24
190.98.161.0/24
192.33.24.0/21
192.46.208.0/20
192.46.224.0/20
192.53.112.0/20
192.53.160.0/20
192.81.128.0/21
192.155.80.0/20
193.108.88.0/24
193.108.89.0/24
193.108.91.0/24
193.108.92.0/24
193.108.94.0/23
193.108.152.0/22
194.195.112.0/20
194.195.208.0/20
194.195.240.0/20
194.233.160.0/19
195.57.81.0/24
195.57.152.0/23
195.95.192.0/22
195.122.148.0/24
195.245.124.0/22
198.47.108.0/25
198.47.116.0/24
198.58.96.0/19
198.74.48.0/20
198.93.38.0/24
198.144.112.0/24
198.180.186.0/23
199.101.28.0/22
199.119.220.0/22
199.239.182.0/23
199.239.184.0/24
200.60.136.0/23
200.60.190.0/24
200.136.36.0/24
201.16.50.0/24
201.159.159.0/24
201.220.10.0/24
202.4.185.0/24
202.12.75.0/24
202.43.88.0/23
202.74.45.0/24
202.90.8.0/22
202.90.15.0/24
202.94.80.0/24
202.138.164.0/22
202.138.183.0/24
202.171.237.0/24
202.226.44.0/22
203.25.23.0/24
203.27.6.0/23
203.30.14.0/24
203.31.242.0/24
203.63.146.0/24
203.69.138.0/24
203.69.141.0/24
203.161.190.0/23
203.198.20.0/24
203.217.134.0/23
203.221.109.0/24
203.223.90.0/23
204.0.54.0/23
204.2.132.64/26
204.2.132.128/25
204.2.136.0/24
204.2.137.0/24
204.2.146.0/25
204.2.148.128/25
204.2.163.64/26
204.2.187.0/24
204.2.191.128/25
204.2.196.0/24
204.2.211.0/26
204.2.211.192/26
204.2.255.0/25
204.8.48.0/22
204.10.28.0/22
204.93.38.0/23
204.93.46.0/23
204.93.48.0/24
204.141.239.0/24
204.237.134.0/25
204.237.142.0/23
204.237.182.0/25
204.237.201.0/26
204.237.229.0/25
204.245.23.0/24
204.245.143.0/25
204.246.230.0/24
206.55.4.128/25
206.57.28.0/24
206.132.122.0/24
206.239.100.0/23
207.192.68.0/22
207.192.72.0/22
208.48.0.0/24
208.49.247.64/28
208.49.247.80/28
209.123.162.0/24
209.123.234.0/24
210.8.28.0/23
210.9.71.0/24
210.9.135.192/26
210.10.243.0/27
210.11.208.0/24
210.11.209.0/24
210.11.210.0/24
210.11.211.0/24
210.11.212.0/23
210.61.248.0/23
211.175.153.0/24
212.71.232.0/21
212.71.244.0/22
212.71.248.0/21
212.73.225.0/24
212.111.40.0/22
213.52.128.0/22
213.168.248.0/22
213.219.36.0/22
216.156.213.0/24
216.156.242.0/24
216.187.88.0/23
216.200.69.0/24
216.206.12.128/26
216.206.30.0/24
217.163.15.0/24
219.76.11.0/24
220.227.183.0/24
221.110.130.0/25
221.110.130.128/25
221.110.152.0/24
221.110.165.0/24
221.110.182.0/25
221.110.183.0/24
221.110.213.128/25
221.110.252.0/25
221.110.252.128/25
221.111.192.0/25
221.111.224.0/26
EOF
}

# ============================================================
# 内嵌 CDN IPv6 列表
# ============================================================
generate_ipv6_list() {
cat << 'EOF'
# Cloudflare IPv6
2400:cb00::/32
2606:4700::/32
2803:f800::/32
2405:b500::/32
2405:8100::/32
2a06:98c0::/29
2c0f:f248::/32
# Fastly IPv6
2a04:4e40::/32
2a04:4e42::/32
EOF
}

# ============================================================
# 颜色定义
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # 无颜色

# ============================================================
# 工具函数
# ============================================================
msg_info()    { echo -e "${BLUE}[信息]${NC} $1"; }
msg_ok()      { echo -e "${GREEN}[成功]${NC} $1"; }
msg_warn()    { echo -e "${YELLOW}[警告]${NC} $1"; }
msg_err()     { echo -e "${RED}[错误]${NC} $1"; }

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_err "此脚本需要 root 权限运行"
        msg_info "请使用: sudo $0"
        exit 1
    fi
}

# 检查依赖
check_deps() {
    local missing=()
    for cmd in ipset iptables; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        msg_err "缺少必要命令: ${missing[*]}"
        msg_info "请运行: apt install -y ipset iptables"
        exit 1
    fi
}

# 检查 IPv6 工具是否可用
has_ip6tables() {
    command -v ip6tables &>/dev/null
}

# 按 ENTER 继续
press_enter() {
    echo ""
    read -rp "按 Enter 键返回菜单..."
}

# ============================================================
# 核心功能：加载/卸载规则
# ============================================================

# 加载 IPv4 规则
load_ipv4_rules() {
    # 如果 ipset 已存在则先清空
    if ipset list -n 2>/dev/null | grep -qw "$IPSET_NAME_V4"; then
        ipset flush "$IPSET_NAME_V4"
    else
        ipset create "$IPSET_NAME_V4" hash:net
    fi

    # 逐行添加 IP，跳过注释和空行
    local count=0
    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '\r' | xargs)
        [[ -z "$line" || "$line" == \#* ]] && continue
        ipset add "$IPSET_NAME_V4" "$line" -exist
        count=$((count + 1))
    done <<< "$(generate_ipv4_list)"
    msg_info "已加载 ${count} 条 IPv4 规则"

    # 添加 iptables 规则（避免重复）
    if ! iptables -C INPUT -m set --match-set "$IPSET_NAME_V4" src -j DROP 2>/dev/null; then
        iptables -I INPUT -m set --match-set "$IPSET_NAME_V4" src -j DROP
    fi
    if ! iptables -C OUTPUT -m set --match-set "$IPSET_NAME_V4" dst -j DROP 2>/dev/null; then
        iptables -I OUTPUT -m set --match-set "$IPSET_NAME_V4" dst -j DROP
    fi
}

# 加载 IPv6 规则
load_ipv6_rules() {
    if ! has_ip6tables; then
        msg_warn "ip6tables 不可用，跳过 IPv6 规则"
        return
    fi

    if ipset list -n 2>/dev/null | grep -qw "$IPSET_NAME_V6"; then
        ipset flush "$IPSET_NAME_V6"
    else
        ipset create "$IPSET_NAME_V6" hash:net family inet6
    fi

    local count=0
    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '\r' | xargs)
        [[ -z "$line" || "$line" == \#* ]] && continue
        ipset add "$IPSET_NAME_V6" "$line" -exist
        count=$((count + 1))
    done <<< "$(generate_ipv6_list)"
    msg_info "已加载 ${count} 条 IPv6 规则"

    if ! ip6tables -C INPUT -m set --match-set "$IPSET_NAME_V6" src -j DROP 2>/dev/null; then
        ip6tables -I INPUT -m set --match-set "$IPSET_NAME_V6" src -j DROP
    fi
    if ! ip6tables -C OUTPUT -m set --match-set "$IPSET_NAME_V6" dst -j DROP 2>/dev/null; then
        ip6tables -I OUTPUT -m set --match-set "$IPSET_NAME_V6" dst -j DROP
    fi
}

# 卸载 IPv4 规则
unload_ipv4_rules() {
    # 删除 iptables 规则
    # 加载时 INPUT 匹配 src，OUTPUT 匹配 dst，卸载时需精确对应
    if iptables -C INPUT -m set --match-set "$IPSET_NAME_V4" src -j DROP 2>/dev/null; then
        iptables -D INPUT -m set --match-set "$IPSET_NAME_V4" src -j DROP
    fi
    if iptables -C OUTPUT -m set --match-set "$IPSET_NAME_V4" dst -j DROP 2>/dev/null; then
        iptables -D OUTPUT -m set --match-set "$IPSET_NAME_V4" dst -j DROP
    fi

    # 销毁 ipset
    if ipset list -n 2>/dev/null | grep -qw "$IPSET_NAME_V4"; then
        ipset flush "$IPSET_NAME_V4"
        ipset destroy "$IPSET_NAME_V4"
    fi
}

# 卸载 IPv6 规则
unload_ipv6_rules() {
    if ! has_ip6tables; then
        return
    fi

    if ip6tables -C INPUT -m set --match-set "$IPSET_NAME_V6" src -j DROP 2>/dev/null; then
        ip6tables -D INPUT -m set --match-set "$IPSET_NAME_V6" src -j DROP
    fi
    if ip6tables -C OUTPUT -m set --match-set "$IPSET_NAME_V6" dst -j DROP 2>/dev/null; then
        ip6tables -D OUTPUT -m set --match-set "$IPSET_NAME_V6" dst -j DROP
    fi

    if ipset list -n 2>/dev/null | grep -qw "$IPSET_NAME_V6"; then
        ipset flush "$IPSET_NAME_V6"
        ipset destroy "$IPSET_NAME_V6"
    fi
}

# 加载全部规则
load_all_rules() {
    load_ipv4_rules
    load_ipv6_rules
}

# 卸载全部规则
unload_all_rules() {
    unload_ipv4_rules
    unload_ipv6_rules
}

# ============================================================
# 状态检查
# ============================================================
is_rules_active() {
    ipset list -n 2>/dev/null | grep -qw "$IPSET_NAME_V4"
}

is_service_enabled() {
    systemctl is-enabled "$SERVICE_NAME" &>/dev/null
}

# is_service_active() - 备用函数，可用于未来扩展
# systemctl is-active "$SERVICE_NAME" &>/dev/null

# ============================================================
# 菜单功能
# ============================================================

# 1. 临时启用 CDN 屏蔽
do_temp_enable() {
    echo ""
    msg_info "正在临时启用 CDN 屏蔽（重启后失效）..."
    if is_rules_active; then
        msg_warn "CDN 屏蔽规则已处于启用状态"
    else
        load_all_rules
        msg_ok "CDN 屏蔽已临时启用"
    fi
    press_enter
}

# 2. 临时停用 CDN 屏蔽
do_temp_disable() {
    echo ""
    msg_info "正在临时停用 CDN 屏蔽..."
    if is_rules_active; then
        unload_all_rules
        msg_ok "CDN 屏蔽已临时停用（如已设置永久屏蔽，重启后会恢复）"
    else
        msg_warn "CDN 屏蔽规则当前未启用"
    fi
    press_enter
}

# 3. 永久启用 CDN 屏蔽
do_permanent_enable() {
    echo ""
    msg_info "正在设置永久 CDN 屏蔽（开机自启）..."

    # 创建 systemd service
    cat > "$SERVICE_FILE" << SVCEOF
[Unit]
Description=CDN IP 屏蔽服务
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${SCRIPT_PATH} --apply
ExecStop=${SCRIPT_PATH} --remove

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" &>/dev/null

    # 安装流量监控 cron 任务
    install_traffic_cron
    # 首次更新流量基线
    update_traffic

    # 同时立即启用规则
    if ! is_rules_active; then
        load_all_rules
    fi

    msg_ok "永久 CDN 屏蔽已启用，开机将自动生效"
    msg_warn "提示: 如果 apt 源使用 deb.debian.org（走 CDN），请前往菜单 9 切换源"
    press_enter
}

# 4. 永久停用 CDN 屏蔽
do_permanent_disable() {
    echo ""
    msg_info "正在移除永久 CDN 屏蔽..."

    if [[ -f "$SERVICE_FILE" ]]; then
        systemctl stop "$SERVICE_NAME" &>/dev/null
        systemctl disable "$SERVICE_NAME" &>/dev/null
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
    fi

    # 移除流量监控 cron 任务
    remove_traffic_cron

    # 同时清除当前规则
    if is_rules_active; then
        unload_all_rules
    fi

    msg_ok "永久 CDN 屏蔽已移除，开机不再自动启用"
    press_enter
}

# 5. 查看屏蔽状态
do_show_status() {
    echo ""
    echo -e "${BOLD}========== CDN 屏蔽状态 ==========${NC}"
    echo ""

    # 运行时状态
    if is_rules_active; then
        echo -e "  运行时屏蔽:  ${GREEN}● 已启用${NC}"
        local v4_count
        v4_count=$(ipset list "$IPSET_NAME_V4" 2>/dev/null | sed -n '/^Members:/,$p' | tail -n +2 | grep -c . || echo "0")
        echo -e "  IPv4 规则数:  ${CYAN}${v4_count}${NC}"

        if ipset list -n 2>/dev/null | grep -qw "$IPSET_NAME_V6"; then
            local v6_count
            v6_count=$(ipset list "$IPSET_NAME_V6" 2>/dev/null | sed -n '/^Members:/,$p' | tail -n +2 | grep -c . || echo "0")
            echo -e "  IPv6 规则数:  ${CYAN}${v6_count}${NC}"
        else
            echo -e "  IPv6 规则数:  ${YELLOW}未加载${NC}"
        fi
    else
        echo -e "  运行时屏蔽:  ${RED}● 未启用${NC}"
    fi

    # 永久状态
    if is_service_enabled 2>/dev/null; then
        echo -e "  开机自启:    ${GREEN}● 已启用${NC}"
    else
        echo -e "  开机自启:    ${RED}● 未启用${NC}"
    fi

    # iptables 规则
    echo ""
    echo -e "${BOLD}--- IPv4 iptables 规则 ---${NC}"
    iptables -L INPUT -n --line-numbers 2>/dev/null | grep -i "cdn_ips" || echo "  (无)"
    iptables -L OUTPUT -n --line-numbers 2>/dev/null | grep -i "cdn_ips" || echo "  (无)"

    if has_ip6tables; then
        echo ""
        echo -e "${BOLD}--- IPv6 ip6tables 规则 ---${NC}"
        ip6tables -L INPUT -n --line-numbers 2>/dev/null | grep -i "cdn_ips_v6" || echo "  (无)"
        ip6tables -L OUTPUT -n --line-numbers 2>/dev/null | grep -i "cdn_ips_v6" || echo "  (无)"
    fi

    echo ""
    echo -e "${BOLD}==================================${NC}"
    press_enter
}

# 6. 查看屏蔽 IP 列表
do_show_ips() {
    echo ""
    local output
    if ! is_rules_active; then
        msg_warn "CDN 屏蔽规则当前未启用，以下显示的是内嵌 IP 列表"
        output=$(
            echo ""
            echo "--- IPv4 ---"
            generate_ipv4_list
            echo ""
            echo "--- IPv6 ---"
            generate_ipv6_list
        )
    else
        output=$(
            echo "--- IPv4 (ipset: ${IPSET_NAME_V4}) ---"
            ipset list "$IPSET_NAME_V4" 2>/dev/null | sed -n '/^Members:/,$p' | tail -n +2
            echo ""
            if ipset list -n 2>/dev/null | grep -qw "$IPSET_NAME_V6"; then
                echo "--- IPv6 (ipset: ${IPSET_NAME_V6}) ---"
                ipset list "$IPSET_NAME_V6" 2>/dev/null | sed -n '/^Members:/,$p' | tail -n +2
            fi
        )
    fi
    # 内容较多时使用 less 分页，否则直接输出
    local line_count
    line_count=$(echo "$output" | wc -l)
    if [[ $line_count -gt 50 ]] && command -v less &>/dev/null; then
        echo "$output" | less
    else
        echo "$output"
    fi
    press_enter
}

# 7. 添加自定义 IP 段
do_add_ip() {
    echo ""
    if ! is_rules_active; then
        msg_err "请先启用 CDN 屏蔽后再添加 IP 段"
        press_enter
        return
    fi

    read -rp "请输入要添加的 IP 段 (CIDR 格式，如 1.2.3.0/24): " new_ip
    new_ip=$(echo "$new_ip" | tr -d '\r' | xargs)

    if [[ -z "$new_ip" ]]; then
        msg_err "输入不能为空"
        press_enter
        return
    fi

    # 判断 IPv4 还是 IPv6
    if [[ "$new_ip" == *:* ]]; then
        # IPv6
        if ! has_ip6tables; then
            msg_err "ip6tables 不可用，无法添加 IPv6 规则"
            press_enter
            return
        fi
        if ! ipset list -n 2>/dev/null | grep -qw "$IPSET_NAME_V6"; then
            msg_err "IPv6 ipset 未创建，请先启用屏蔽"
            press_enter
            return
        fi
        if ipset add "$IPSET_NAME_V6" "$new_ip" -exist 2>/dev/null; then
            msg_ok "已添加 IPv6 段: $new_ip"
        else
            msg_err "添加失败，请检查 CIDR 格式是否正确"
        fi
    else
        # IPv4
        if ipset add "$IPSET_NAME_V4" "$new_ip" -exist 2>/dev/null; then
            msg_ok "已添加 IPv4 段: $new_ip"
        else
            msg_err "添加失败，请检查 CIDR 格式是否正确"
        fi
    fi
    press_enter
}

# 8. 删除指定 IP 段
do_del_ip() {
    echo ""
    if ! is_rules_active; then
        msg_err "CDN 屏蔽规则当前未启用"
        press_enter
        return
    fi

    read -rp "请输入要删除的 IP 段 (CIDR 格式，如 1.2.3.0/24): " del_ip
    del_ip=$(echo "$del_ip" | tr -d '\r' | xargs)

    if [[ -z "$del_ip" ]]; then
        msg_err "输入不能为空"
        press_enter
        return
    fi

    if [[ "$del_ip" == *:* ]]; then
        if ipset del "$IPSET_NAME_V6" "$del_ip" 2>/dev/null; then
            msg_ok "已从 IPv6 集合删除: $del_ip"
        else
            msg_err "删除失败，该 IP 段可能不存在"
        fi
    else
        if ipset del "$IPSET_NAME_V4" "$del_ip" 2>/dev/null; then
            msg_ok "已从 IPv4 集合删除: $del_ip"
        else
            msg_err "删除失败，该 IP 段可能不存在"
        fi
    fi
    press_enter
}

# 9. APT 换源管理
do_apt_source() {
    # 检测 Debian 版本代号
    local codename
    if [[ -f /etc/os-release ]]; then
        codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
    fi
    if [[ -z "$codename" ]]; then
        codename=$(lsb_release -cs 2>/dev/null || echo "bookworm")
    fi

    while true; do
        echo ""
        echo -e "${BOLD}========== APT 换源管理 ==========${NC}"
        echo -e "  检测到 Debian 版本代号: ${CYAN}${codename}${NC}"
        echo ""
        echo "  1) 查看当前源"
        echo "  2) 切换到清华源 (mirrors.tuna.tsinghua.edu.cn)"
        echo "  3) 切换到 Debian 美国直连镜像 (ftp.us.debian.org)"
        echo "  4) 恢复默认源 (deb.debian.org)"
        echo "  5) 恢复原始备份 (换源前的配置)"
        echo "  0) 返回主菜单"
        echo -e "${BOLD}==================================${NC}"
        echo ""
        read -rp "请选择 [0-5]: " apt_choice

        case "$apt_choice" in
            1)
                echo ""
                echo -e "${BOLD}--- 当前 sources.list ---${NC}"
                if [[ -f "$SOURCES_LIST" ]]; then
                    cat "$SOURCES_LIST"
                else
                    msg_warn "sources.list 不存在"
                fi
                # 检查 sources.list.d 目录
                if [[ -d /etc/apt/sources.list.d/ ]] && ls /etc/apt/sources.list.d/*.list &>/dev/null 2>&1; then
                    echo ""
                    echo -e "${BOLD}--- sources.list.d/ ---${NC}"
                    for f in /etc/apt/sources.list.d/*.list; do
                        echo -e "${CYAN}[$f]${NC}"
                        cat "$f"
                        echo ""
                    done
                fi
                # 检查 DEB822 格式 (.sources)
                if [[ -d /etc/apt/sources.list.d/ ]] && ls /etc/apt/sources.list.d/*.sources &>/dev/null 2>&1; then
                    echo ""
                    echo -e "${BOLD}--- sources.list.d/ (.sources 格式) ---${NC}"
                    for f in /etc/apt/sources.list.d/*.sources; do
                        echo -e "${CYAN}[$f]${NC}"
                        cat "$f"
                        echo ""
                    done
                fi
                press_enter
                ;;
            2)
                echo ""
                _backup_sources
                msg_info "正在切换到清华源..."
                cat > "$SOURCES_LIST" << TUNA_EOF
# 清华大学开源软件镜像站 - 由 CDN 屏蔽工具自动生成
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ ${codename} main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ ${codename}-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ ${codename}-backports main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security ${codename}-security main contrib non-free non-free-firmware
TUNA_EOF
                # 同时禁用 DEB822 格式的默认源，防止冲突
                _disable_deb822_sources
                msg_ok "已切换到清华源"
                msg_info "正在更新索引..."
                apt update 2>&1 | tail -3
                press_enter
                ;;
            3)
                echo ""
                _backup_sources
                msg_info "正在切换到 Debian 美国直连镜像..."
                cat > "$SOURCES_LIST" << US_EOF
# Debian 美国镜像 (不走 CDN) - 由 CDN 屏蔽工具自动生成
deb http://ftp.us.debian.org/debian/ ${codename} main contrib non-free non-free-firmware
deb http://ftp.us.debian.org/debian/ ${codename}-updates main contrib non-free non-free-firmware
deb http://ftp.us.debian.org/debian/ ${codename}-backports main contrib non-free non-free-firmware
deb http://ftp.us.debian.org/debian-security ${codename}-security main contrib non-free non-free-firmware
US_EOF
                _disable_deb822_sources
                msg_ok "已切换到 Debian 美国直连镜像"
                msg_info "正在更新索引..."
                apt update 2>&1 | tail -3
                press_enter
                ;;
            4)
                echo ""
                _backup_sources
                msg_info "正在恢复到默认源 (deb.debian.org)..."
                cat > "$SOURCES_LIST" << DEFAULT_EOF
# Debian 默认源 (CDN 加速) - 由 CDN 屏蔽工具自动生成
deb http://deb.debian.org/debian/ ${codename} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ ${codename}-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ ${codename}-backports main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security ${codename}-security main contrib non-free non-free-firmware
DEFAULT_EOF
                _restore_deb822_sources
                msg_ok "已恢复到默认源"
                msg_warn "注意: 如果 CDN 屏蔽已启用，apt update 可能会失败！"
                press_enter
                ;;
            5)
                echo ""
                if [[ -f "$SOURCES_BACKUP" ]]; then
                    cp "$SOURCES_BACKUP" "$SOURCES_LIST"
                    _restore_deb822_sources
                    msg_ok "已从备份恢复 sources.list"
                else
                    msg_err "未找到备份文件: $SOURCES_BACKUP"
                fi
                press_enter
                ;;
            0)
                return
                ;;
            *)
                msg_err "无效选择"
                ;;
        esac
    done
}

# 备份 sources.list（仅首次）
_backup_sources() {
    if [[ ! -f "$SOURCES_BACKUP" ]] && [[ -f "$SOURCES_LIST" ]]; then
        cp "$SOURCES_LIST" "$SOURCES_BACKUP"
        msg_info "已备份当前 sources.list → ${SOURCES_BACKUP}"
    fi
}

# 禁用 DEB822 格式的默认源文件（防止与 sources.list 冲突）
_disable_deb822_sources() {
    if [[ -d /etc/apt/sources.list.d/ ]]; then
        for f in /etc/apt/sources.list.d/*.sources; do
            [[ -f "$f" ]] || continue
            if [[ ! -f "${f}.disabled" ]]; then
                mv "$f" "${f}.disabled"
                msg_info "已禁用 DEB822 源: $(basename "$f")"
            fi
        done
    fi
}

# 恢复 DEB822 格式的默认源文件
_restore_deb822_sources() {
    if [[ -d /etc/apt/sources.list.d/ ]]; then
        for f in /etc/apt/sources.list.d/*.sources.disabled; do
            [[ -f "$f" ]] || continue
            local original="${f%.disabled}"
            mv "$f" "$original"
            msg_info "已恢复 DEB822 源: $(basename "$original")"
        done
    fi
}

# 10. 完全卸载
do_uninstall() {
    echo ""
    echo -e "${RED}${BOLD}⚠️  警告: 此操作将完全卸载 CDN 屏蔽工具${NC}"
    echo "  - 清除所有 iptables/ipset 规则"
    echo "  - 移除 systemd 开机自启服务"
    echo "  - 移除流量监控 cron 任务和数据"
    echo "  - 恢复 apt 源（如有备份）"
    echo "  - 删除脚本文件自身"
    echo ""
    read -rp "确认要完全卸载吗？输入 YES 确认: " confirm
    if [[ "$confirm" != "YES" ]]; then
        msg_info "已取消卸载"
        press_enter
        return
    fi

    echo ""

    # 1. 清除运行时规则
    msg_info "正在清除屏蔽规则..."
    unload_all_rules
    msg_ok "屏蔽规则已清除"

    # 2. 移除 systemd service
    if [[ -f "$SERVICE_FILE" ]]; then
        msg_info "正在移除 systemd 服务..."
        systemctl stop "$SERVICE_NAME" &>/dev/null
        systemctl disable "$SERVICE_NAME" &>/dev/null
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        msg_ok "systemd 服务已移除"
    fi

    # 3. 恢复 apt 源
    if [[ -f "$SOURCES_BACKUP" ]]; then
        msg_info "正在恢复 apt 源..."
        cp "$SOURCES_BACKUP" "$SOURCES_LIST"
        rm -f "$SOURCES_BACKUP"
        _restore_deb822_sources
        msg_ok "apt 源已恢复"
    fi

    # 4. 移除流量监控 cron
    remove_traffic_cron
    msg_ok "cron 任务已移除"

    # 5. 清理流量数据
    if [[ -d "$TRAFFIC_DIR" ]]; then
        rm -rf "$TRAFFIC_DIR"
        msg_ok "流量数据已清理"
    fi

    # 6. 删除脚本自身
    msg_info "正在删除脚本文件..."
    rm -f "$SCRIPT_PATH"
    msg_ok "脚本已删除: $SCRIPT_PATH"

    echo ""
    msg_ok "CDN 屏蔽工具已完全卸载！"
    exit 0
}

# ============================================================
# 流量监控功能
# ============================================================

# 自动检测主网络接口（排除 lo、docker、veth 等）
detect_interface() {
    local iface
    # 优先选择默认路由的接口
    iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
    if [[ -n "$iface" ]]; then
        echo "$iface"
        return
    fi
    # 回退：选择第一个非 lo 接口
    iface=$(ip -o link show up 2>/dev/null | awk -F': ' '!/lo|docker|veth|br-/{print $2; exit}')
    echo "${iface:-eth0}"
}

# 确保流量数据目录存在
_ensure_traffic_dir() {
    mkdir -p "$TRAFFIC_DIR"
}

# 读取接口当前出站字节数（TX bytes 是 /proc/net/dev 第 10 个字段）
_get_tx_bytes() {
    local iface="$1"
    local tx_bytes
    # /proc/net/dev 格式: iface: rx_bytes ... tx_bytes ...
    # 接口名后紧跟冒号，TX bytes 固定为第 10 列
    tx_bytes=$(awk -v dev="${iface}:" '$1==dev {print $10}' /proc/net/dev 2>/dev/null)
    # 兜底：如果接口名和冒号之间有空格
    if [[ -z "$tx_bytes" ]]; then
        tx_bytes=$(grep "${iface}:" /proc/net/dev 2>/dev/null | awk '{print $10}')
    fi
    echo "${tx_bytes:-0}"
}

# 字节数转可读格式
_bytes_to_human() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        awk "BEGIN {printf \"%.2f GB\", $bytes/1073741824}"
    elif [[ $bytes -ge 1048576 ]]; then
        awk "BEGIN {printf \"%.2f MB\", $bytes/1048576}"
    elif [[ $bytes -ge 1024 ]]; then
        awk "BEGIN {printf \"%.2f KB\", $bytes/1024}"
    else
        echo "${bytes} B"
    fi
}

# 更新流量统计（核心追踪逻辑）
update_traffic() {
    _ensure_traffic_dir
    local iface
    iface=$(detect_interface)
    local current_tx
    current_tx=$(_get_tx_bytes "$iface")
    local current_month
    current_month=$(date +"%Y-%m")

    # 读取已保存的状态
    local saved_iface="" saved_month="" saved_last_tx="0" saved_accumulated="0"
    if [[ -f "$TRAFFIC_STATE" ]]; then
        while IFS='=' read -r key value; do
            key=$(echo "$key" | tr -d '\r' | xargs)
            value=$(echo "$value" | tr -d '\r' | xargs)
            case "$key" in
                INTERFACE)   saved_iface="$value" ;;
                MONTH)       saved_month="$value" ;;
                LAST_TX)     saved_last_tx="$value" ;;
                ACCUMULATED) saved_accumulated="$value" ;;
            esac
        done < "$TRAFFIC_STATE"
    fi

    # 月份切换 → 归档旧数据并重置
    if [[ "$current_month" != "$saved_month" ]] && [[ -n "$saved_month" ]]; then
        # 归档上月数据
        echo "${saved_month} ${saved_accumulated}" >> "$TRAFFIC_HISTORY"
        # 清理超过 3 个月的历史记录
        _cleanup_history
        # 重置
        saved_accumulated=0
        saved_last_tx=0
    fi

    # 计算增量
    local delta=0
    if [[ "$iface" == "$saved_iface" ]] && [[ $saved_last_tx -gt 0 ]]; then
        if [[ $current_tx -ge $saved_last_tx ]]; then
            # 正常情况：计数器增长
            delta=$((current_tx - saved_last_tx))
        else
            # 计数器回绕或重启：当前值作为增量
            delta=$current_tx
        fi
    elif [[ $saved_last_tx -eq 0 ]]; then
        # 首次记录，不计增量，仅保存基线
        delta=0
    else
        # 接口切换，当前值作为增量
        delta=$current_tx
    fi

    saved_accumulated=$((saved_accumulated + delta))

    # 保存状态
    cat > "$TRAFFIC_STATE" << STATE_EOF
INTERFACE=${iface}
MONTH=${current_month}
LAST_TX=${current_tx}
ACCUMULATED=${saved_accumulated}
STATE_EOF
}

# 获取当前月累计出站字节数
get_accumulated_bytes() {
    if [[ -f "$TRAFFIC_STATE" ]]; then
        local acc
        acc=$(grep '^ACCUMULATED=' "$TRAFFIC_STATE" 2>/dev/null | cut -d'=' -f2 | tr -d '\r' | xargs)
        echo "${acc:-0}"
    else
        echo "0"
    fi
}

# 清理超过 3 个月的历史记录
_cleanup_history() {
    [[ -f "$TRAFFIC_HISTORY" ]] || return
    local cutoff_month
    cutoff_month=$(date -d "3 months ago" +"%Y-%m" 2>/dev/null || date +"%Y-%m")
    local tmpfile="${TRAFFIC_HISTORY}.tmp"
    while IFS=' ' read -r month bytes; do
        [[ -z "$month" ]] && continue
        if [[ "$month" > "$cutoff_month" ]] || [[ "$month" == "$cutoff_month" ]]; then
            echo "$month $bytes"
        fi
    done < "$TRAFFIC_HISTORY" > "$tmpfile"
    mv "$tmpfile" "$TRAFFIC_HISTORY"
}

# 强制重置当月流量（供 cron 调用）
reset_traffic() {
    _ensure_traffic_dir
    # 归档当前月
    if [[ -f "$TRAFFIC_STATE" ]]; then
        local saved_month saved_accumulated
        saved_month=$(grep '^MONTH=' "$TRAFFIC_STATE" 2>/dev/null | cut -d'=' -f2 | tr -d '\r' | xargs)
        saved_accumulated=$(grep '^ACCUMULATED=' "$TRAFFIC_STATE" 2>/dev/null | cut -d'=' -f2 | tr -d '\r' | xargs)
        if [[ -n "$saved_month" ]] && [[ "${saved_accumulated:-0}" -gt 0 ]]; then
            echo "${saved_month} ${saved_accumulated}" >> "$TRAFFIC_HISTORY"
            _cleanup_history
        fi
    fi
    # 重置状态
    local iface
    iface=$(detect_interface)
    local current_tx
    current_tx=$(_get_tx_bytes "$iface")
    cat > "$TRAFFIC_STATE" << STATE_EOF
INTERFACE=${iface}
MONTH=$(date +"%Y-%m")
LAST_TX=${current_tx}
ACCUMULATED=0
STATE_EOF
    msg_ok "流量已重置"
}

# 绘制进度条
_draw_progress_bar() {
    local accumulated=$1
    local limit=$2
    local bar_width=30

    # 防止除零和无效输入
    [[ -z "$accumulated" ]] && accumulated=0
    [[ -z "$limit" || "$limit" -le 0 ]] 2>/dev/null && limit=1

    # 计算百分比
    local percent
    percent=$(awk "BEGIN {printf \"%.1f\", ($accumulated/$limit)*100}")
    local percent_int
    percent_int=$(awk "BEGIN {v=($accumulated/$limit)*100; printf \"%d\", (v>100?100:v)}")

    # 计算填充长度
    local filled=$((percent_int * bar_width / 100))
    local empty=$((bar_width - filled))

    # 选择颜色：<60% 绿色, 60-85% 黄色, >85% 红色
    local bar_color
    if [[ $percent_int -lt 60 ]]; then
        bar_color="$GREEN"
    elif [[ $percent_int -lt 85 ]]; then
        bar_color="$YELLOW"
    else
        bar_color="$RED"
    fi

    # 构建进度条
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    local used_human
    used_human=$(_bytes_to_human "$accumulated")

    echo -e "  📊 本月流量: ${bar_color}[${bar}]${NC} ${used_human} / ${TRAFFIC_LIMIT_GB} GB (${percent}%)"

    # 超限警告
    if [[ $percent_int -ge 90 ]]; then
        echo -e "  ${RED}${BOLD}⚠️  流量即将耗尽，请注意控制用量！${NC}"
    fi
}

# 安装流量监控 cron 任务
install_traffic_cron() {
    # 每 5 分钟更新流量统计
    local cron_update="*/5 * * * * ${SCRIPT_PATH} --update-traffic  # ${CRON_TAG}"
    # 每月 1 号 0 点重置
    local cron_reset="0 0 1 * * ${SCRIPT_PATH} --reset-traffic  # ${CRON_TAG}"

    # 移除旧的 cron 条目
    remove_traffic_cron

    # 添加新条目
    (crontab -l 2>/dev/null; echo "$cron_update"; echo "$cron_reset") | crontab -
    msg_info "已安装流量监控 cron 任务（每 5 分钟更新，每月 1 号重置）"
}

# 移除流量监控 cron 任务
remove_traffic_cron() {
    if crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
        crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab -
    fi
}

# 11. 流量记录菜单
do_traffic_history() {
    while true; do
        echo ""
        echo -e "${BOLD}========== 流量记录 ==========${NC}"
        echo ""

        # 更新一次流量
        update_traffic

        # 当前月统计
        local iface
        iface=$(detect_interface)
        local accumulated
        accumulated=$(get_accumulated_bytes)
        local used_human
        used_human=$(_bytes_to_human "$accumulated")
        local current_month
        current_month=$(date +"%Y-%m")

        echo -e "  ${BOLD}当前月份:${NC} ${CYAN}${current_month}${NC}"
        echo -e "  ${BOLD}监控接口:${NC} ${CYAN}${iface}${NC}"
        echo -e "  ${BOLD}已用流量:${NC} ${used_human} / ${TRAFFIC_LIMIT_GB} GB"
        _draw_progress_bar "$accumulated" "$TRAFFIC_LIMIT_BYTES"
        echo ""

        # 历史记录
        echo -e "  ${BOLD}── 历史记录（最近 3 个月）──${NC}"
        if [[ -f "$TRAFFIC_HISTORY" ]] && [[ -s "$TRAFFIC_HISTORY" ]]; then
            echo -e "  ${CYAN}月份          出站流量${NC}"
            echo "  ─────────────────────────"
            while IFS=' ' read -r month bytes; do
                [[ -z "$month" ]] && continue
                local h_bytes
                h_bytes=$(_bytes_to_human "$bytes")
                printf "  %-14s %s\n" "$month" "$h_bytes"
            done < "$TRAFFIC_HISTORY"
        else
            echo "  (暂无历史记录)"
        fi

        echo ""
        echo "  ${BOLD}── 操作 ──${NC}"
        echo "  1) 刷新"
        echo "  2) 手动重置当月流量"
        echo "  0) 返回主菜单"
        echo ""
        read -rp "  请选择 [0-2]: " tc

        case "$tc" in
            1) continue ;;
            2)
                echo ""
                read -rp "  确认重置当月流量记录？(y/N): " rc
                if [[ "$rc" == "y" || "$rc" == "Y" ]]; then
                    reset_traffic
                fi
                ;;
            0) return ;;
            *) msg_err "无效选择" ;;
        esac
    done
}

# 12. 测试屏蔽效果
do_test_block() {
    echo ""
    echo -e "${BOLD}========== 屏蔽效果测试 ==========${NC}"
    echo ""

    if ! is_rules_active; then
        msg_warn "CDN 屏蔽规则当前未启用，测试结果将显示未屏蔽状态"
        echo ""
    fi

    # 测试目标：每个 CDN 取一个代表性 IP
    local -a test_targets=(
        "Cloudflare|1.1.1.1|104.16.132.229"
        "Fastly|151.101.1.6|151.101.65.6"
        "Akamai|23.192.0.1|23.72.0.1"
    )

    echo -e "  ${BOLD}测试方式:${NC} 尝试向 CDN IP 发起连接，超时 3 秒则视为屏蔽生效"
    echo ""
    printf "  ${CYAN}%-14s %-18s %-10s %s${NC}\n" "CDN 提供商" "测试 IP" "类型" "结果"
    echo "  ────────────────────────────────────────────────────────"

    local total_tests=0
    local blocked_count=0

    for entry in "${test_targets[@]}"; do
        IFS='|' read -r cdn_name ip1 ip2 <<< "$entry"

        for test_ip in $ip1 $ip2; do
            total_tests=$((total_tests + 1))

            # Ping 测试
            local ping_result
            if ping -c 1 -W 3 "$test_ip" &>/dev/null; then
                ping_result="${RED}✘ 未屏蔽${NC}"
            else
                ping_result="${GREEN}✔ 已屏蔽${NC}"
                blocked_count=$((blocked_count + 1))
            fi
            printf "  %-14s %-18s %-10s %b\n" "$cdn_name" "$test_ip" "Ping" "$ping_result"
        done
    done

    # 还可以做一个 HTTP 测试
    echo ""
    echo -e "  ${BOLD}HTTP 连接测试:${NC}"
    echo "  ────────────────────────────────────────────────────────"

    local -a http_targets=(
        "Cloudflare|http://1.1.1.1"
        "Fastly|http://151.101.1.6"
    )

    for entry in "${http_targets[@]}"; do
        IFS='|' read -r cdn_name url <<< "$entry"
        total_tests=$((total_tests + 1))
        local http_result
        if curl -sf --connect-timeout 3 --max-time 5 -o /dev/null "$url" 2>/dev/null; then
            http_result="${RED}✘ 未屏蔽${NC}"
        else
            http_result="${GREEN}✔ 已屏蔽${NC}"
            blocked_count=$((blocked_count + 1))
        fi
        printf "  %-14s %-18s %-10s %b\n" "$cdn_name" "$url" "HTTP" "$http_result"
    done

    # 汇总
    echo ""
    echo "  ────────────────────────────────────────────────────────"
    if [[ $blocked_count -eq $total_tests ]]; then
        echo -e "  ${GREEN}${BOLD}✔ 全部屏蔽生效 (${blocked_count}/${total_tests})${NC}"
    elif [[ $blocked_count -gt 0 ]]; then
        echo -e "  ${YELLOW}${BOLD}⚠ 部分屏蔽生效 (${blocked_count}/${total_tests})${NC}"
    else
        echo -e "  ${RED}${BOLD}✘ 屏蔽未生效 (${blocked_count}/${total_tests})${NC}"
    fi

    # 自定义测试
    echo ""
    read -rp "  要测试自定义 IP 吗？输入 IP 或按 Enter 跳过: " custom_ip
    custom_ip=$(echo "$custom_ip" | tr -d '\r' | xargs)
    if [[ -n "$custom_ip" ]]; then
        echo ""
        echo -n "  Ping ${custom_ip}: "
        if ping -c 1 -W 3 "$custom_ip" &>/dev/null; then
            echo -e "${RED}✘ 未屏蔽${NC}"
        else
            echo -e "${GREEN}✔ 已屏蔽${NC}"
        fi

        if command -v curl &>/dev/null; then
            echo -n "  HTTP ${custom_ip}: "
            if curl -sf --connect-timeout 3 --max-time 5 -o /dev/null "http://${custom_ip}" 2>/dev/null; then
                echo -e "${RED}✘ 未屏蔽${NC}"
            else
                echo -e "${GREEN}✔ 已屏蔽${NC}"
            fi
        fi
    fi

    press_enter
}

# ============================================================
# 非交互模式（供 systemd / cron 调用）
# ============================================================
if [[ "${1:-}" == "--apply" ]]; then
    check_root
    check_deps
    load_all_rules
    msg_ok "CDN 屏蔽规则已加载（systemd 调用）"
    exit 0
fi

if [[ "${1:-}" == "--remove" ]]; then
    check_root
    check_deps
    unload_all_rules
    msg_ok "CDN 屏蔽规则已卸载（systemd 调用）"
    exit 0
fi

if [[ "${1:-}" == "--update-traffic" ]]; then
    _ensure_traffic_dir
    update_traffic
    exit 0
fi

if [[ "${1:-}" == "--reset-traffic" ]]; then
    _ensure_traffic_dir
    reset_traffic
    exit 0
fi

# ============================================================
# 主菜单
# ============================================================
main_menu() {
    check_root
    check_deps

    while true; do
        clear
        echo -e "${BOLD}${CYAN}"
        echo "  ╔══════════════════════════════════════╗"
        echo "  ║       CDN 屏蔽管理工具 v3.0          ║"
        echo "  ║   GCP 免费服务器 CDN 流量屏蔽方案    ║"
        echo "  ╚══════════════════════════════════════╝"
        echo -e "${NC}"

        # 显示当前状态概要
        echo -n "  当前状态: "
        if is_rules_active; then
            echo -e "${GREEN}● 屏蔽已启用${NC}"
        else
            echo -e "${RED}● 屏蔽未启用${NC}"
        fi
        echo -n "  开机自启: "
        if is_service_enabled 2>/dev/null; then
            echo -e "${GREEN}● 已设置${NC}"
        else
            echo -e "${RED}● 未设置${NC}"
        fi
        echo ""

        # 流量进度条
        update_traffic
        local _acc
        _acc=$(get_accumulated_bytes)
        _draw_progress_bar "$_acc" "$TRAFFIC_LIMIT_BYTES"
        echo ""

        echo -e "  ${BOLD}── 屏蔽控制 ──${NC}"
        echo "  1) 临时启用 CDN 屏蔽   (重启后失效)"
        echo "  2) 临时停用 CDN 屏蔽   (重启后恢复)"
        echo "  3) 永久启用 CDN 屏蔽   (开机自动生效)"
        echo "  4) 永久停用 CDN 屏蔽   (移除开机自启)"
        echo ""
        echo -e "  ${BOLD}── 信息查看 ──${NC}"
        echo "  5) 查看屏蔽状态"
        echo "  6) 查看屏蔽 IP 列表"
        echo ""
        echo -e "  ${BOLD}── IP 管理 ──${NC}"
        echo "  7) 添加自定义 IP 段"
        echo "  8) 删除指定 IP 段"
        echo ""
        echo -e "  ${BOLD}── 流量监控 ──${NC}"
        echo " 11) 流量记录"
        echo ""
        echo -e "  ${BOLD}── 诊断工具 ──${NC}"
        echo " 12) 测试屏蔽效果"
        echo ""
        echo -e "  ${BOLD}── 系统设置 ──${NC}"
        echo "  9) APT 换源管理"
        echo " 10) 完全卸载"
        echo ""
        echo "  0) 退出"
        echo ""
        echo -e "  ${BOLD}==============================${NC}"
        echo ""
        read -rp "  请选择 [0-12]: " choice

        case "$choice" in
            1)  do_temp_enable ;;
            2)  do_temp_disable ;;
            3)  do_permanent_enable ;;
            4)  do_permanent_disable ;;
            5)  do_show_status ;;
            6)  do_show_ips ;;
            7)  do_add_ip ;;
            8)  do_del_ip ;;
            9)  do_apt_source ;;
            10) do_uninstall ;;
            11) do_traffic_history ;;
            12) do_test_block ;;
            0)
                echo ""
                msg_info "再见！"
                exit 0
                ;;
            *)
                msg_err "无效选择，请重新输入"
                sleep 1
                ;;
        esac
    done
}

# 启动主菜单
main_menu
