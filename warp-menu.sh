
#!/bin/bash
# 一键安装 + WARP IPv4 管理菜单（纯 IPv6 VPS 适用）

set -e

WGCF_CONF="/etc/wireguard/wgcf.conf"

install_warp() {
    echo ">>> 安装依赖..."
    apt update && apt install -y curl wget net-tools iproute2 wireguard-tools

    echo ">>> 下载 wgcf..."
    WGCF_BIN="/usr/local/bin/wgcf"
    if [ ! -f "$WGCF_BIN" ]; then
        wget -O $WGCF_BIN https://github.com/ViRb3/wgcf/releases/download/v2.2.20/wgcf_2.2.20_linux_amd64
        chmod +x $WGCF_BIN
    fi

    echo ">>> 注册 WARP 账户..."
    yes | wgcf register
    wgcf generate
    mv wgcf-profile.conf /etc/wireguard/wgcf.conf

    echo ">>> 启用 WARP..."
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null
    wg-quick up wgcf
    systemctl enable wg-quick@wgcf
    echo ">>> WARP 安装并启用完成！"
}

check_status() {
    if ip a show wgcf >/dev/null 2>&1; then
        echo "✅ WARP 已运行"
        echo -n "IPv4: "; curl -s4 ip.p3terx.com || echo "无"
        echo -n "IPv6: "; curl -s6 ip.p3terx.com || echo "无"
    else
        echo "❌ WARP 未运行"
    fi
}

start_warp() {
    wg-quick up wgcf && systemctl enable wg-quick@wgcf
    echo ">>> WARP 已启动并开机自启"
    check_status
}

stop_warp() {
    wg-quick down wgcf
    systemctl disable wg-quick@wgcf >/dev/null 2>&1
    echo ">>> WARP 已停止"
    check_status
}

restart_warp() {
    wg-quick down wgcf 2>/dev/null || true
    wg-quick up wgcf
    echo ">>> WARP 已重启"
    check_status
}

uninstall_warp() {
    echo "⚠️ 正在卸载 WARP..."
    wg-quick down wgcf 2>/dev/null || true
    systemctl disable wg-quick@wgcf >/dev/null 2>&1
    rm -f /etc/wireguard/wgcf.conf /etc/wireguard/wgcf-account.toml
    apt-get remove --purge -y wireguard-tools wgcf >/dev/null 2>&1
    apt-get autoremove -y >/dev/null 2>&1
    echo "✅ WARP 已卸载完成"
}

# 如果没安装，自动安装
if [ ! -f "$WGCF_CONF" ]; then
    install_warp
fi

# 主菜单
menu() {
    clear
    echo "=========== WARP IPv4 管理菜单 ==========="
    echo "1. 查看 WARP 状态"
    echo "2. 启动 WARP"
    echo "3. 停止 WARP"
    echo "4. 重启 WARP"
    echo "5. 卸载 WARP"
    echo "0. 退出"
    echo "========================================="
    read -p "请输入选项: " choice
    case $choice in
        1) check_status ;;
        2) start_warp ;;
        3) stop_warp ;;
        4) restart_warp ;;
        5) uninstall_warp ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
}

# 循环显示菜单
while true; do
    menu
    echo
    read -p "按回车键继续..." enter
done
