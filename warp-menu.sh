#!/bin/bash
# 一键安装 + 自动注册 WARP + 管理菜单
# 适合放 GitHub 上使用

set -e

WGCF_BIN="/usr/local/bin/wgcf"
WGCF_CONF="/etc/wireguard/wgcf.conf"

# 安装依赖
install_dependencies() {
    echo ">>> 安装依赖..."
    apt update && apt install -y curl wget net-tools iproute2 wireguard-tools
}

# 下载 wgcf
install_wgcf() {
    if [ ! -f "$WGCF_BIN" ]; then
        echo ">>> 下载 wgcf..."
        wget -O $WGCF_BIN https://github.com/ViRb3/wgcf/releases/download/v2.3.0/wgcf_2.3.0_linux_amd64
        chmod +x $WGCF_BIN
    fi
}

# 自动注册 WARP
register_warp() {
    rm -f wgcf-account.toml wgcf-profile.conf
    max_retries=5
    count=0
    success=0
    while [ $count -lt $max_retries ]; do
        echo ">>> 尝试注册 WARP (第 $((count+1)) 次)..."
        if yes | wgcf register >/dev/null 2>&1; then
            wgcf generate
            mv wgcf-profile.conf /etc/wireguard/wgcf.conf
            success=1
            echo ">>> 注册成功！配置已生成：/etc/wireguard/wgcf.conf"
            break
        else
            echo ">>> 注册失败，等待 10 秒后重试..."
            sleep 10
            count=$((count+1))
        fi
    done
    if [ $success -eq 0 ]; then
        echo "❌ 多次尝试仍未注册成功，请稍后再试"
        exit 1
    fi
}

# 启动 WARP
start_warp() {
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null
    wg-quick up wgcf
    systemctl enable wg-quick@wgcf
    echo ">>> WARP 已启动并开机自启"
    check_status
}

# 停止 WARP
stop_warp() {
    wg-quick down wgcf
    systemctl disable wg-quick@wgcf >/dev/null 2>&1
    echo ">>> WARP 已停止"
    check_status
}

# 重启 WARP
restart_warp() {
    wg-quick down wgcf 2>/dev/null || true
    wg-quick up wgcf
    echo ">>> WARP 已重启"
    check_status
}

# 卸载 WARP
uninstall_warp() {
    echo "⚠️ 正在卸载 WARP..."
    wg-quick down wgcf 2>/dev/null || true
    systemctl disable wg-quick@wgcf >/dev/null 2>&1
    rm -f /etc/wireguard/wgcf.conf /etc/wireguard/wgcf-account.toml
    apt-get remove --purge -y wireguard-tools wgcf >/dev/null 2>&1
    apt-get autoremove -y >/dev/null 2>&1
    echo "✅ WARP 已卸载完成"
}

# 查看状态
check_status() {
    if ip a show wgcf >/dev/null 2>&1; then
        echo "✅ WARP 已运行"
        echo -n "IPv4: "; curl -s4 ip.p3terx.com || echo "无"
        echo -n "IPv6: "; curl -s6 ip.p3terx.com || echo "无"
    else
        echo "❌ WARP 未运行"
    fi
}

# 菜单
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

# 主流程
if [ ! -f "$WGCF_CONF" ]; then
    install_dependencies
    install_wgcf
    register_warp
    start_warp
fi

while true; do
    menu
    echo
    read -p "按回车键继续..." enter
done
