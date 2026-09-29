#!/bin/bash
set -o pipefail

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# This entry point is only for a fresh VPS. Never replace an existing install.
if [[ -e /usr/local/V2bX || -L /usr/local/V2bX || -e /etc/V2bX || -L /etc/V2bX || -e /etc/systemd/system/V2bX.service || -e /etc/init.d/V2bX || -e /usr/bin/V2bX || -L /usr/bin/V2bX || -e /usr/bin/v2bx || -L /usr/bin/v2bx ]]; then
    echo -e "${red}检测到已有 V2bX 文件或服务；此脚本只用于全新 VPS，已停止安装。${plain}" >&2
    exit 1
fi

profile_source="${V2BX_PROFILE:-/root/v2bx.private.json}"
if [[ ! -f "$profile_source" || ! -r "$profile_source" ]]; then
    echo -e "${red}未找到可读取的配置文件：${profile_source}${plain}" >&2
    echo "请先按 README 用 SFTP 上传配置文件，再运行安装脚本。" >&2
    exit 1
fi
chmod 600 "$profile_source" || exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "alpine"; then
    release="alpine"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "arch"; then
    release="arch"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(uname -m)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    echo -e "${red}不支持的 CPU 架构：$(uname -m)${plain}" >&2
    exit 1
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
    if [[ ${os_version} -eq 7 ]]; then
        echo -e "${red}注意： CentOS 7 无法使用hysteria1/2协议！${plain}\n"
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release python3 wget curl unzip tar crontabs socat ca-certificates -y >/dev/null 2>&1 || return 1
        update-ca-trust force-enable >/dev/null 2>&1 || return 1
    elif [[ x"${release}" == x"alpine" ]]; then
        apk add python3 wget curl unzip tar socat ca-certificates >/dev/null 2>&1 || return 1
        update-ca-certificates >/dev/null 2>&1 || return 1
    elif [[ x"${release}" == x"debian" ]]; then
        apt-get update -y >/dev/null 2>&1 || return 1
        apt-get install python3 wget curl unzip tar cron socat ca-certificates -y >/dev/null 2>&1 || return 1
        update-ca-certificates >/dev/null 2>&1 || return 1
    elif [[ x"${release}" == x"ubuntu" ]]; then
        apt-get update -y >/dev/null 2>&1 || return 1
        apt-get install python3 wget curl unzip tar cron socat ca-certificates -y >/dev/null 2>&1 || return 1
        update-ca-certificates >/dev/null 2>&1 || return 1
    elif [[ x"${release}" == x"arch" ]]; then
        pacman -Sy --noconfirm >/dev/null 2>&1 || return 1
        pacman -S --noconfirm --needed python3 wget curl unzip tar cron socat ca-certificates >/dev/null 2>&1 || return 1
    fi
}

install_V2bX() {
    mkdir /usr/local/V2bX/ -p
    cd /usr/local/V2bX/

    last_version=$(curl -fLsS "https://api.github.com/repos/wyx2685/V2bX/releases/latest" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')
    if [[ ! "$last_version" =~ ^[A-Za-z0-9._-]+$ ]]; then
        echo -e "${red}检测 V2bX 最新版本失败，请确认 GitHub 可以访问。${plain}" >&2
        return 1
    fi
    echo "检测到 V2bX 最新版本：${last_version}，开始安装"
    if ! wget -N --progress=bar -O /usr/local/V2bX/V2bX-linux.zip "https://github.com/wyx2685/V2bX/releases/download/${last_version}/V2bX-linux-${arch}.zip"; then
        echo -e "${red}下载 V2bX 失败，请确认 VPS 可以访问 GitHub。${plain}" >&2
        return 1
    fi

    unzip V2bX-linux.zip || return 1
    rm V2bX-linux.zip -f
    chmod +x V2bX
    mkdir /etc/V2bX/ -p
    cp geoip.dat /etc/V2bX/
    cp geosite.dat /etc/V2bX/
    if [[ x"${release}" == x"alpine" ]]; then
        cat <<EOF > /etc/init.d/V2bX
#!/sbin/openrc-run

name="V2bX"
description="V2bX"

command="/usr/local/V2bX/V2bX"
command_args="server"
command_user="root"

pidfile="/run/V2bX.pid"
command_background="yes"

depend() {
        need net
}
EOF
        chmod +x /etc/init.d/V2bX
        rc-update add V2bX default || return 1
        echo -e "${green}V2bX ${last_version}${plain} 安装完成，已设置开机自启"
    else
        cat <<EOF > /etc/systemd/system/V2bX.service
[Unit]
Description=V2bX Service
After=network.target nss-lookup.target
Wants=network.target

[Service]
User=root
Group=root
Type=simple
LimitAS=infinity
LimitRSS=infinity
LimitCORE=infinity
LimitNOFILE=999999
WorkingDirectory=/usr/local/V2bX/
ExecStart=/usr/local/V2bX/V2bX server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload || return 1
        systemctl enable V2bX || return 1
        echo -e "${green}V2bX ${last_version}${plain} 安装完成，已设置开机自启"
    fi

    cp config.json /etc/V2bX/

    if [[ ! -f /etc/V2bX/dns.json ]]; then
        cp dns.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/route.json ]]; then
        cp route.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/V2bX/
    fi
    if [[ ! -f /etc/V2bX/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/V2bX/
    fi
    install -m 644 "$profile_helper_tmp" /usr/local/V2bX/profile.py || return 1
    python3 /usr/local/V2bX/profile.py import "$profile_source" || return 1
    curl -fLsS https://raw.githubusercontent.com/wjy23443200/V2bX-script/master/V2bX.sh -o /usr/bin/V2bX || return 1
    chmod +x /usr/bin/V2bX
    ln -s /usr/bin/V2bX /usr/bin/v2bx
    cd "$cur_dir"
    echo -e ""
    echo "开始首次节点配置；完成后可用 v2bx status 查看状态、v2bx log 查看日志。"
    local initconfig_tmp
    initconfig_tmp=$(mktemp) || return 1
    curl -fLsS https://raw.githubusercontent.com/wjy23443200/V2bX-script/master/initconfig.sh -o "$initconfig_tmp" || { rm -f "$initconfig_tmp"; return 1; }
    source "$initconfig_tmp" || { rm -f "$initconfig_tmp"; return 1; }
    rm -f "$initconfig_tmp"
    generate_config_file
}

echo -e "${green}开始安装${plain}"
install_base || { echo -e "${red}安装系统依赖失败，请检查软件源。${plain}" >&2; exit 1; }
profile_helper_tmp=$(mktemp) || exit 1
trap 'rm -f "$profile_helper_tmp"' EXIT
curl -fLsS https://raw.githubusercontent.com/wjy23443200/V2bX-script/master/profile.py -o "$profile_helper_tmp" || exit 1
python3 "$profile_helper_tmp" --profile "$profile_source" validate || exit 1
install_V2bX
