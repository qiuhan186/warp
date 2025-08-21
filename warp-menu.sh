#!/bin/bash
# WARP 管理菜单 (适配 IPv6-only VPS 强制 IPv4)
# 2025 by ChatGPT

CONF="/etc/wireguard/warp.conf"

fix_ipv4() {
    echo ">>> 检查并修复 IPv4 设置..."
    if ! grep -q "172.16.0." $CONF; then
        echo "未检测到 IPv4 地址，添加 172.16.0.2/32..."
        sed -i '/^\[Interface\]/a Address = 172.16.0.2/32,' $CONF
    fi
    sed -i 's#AllowedIPs = ::/0#AllowedIPs = 0.0.0.0/0, ::/0#g' $CONF
    if ! grep -q "PostUp" $CONF; then
cat >> $CONF <<EOF
PostUp = ip addr add 172.16.0.2/32 dev %i; ip -4 route add default dev %i
PostDown = ip addr del 172.16.0.2/32 dev %i; ip -4 route del default dev %i
EOF
    fi
    echo "修复完成 ✅"
}

install_warp() {
    echo ">>> 安装依赖并下载 wgcf..."
    apt update -y || yum makecache fast
    apt install -y curl wget sudo net-tools iproute2 wireguard-tools || yum install -y curl wget sudo net-tools iproute iptables wireguard-tools
    WGCF_VER=$(curl -s https://api.github.com/repos/ViRb3/wgcf/releases/latest | grep tag_name | cut -d '"' -f4)
    wget -O /usr/local/bin/wgcf https://github.com/ViRb3/wgcf/releases/download/$WGCF_VER/wgcf_$(echo $WGCF_VER | tr -d v)_linux_amd64
    chmod +x /usr/local/bin/wgcf

    if [ ! -f wgcf-account.toml ]; then
        yes | wgcf register
    fi
    wgcf generate
    mkdir -p /etc/wireguard
    cp wgcf-profile.conf $CONF
    fix_ipv4
    systemctl enable wg-quick@warp
    wg-quick up warp
    echo "WARP 安装完成 ✅"
}

show_status() {
    echo ">>> 当前 WARP 状态:"
    wg show warp || echo "未运行"
    echo "IPv4 出口: $(curl -s -4 ip.gs || echo FAIL)"
    echo "IPv6 出口: $(curl -s -6 ip.gs || echo FAIL)"
}

restart_warp() {
    wg-quick down warp 2>/dev/null || true
    wg-quick up warp
    echo "WARP 已重启 ✅"
    show_status
}

change_endpoint() {
    echo ">>> 切换 Endpoint..."
    read -p "请输入新的 Endpoint (例如 [2606:4700:d0::a29f:c001]:2408): " ep
    sed -i "s#Endpoint = .*#Endpoint = $ep#g" $CONF
    restart_warp
}

menu() {
    clear
    echo "============================"
    echo "    Cloudflare WARP 管理菜单"
    echo "============================"
    echo "1. 安装 WARP"
    echo "2. 查看状态"
    echo "3. 重启 WARP"
    echo "4. 修复 IPv4 出口"
    echo "5. 切换 Endpoint 节点"
    echo "0. 退出"
    echo "============================"
    read -p "请选择: " choice

    case $choice in
        1) install_warp ;;
        2) show_status ;;
        3) restart_warp ;;
        4) fix_ipv4 && restart_warp ;;
        5) change_endpoint ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
}

while true; do
    menu
    read -p "按回车继续..."
done
