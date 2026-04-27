#!/bin/bash

#系统信息
unset machine
unset release
unset systemVersion
unset apt
unset apt_no_install_recommends
unset cpu_thread_num
unset timezone
unset ssh_service

#安装配置信息
nginx_prefix="/etc/nginx"
nginx_config="/etc/nginx/conf.d/xray.conf"
nginx_service="nginx"
nginx_is_installed=""

xray_config="/usr/local/etc/xray/config.json"
unset xray_is_installed

temp_dir="/temp_install_update_xray_tls_web"
unset is_installed

#连接配置信息
unset domain_list
unset true_domain_list

unset xid_1

using_swap_now=0
unset update
in_install_update_xray_tls_web=0

#颜色函数
purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }
blue() { echo -e "\\033[34;1m${*}\\033[0m"; }

#检查基本命令
check_base_command()
{
    hash -r
    local i
    local temp_command_list=('bash' 'sh' 'command' 'type' 'hash' 'install' 'true' 'false' 'exit' 'echo' 'test' 'sort' 'sed' 'awk' 'grep' 'cut' 'cd' 'rm' 'cp' 'mv' 'head' 'tail' 'uname' 'tr' 'md5sum' 'cat' 'find' 'wc' 'ls' 'mktemp' 'chmod' 'chown' 'mkdir' 'systemctl' 'ss')
    for i in "${temp_command_list[@]}"
    do
        if ! command -V "${i}" > /dev/null; then
            red "命令\"${i}\"未找到"
            red "不是标准的Linux系统"
            exit 1
        fi
    done
}

check_sudo()
{
    if [ "$SUDO_GID" ] && [ "$SUDO_COMMAND" ] && [ "$SUDO_USER" ] && [ "$SUDO_UID" ]; then
        if [ "$SUDO_USER" = "root" ] && [ "$SUDO_UID" = "0" ]; then
            return 0
        fi
        if [ -n "$SUDO_COMMAND" ]; then
            echo "$SUDO_COMMAND" | grep -- "/bin/su\$" >/dev/null 2>&1 || echo "$SUDO_COMMAND" | grep -- "/bin/su " >/dev/null 2>&1 || grep "^$SUDO_COMMAND\$" /etc/shells >/dev/null 2>&1
            return $?
        fi
        return 1
    fi
    return 0
}

ask_if()
{
    local choice=""
    while [ "$choice" != "y" ] && [ "$choice" != "n" ]
    do
        tyblue "$1"
        read choice
    done
    [ $choice == y ] && return 0
    return 1
}

#卸载函数
remove_xray()
{
    if ! bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge 2>/dev/null; then
        systemctl stop xray 2>/dev/null
        systemctl disable xray 2>/dev/null
        rm -rf /usr/local/bin/xray
        rm -rf /usr/local/etc/xray
        rm -rf /etc/systemd/system/xray.service
        rm -rf /etc/systemd/system/xray@.service
        rm -rf /var/log/xray
        systemctl daemon-reload
    fi
    xray_is_installed=0
    is_installed=0
}

remove_nginx()
{
    systemctl stop nginx 2>/dev/null
    systemctl disable nginx 2>/dev/null
    apt-get -y --allow-change-held-packages purge nginx nginx-common 2>/dev/null
    rm -rf /etc/nginx
    nginx_is_installed=0
    is_installed=0
}

#获取配置信息
get_config_info()
{
    [ $is_installed -eq 0 ] && return
    if [ -f $xray_config ]; then
        xid_1="$(grep '"id"' $xray_config 2>/dev/null | head -n 1 | cut -d : -f 2 | cut -d \" -f 2)"
    fi
    if [ -f $nginx_config ]; then
        unset domain_list
        unset true_domain_list
        domain_list=($(grep "^#domain_list=" $nginx_config 2>/dev/null | cut -d = -f 2))
        true_domain_list=($(grep "^#true_domain_list=" $nginx_config 2>/dev/null | cut -d = -f 2))
    fi
}

#安装依赖
install_dependence()
{
    if ! $apt_no_install_recommends -y install "$@"; then
        $apt update
        $apt_no_install_recommends -y -f install
        if ! $apt_no_install_recommends -y install "$@"; then
            yellow "依赖安装失败！！"
            yellow "按回车键继续或者Ctrl+c退出"
            read -s
            return 1
        fi
    fi
    return 0
}

check_important_dependence_installed()
{
    if ! dpkg -s "$1" 2>/dev/null | grep -qi 'status[ '$'\t]*:[ '$'\t]*install[ '$'\t]*ok[ '$'\t]*installed[ '$'\t]*$'; then
        install_dependence "$1"
    fi
}

#安装NGINX
install_nginx()
{
    green "正在安装Nginx。。。"
    
    dpkg --configure -a 2>/dev/null
    
    if ! install_dependence nginx; then
        red "Nginx安装失败，尝试修复..."
        apt-get -y -f install
        dpkg --configure -a
        install_dependence nginx
    fi
    
    systemctl enable nginx
    systemctl stop nginx
    
    nginx_is_installed=1
    [ $xray_is_installed -eq 1 ] && is_installed=1 || is_installed=0
}

install_acme_dependence()
{
    green "正在安装acme.sh依赖。。。"
    install_dependence curl openssl cron socat
}

#安装Xray
install_update_xray()
{
    green "正在安装/更新Xray。。。。"
    if ! bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root --without-geodata --without-logfiles; then
        red "安装/更新Xray失败"
        yellow "按回车键继续或者按Ctrl+c终止"
        read -s
        return 1
    fi
    systemctl enable xray
    xray_is_installed=1
    [ $nginx_is_installed -eq 1 ] && is_installed=1 || is_installed=0
}

#获取证书 - 使用standalone模式
get_cert()
{
    green "正在获取 \"${domain_list[0]}\" 的域名证书"
    domains="-d ${domain_list[0]}"
    
    systemctl stop nginx 2>/dev/null
    
    if ! $HOME/.acme.sh/acme.sh --issue $domains --standalone -k ec-256 --force; then
        red "域名证书申请失败！"
        systemctl start nginx 2>/dev/null
        yellow "请检查："
        yellow "    1.域名是否解析正确"
        yellow "    2.防火墙80端口是否开放"
        return 1
    fi
    
    mkdir -p ${nginx_prefix}/certs
    if ! $HOME/.acme.sh/acme.sh --installcert $domains --key-file ${nginx_prefix}/certs/${domain_list[0]}.key --fullchain-file ${nginx_prefix}/certs/${domain_list[0]}.cer --ecc; then
        red "证书安装失败！"
        systemctl start nginx 2>/dev/null
        return 1
    fi
    
    systemctl start nginx 2>/dev/null
    
    return 0
}

#配置nginx - 监听unix socket，作为fallback返回403
config_nginx()
{
    mkdir -p ${nginx_prefix}/conf.d
    mkdir -p ${nginx_prefix}/certs
    mkdir -p /var/www/html
    mkdir -p /dev/shm/nginx
    chmod 755 /dev/shm/nginx
    
    rm -f /etc/nginx/sites-enabled/*
    rm -f /etc/nginx/sites-available/*
    rm -f ${nginx_config}
    
    # 创建xray.conf - nginx监听unix socket
    cat > $nginx_config <<EOF
server {
    listen unix:/dev/shm/nginx/default.sock;
    listen unix:/dev/shm/nginx/h2.sock http2;
    server_name _;
    
    location / {
        return 403;
    }
    
    server_tokens off;
}
#-----------------不要修改以下内容----------------
#domain_list=${domain_list[@]}
#true_domain_list=${true_domain_list[@]}
EOF

    # 创建nginx主配置
    cat > /etc/nginx/nginx.conf <<EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    gzip on;
    
    include /etc/nginx/conf.d/*.conf;
}
EOF

    # 创建403页面
    echo "403 Forbidden" > /var/www/html/index.html
    
    if ! nginx -t; then
        red "Nginx配置错误！"
        nginx -t
        return 1
    fi
}

#配置xray - 监听443端口，fallback到nginx socket
config_xray()
{
    mkdir -p /usr/local/etc/xray
    mkdir -p /dev/shm/xray
    chmod 755 /dev/shm/xray
    
    cat > $xray_config <<EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$xid_1",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": "/dev/shm/nginx/default.sock"
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "minVersion": "1.2",
                    "certificates": [
                        {
                            "certificateFile": "${nginx_prefix}/certs/${domain_list[0]}.cer",
                            "keyFile": "${nginx_prefix}/certs/${domain_list[0]}.key",
                            "ocspStapling": 3600
                        }
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
}

print_share_link()
{
    local ip=""
    while [ -z "$ip" ]
    do
        read -p "请输入您的服务器IP(用于生成分享链接)：" ip
    done
    if [[ "$ip" =~ : ]] && ! [[ "$ip" =~ ^\[.*:.*\]$ ]]; then
        ip="[$ip]"
    fi
    echo
    tyblue "分享链接："
    echo "vless://${xid_1}@${ip}:443?security=tls&sni=${domain_list[0]}&alpn=http%2F1.1&flow=xtls-rprx-vision"
}

print_config_info()
{
    echo -e "\\n\\n\\n"
    tyblue "==================== Xray配置信息 ===================="
    tyblue " 传输协议            ：VLESS-TCP-XTLS"
    tyblue " Xray端口            ：443"
    tyblue " 地址(域名)          ：${domain_list[0]}"
    tyblue " 用户ID(UUID)        ：${xid_1}"
    tyblue " 流控(flow)          ：xtls-rprx-vision"
    tyblue " 加密(encryption)    ：none"
    tyblue " 传输方式(network)   ：tcp"
    tyblue " 传输层加密(security)：tls"
    tyblue " SNI(serverName)     ：${domain_list[0]}"
    tyblue "====================================================="
    echo
    tyblue "伪装说明："
    tyblue "  访问 https://${domain_list[0]} 将返回403 Forbidden"
    tyblue "  代理流量通过443端口传输，与正常HTTPS流量无法区分"
    echo
    ask_if "是否生成分享链接？(y/n)" && print_share_link
    echo
    red " 此脚本仅供交流学习使用，请勿使用此脚本行违法之事。网络非法外之地，行非法之事，必将接受法律制裁!!!!"
}

install_xray_tls_web()
{
    in_install_update_xray_tls_web=1
    
    if ! grep -qi "debian" /etc/os-release; then
        red "此脚本仅支持Debian系统！"
        exit 1
    fi
    
    get_system_info
    
    check_port
    check_important_dependence_installed ca-certificates
    check_important_dependence_installed wget
    check_important_dependence_installed curl
    check_important_dependence_installed procps
    check_important_dependence_installed systemd
    
    dpkg --configure -a
    
    $apt update
    $apt -y -f install
    $apt -y full-upgrade

    # 读取域名
    readDomain
    
    # 生成UUID
    xid_1="$(cat /proc/sys/kernel/random/uuid)"

    install_nginx
    
    install_acme_dependence
    $apt clean

    [ -e $HOME/.acme.sh/acme.sh ] && $HOME/.acme.sh/acme.sh --uninstall
    rm -rf $HOME/.acme.sh
    curl https://get.acme.sh | sh
    $HOME/.acme.sh/acme.sh --register-account -m my@example.com
    
    get_cert

    remove_xray
    install_update_xray

    config_nginx
    config_xray
    
    if ! nginx -t; then
        red "Nginx配置验证失败！"
        exit 1
    fi
    
    sleep 2s
    # 先启动Nginx（监听unix socket），再启动Xray（监听443）
    systemctl start nginx
    sleep 1s
    systemctl restart xray
    
    # 检查服务状态
    if systemctl -q is-active xray && systemctl -q is-active nginx; then
        green "-------------------安装完成-------------------"
    else
        red "服务启动有问题，请检查日志"
    fi
    print_config_info
    
    cd /
    rm -rf "$temp_dir"
    in_install_update_xray_tls_web=0
}

readDomain()
{
    check_domain()
    {
        if [ -z "$1" ]; then
            return 1
        elif [ "${1%%.*}" == "www" ]; then
            red "域名前面不要带www！"
            return 1
        elif [ "$(echo -n "$1" | wc -c)" -gt 42 ]; then
            red "域名过长！"
            return 1
        else
            return 0
        fi
    }
    
    local domain
    
    tyblue "-------请输入解析到此服务器的域名(前面不带\"http://\"或\"https://\")-------"
    
    local queren=0
    while [ $queren -ne 1 ]
    do
        domain=""
        while [ -z "$domain" ]
        do
            read -p "请输入域名：" domain
            if [ "$(echo -n "$domain" | wc -c)" -gt 46 ]; then
                red "域名过长！"
                domain=""
            fi
        done
        echo
        ask_if "您输入的域名是\"$domain\"，确认吗？(y/n)" && queren=1
    done
    
    domain_list=("$domain")
    true_domain_list=("$domain")
}

get_system_info()
{
    timezone="$(ls -l /etc/localtime 2>/dev/null | awk -F zoneinfo/ '{print $NF}')"
    if [[ ! -L /etc/localtime ]] || [ "$timezone" == "" ]; then
        timezone="UTC"
    fi
    
    release="debian"
    systemVersion="$(grep VERSION_ID /etc/os-release | cut -d = -f 2 | tr -d '"')"
    
    apt="apt"
    apt_no_install_recommends="apt --no-install-recommends"
    
    cpu_thread_num="$(grep '^processor' /proc/cpuinfo | uniq | wc -l)"
    if [ -z "$cpu_thread_num" ] || [ $cpu_thread_num -lt 1 ]; then
        cpu_thread_num=1
    fi
}

check_port()
{
    green "正在检查端口占用。。。"
    
    if ss -tlnp | grep -q ":80 "; then
        red "TCP:80端口被占用！"
        yellow "请停止占用80端口的服务后重试"
        exit 1
    fi
    
    if ss -tlnp | grep -q ":443 "; then
        red "TCP:443端口被占用！"
        yellow "请停止占用443端口的服务后重试"
        exit 1
    fi
    
    green "端口检查通过！"
}

restart_xray_tls_web()
{
    get_config_info
    systemctl restart nginx
    sleep 1s
    systemctl restart xray
    sleep 2s
    if ! systemctl -q is-active xray; then
        red "Xray启动失败！！"
        journalctl -u xray -n 5 --no-pager
    elif ! systemctl -q is-active nginx; then
        red "Nginx启动失败！！"
        nginx -t
    else
        green "重启/启动成功！！"
    fi
}

stop_xray_tls_web()
{
    systemctl stop xray nginx
    green "已停止！"
}

view_config()
{
    get_config_info
    print_config_info
}

reset_domain()
{
    yellow "重置域名将删除所有现有域名(包括域名证书、伪装网站等)"
    ! ask_if "是否继续？(y/n)" && return 0
    
    get_config_info
    
    if [ ${#domain_list[@]} -eq 0 ]; then
        red "没有域名配置"
        return 1
    fi
    
    systemctl stop xray nginx
    
    # 清理证书
    for i in "${domain_list[@]}"
    do
        $HOME/.acme.sh/acme.sh --remove --domain ${i} --ecc 2>/dev/null
        rm -rf $HOME/.acme.sh/${i}_ecc
        rm -rf "${nginx_prefix}/certs/${i}.key" "${nginx_prefix}/certs/${i}.cer"
    done
    
    # 重新获取域名
    readDomain
    
    # 重新生成UUID
    xid_1="$(cat /proc/sys/kernel/random/uuid)"
    
    # 重新申请证书
    get_cert
    
    # 重新配置
    config_nginx
    config_xray
    
    if ! nginx -t; then
        red "Nginx配置验证失败！"
        return 1
    fi
    
    sleep 2s
    systemctl start nginx
    sleep 1s
    systemctl restart xray
    
    green "域名重置完成！！"
    print_config_info
}

change_xray_id()
{
    get_config_info
    tyblue "您现在的TCP id是：${xid_1}"
    ! ask_if "是否要继续修改?(y/n)" && return 0
    while true
    do
        local new_xid=""
        while [ -z "$new_xid" ]
        do
            tyblue "-------------请输入新的id(UUID格式)-------------"
            read new_xid
        done
        tyblue "您输入的id是：$new_xid"
        ask_if "是否确定?(y/n)" && break
    done
    xid_1="$new_xid"
    config_xray
    systemctl -q is-active xray && systemctl restart xray
    green "更换成功！！"
    print_config_info
}

update_xray()
{
    green "正在更新Xray..."
    install_update_xray
    if [ $is_installed -eq 1 ]; then
        systemctl restart xray
    fi
    green "Xray更新完成！"
}

# 开始菜单
start_menu()
{
    local xray_status
    [ $xray_is_installed -eq 1 ] && xray_status="已安装" || xray_status="未安装"
    systemctl -q is-active xray && xray_status+="    运行中" || xray_status+="    未运行"
    local nginx_status
    [ $nginx_is_installed -eq 1 ] && nginx_status="已安装" || nginx_status="未安装"
    systemctl -q is-active nginx && nginx_status+="    运行中" || nginx_status+="    未运行"
    
    clear
    tyblue "======================= Xray-TLS+Web 搭建/管理脚本 ======================="
    echo
    tyblue "            Xray   ：           ${xray_status}"
    echo
    tyblue "            Nginx  ：           ${nginx_status}"
    echo
    tyblue "================================= 注意事项 ================================="
    yellow " 1. 此脚本需要一个解析到本服务器的域名"
    tyblue " 2. Xray监听443端口处理TLS代理流量"
    tyblue " 3. Nginx作为fallback通过unix socket返回403页面"
    tyblue " 4. 此脚本仅支持Debian系统"
    green " 5. 建议在纯净的系统上使用此脚本"
    tyblue "========================================================================"
    echo
    echo
    tyblue " ---------------------------- 安装/更新/卸载 ----------------------------"
    if [ $is_installed -eq 0 ]; then
        green "   1. 安装Xray-TLS+Web"
    else
        green "   1. 重新安装Xray-TLS+Web"
    fi
    green "   2. 更新Xray"
    red "   3. 卸载Xray-TLS+Web"
    echo
    tyblue " ------------------------------ 启动/停止 ------------------------------"
    tyblue "   4. 启动/重启Xray-TLS+Web"
    tyblue "   5. 停止Xray-TLS+Web"
    echo
    tyblue " -------------------------------- 管理 --------------------------------"
    tyblue "   6. 查看配置信息"
    tyblue "   7. 重置域名"
    tyblue "   8. 修改id(用户ID/UUID)"
    yellow "   0. 退出脚本"
    echo
    echo
    
    local choice=""
    while [[ ! "$choice" =~ ^(0|[1-9][0-9]*)$ ]] || ((choice>8))
    do
        read -p "您的选择是：" choice
    done
    
    if (( choice==2 || (choice>=4 && choice<=8) )) && [ $is_installed -eq 0 ]; then
        red "请先安装Xray-TLS+Web！！"
        echo
        read -p "按回车键继续..." 
        return 1
    fi
    
    case $choice in
        1) install_xray_tls_web ;;
        2) update_xray ;;
        3)
            ! ask_if "确定要删除吗?(y/n)" && return 0
            remove_xray
            remove_nginx
            $HOME/.acme.sh/acme.sh --uninstall 2>/dev/null
            rm -rf $HOME/.acme.sh
            green "删除完成！"
            ;;
        4) restart_xray_tls_web ;;
        5) stop_xray_tls_web ;;
        6) view_config ;;
        7) reset_domain ;;
        8) change_xray_id ;;
        0) exit 0 ;;
    esac
    
    echo
    read -p "按回车键返回主菜单..."
    start_menu
}

# 主程序入口
check_base_command

if ! grep -qi "debian" /etc/os-release; then
    red "此脚本仅支持Debian系统！"
    exit 1
fi

if [ "$EUID" != "0" ]; then
    red "请用root用户运行此脚本！！"
    exit 1
fi

if ! check_sudo; then
    yellow "检测到正在使用sudo！"
    exit 1
fi

apt="apt"
apt_no_install_recommends="apt --no-install-recommends"

dpkg -l nginx 2>/dev/null | grep -q "^ii" && nginx_is_installed=1 || nginx_is_installed=0
[ -f /usr/local/bin/xray ] && xray_is_installed=1 || xray_is_installed=0
([ $xray_is_installed -eq 1 ] && [ $nginx_is_installed -eq 1 ]) && is_installed=1 || is_installed=0

get_system_info

update=0
start_menu
