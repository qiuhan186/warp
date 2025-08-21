#!/bin/bash
#
# WARP 一键菜单脚本 (简化版)
# 适合纯 IPv6 VPS 获取 WARP IPv4
#

show_menu() {
  clear
  echo "============================"
  echo "   WARP 管理菜单"
  echo "============================"
  echo "1. 安装依赖 & WARP"
  echo "2. 注册 WARP 账户"
  echo "3. 启用 WARP (获取 IPv4)"
  echo "4. 查看当前 IP"
  echo "5. 卸载 WARP"
  echo "6. 退出"
  echo "============================"
}

install_warp() {
  echo ">>> 安装依赖..."
  apt update && apt install -y curl wget net-tools iproute2 wireguard-tools
  echo ">>> 下载 wgcf..."
  wget -O /usr/local/bin/wgcf https://github.com/ViRb3/wgcf/releases/download/v2.2.20/wgcf_2.2.20_linux_amd64
  chmod +x /usr/local/bin/wgcf
  echo ">>> 安装完成！"
}

register_warp() {
  echo ">>> 注册 WARP 账户..."
  yes | wgcf register
  wgcf generate
  mv wgcf-profile.conf /etc/wireguard/wgcf.conf
  echo ">>> 注册成功！配置已生成：/etc/wireguard/wgcf.conf"
}

enable_warp() {
  echo ">>> 启用 WARP..."
  sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null
  wg-quick up wgcf
  echo ">>> WARP 已启动！"
}

check_ip() {
  echo ">>> 当前出口 IP："
  echo -n "IPv4: "
  curl -s4 ip.p3terx.com || echo "无 IPv4"
  echo -n "IPv6: "
  curl -s6 ip.p3terx.com || echo "无 IPv6"
}

uninstall_warp() {
  echo ">>> 卸载 WARP..."
  wg-quick down wgcf 2>/dev/null
  rm -f /etc/wireguard/wgcf.conf
  rm -f wgcf-account.toml
  rm -f /usr/local/bin/wgcf
  echo ">>> 卸载完成！"
}

# 主循环
while true; do
  show_menu
  read -p "请输入选项 [1-6]: " choice
  case "$choice" in
    1) install_warp ;;
    2) register_warp ;;
    3) enable_warp ;;
    4) check_ip ;;
    5) uninstall_warp ;;
    6) echo "退出"; exit 0 ;;
    *) echo "无效选项，请重新输入";;
  esac
  read -p "按回车键继续..." 
done
