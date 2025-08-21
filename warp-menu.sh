#!/bin/bash
# 智能 WARP 安装 + 自动注册 + 启动脚本
# 支持纯 IPv6 VPS

set -e

WGCF_BIN="/usr/local/bin/wgcf"
WGCF_CONF="/etc/wireguard/wgcf.conf"

install_dependencies() {
    echo ">>> 安装依赖..."
    apt update && apt install -y curl wget net-tools iproute2 wireguard-tools
}

install_wgcf() {
    if [ ! -f "$WGCF_BIN" ]; then
        echo ">>> 下载 wgcf..."
        wget -O $WGCF_BIN https://github.com/ViRb3/wgcf/releases/download/v2.3.0/wgcf_2.3.0_linux_amd64
        chmod +x $WGCF_BIN
    fi
}

generate_config() {
    echo ">>> 生成配置..."
    wgcf generate
    mv wgcf-profile.conf /etc/wireguard/wgcf.conf
}

register_warp() {
    rm -f wgcf-account.toml wgcf-profile.conf
    max_retries=5
    count=0
    success=0
    while [ $count -lt $max_retries ]; do
        echo ">>> 尝试注册 WARP (第 $((count+1)) 次)..."
        if yes | wgcf register >/dev/null 2>&1; then
            generate_config
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

start_warp() {
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null
    wg-quick up wgcf
    systemctl enable wg-quick@wgcf
    echo ">>> WARP 已启动并开机自启"
}

check_status() {
    echo ">>> 当前 WARP 状态："
    ip a show wgcf >/dev/null 2>&1 && echo "✅ wgcf 已运行" || echo "❌ wgcf 未运行"
    echo -n "IPv4: "; curl -s4 ip.p3terx.com || echo "无"
    echo -n "IPv6: "; curl -s6 ip.p3terx.com || echo "无"
}

# 主流程
install_dependencies
install_wgcf

if [ -f "wgcf-account.toml" ]; then
    echo ">>> 检测到已有 WARP 账户，使用现有账户生成配置"
    generate_config
else
    register_warp
fi

start_warp
check_status
