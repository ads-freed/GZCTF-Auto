#!/bin/bash
stty erase '^H'
check(){
    if [ $(id -u) != "0" ]; then
        echo "Please execute this script as root user！"
        exit 1
    fi
    if ! command -v docker &> /dev/null
    then
        green_echo "Docker-ce is not installed."
        curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository -y "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt-get -y update
        sudo DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install docker-ce docker-compose-plugin
    else
        if ! dpkg -l | grep docker-ce &> /dev/null
        then
            green_echo "Reinstall Docker-ce."
            sudo apt-get remove -y docker.io
            curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
            sudo add-apt-repository -y "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
            sudo apt-get -y update
            sudo DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install docker-ce docker-compose-plugin
        else
            green_echo "Docker-ce is installed."
            if ! dpkg -l | grep docker-compose-plugin &> /dev/null
            then
                green_echo "Install Docker-compose."
                sudo DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install docker-compose-plugin
            else
                green_echo "Docker-compose is installed."
            fi
        fi
    fi
}

start(){
    sudo apt-get -y update
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install apt-transport-https ca-certificates curl software-properties-common dnsutils debian-keyring debian-archive-keyring
    mkdir -p config-auto config-auto/agent config-auto/docker config-auto/gz config-auto/k3s config-auto/caddy
    wget --no-check-certificate -O config-auto/agent/agent-temp.sh https://github.com/ads-freed/GZCTF-Auto/main/config-auto/agent/agent-temp.sh
    wget --no-check-certificate -O config-auto/agent/add-agent.sh https://github.com/ads-freed/GZCTF-Auto/main/config-auto/agent/add-agent.sh
    wget --no-check-certificate -O config-auto/docker/daemon.json https://github.com/ads-freed/GZCTF-Auto/main/config-auto/docker/daemon.json
    wget --no-check-certificate -O config-auto/gz/appsettings.json https://github.com/ads-freed/GZCTF-Auto/main/config-auto/gz/appsettings.json
    wget --no-check-certificate -O config-auto/gz/docker-compose.yaml https://github.com/ads-freed/GZCTF-Auto/main/config-auto/gz/docker-compose.yaml
    wget --no-check-certificate -O config-auto/k3s/kubelet.config https://github.com/ads-freed/GZCTF-Auto/main/config-auto/k3s/kubelet.config
    wget --no-check-certificate -O config-auto/k3s/registries.yaml https://github.com/ads-freed/GZCTF-Auto/main/config-auto/k3s/registries.yaml
    wget --no-check-certificate -O config-auto/caddy/Caddyfile https://github.com/ads-freed/GZCTF-Auto/main/config-auto/caddy/Caddyfile
    sudo kill -9 $(sudo lsof -t -i:80)
}

change_Source(){
    echo "Automatic source change is in progress..."
    if [ -f /etc/os-release ]; then
    . /etc/os-release
    VERSION_ID=$(echo "$VERSION_ID" | tr -d '"')
    major=$(echo "$VERSION_ID" | cut -d '.' -f 1)
    minor=$(echo "$VERSION_ID" | cut -d '.' -f 2)
    if [ "$major" -lt 24 ] || { [ "$major" -eq 24 ] && [ "$minor" -lt 4 ]; }; then
        sudo sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
        green_echo "The source change was successful.！"
    else
        sudo sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources
        green_echo "The source change was successful.！"
    fi
    else
        red_echo "/etc/os-release File does not exist to determine system version information。"
        red_echo "Source change failed, please change source manually！"
    fi
}

login_docker(){
    while true; do
        read -p "Enter the AliCloud Mirror Service username: " username
        read -p "Enter the AliCloud Mirror Service password: " password
        read -p "Enter the AliCloud Mirror Service public address: " address
        out=$(echo $password | sudo -S docker login --username=$username --password-stdin $address 2>&1)
        if echo "$out" | grep -q "Login Succeeded"; then
            echo "Log in successfully!"
            sed -i "s|DOCKER_USERNAME|$username|g" ./config-auto/gz/appsettings.json
            sed -i "s|DOCKER_PASSWORD|$password|g" ./config-auto/gz/appsettings.json
            sed -i "s|DOCKER_ADDRESS|$address|g" ./config-auto/gz/appsettings.json
            sed -i "s|USER_OP|$username|g" ./config-auto/agent/agent-temp.sh
            sed -i "s|PASSWORD_OP|$password|g" ./config-auto/agent/agent-temp.sh
            sed -i "s|ADDRESS_OP|$address|g" ./config-auto/agent/agent-temp.sh
            break
        else
            echo "Login failed, wrong username or password, please re-enter！"
        fi
    done
}

set_smtp(){
    read -p "Please enter the smtp server address: " smtp_server
    read -p "Please enter the smtp server port: " smtp_port
    read -p "Please enter the smtp username: " smtp_username
    read -p "Please enter the smtp password: " smtp_password
    read -p "Please enter the sender's e-mail address: " smtp_sender
    sed -i "s|SMTP_SERVER|$smtp_server|g" ./config-auto/gz/appsettings.json
    sed -i "s|SMTP_PORT|$smtp_port|g" ./config-auto/gz/appsettings.json
    sed -i "s|SMTP_USERNAME|$smtp_username|g" ./config-auto/gz/appsettings.json
    sed -i "s|SMTP_PASSWORD|$smtp_password|g" ./config-auto/gz/appsettings.json
    sed -i "s|SMTP_SENDER|$smtp_sender|g" ./config-auto/gz/appsettings.json
}

set_port(){
    while true; do
        read -p "Please set the port of GZCTF (default is 81): " gz_port
        if [ -z "$gz_port" ]; then
            gz_port=81
        fi
        case $gz_port in
            ''|*[!0-9]*) echo "Port number must be numeric, please re-enter！" ;;
            *) 
                if [ "$gz_port" -lt 1 ] || [ "$gz_port" -gt 65535 ]; then
                    echo "The port number must be between 1 and 65535, please re-enter the！"
                else
                    ss -tuln | grep ":$gz_port\b" > /dev/null
                    if [ $? -eq 0 ]; then
                        echo "Ports $gz_port Occupied, please re-enter！"
                    else
                        sed -i "s|PORT|$gz_port|g" ./config-auto/gz/docker-compose.yaml
                        break
                    fi
                fi
                ;;
        esac
    done
}

red_echo() {
    echo -e "\e[91m$1\e[0m"
}

green_echo() {
    echo -e "\e[92m$1\e[0m"
}

echo "=========================================================="
echo "||                                                      ||"
echo "||  ____ _________ _____ _____       _         _        ||"
echo "|| / ___|__  / ___|_   _|  ___|     / \  _   _| |_ ___  ||"
echo "||| |  _  / / |     | | | |_ _____ / _ \| | | | __/ _ \ ||"
echo "||| |_| |/ /| |___  | | |  _|_____/ ___ \ |_| | || (_) |||"
echo "|| \____/____\____| |_| |_|      /_/   \_\__,_|\__\___/ ||"
echo "||                                                      ||"
echo "=========================================================="
echo "Please choose whether or not to automatically change the source (currently only ubuntu is supported)："
echo "1) yes"
echo "2) No (manual source change)"
while true; do
    read -p "Please enter your selection: " changeSource

    case $changeSource in
        1)
            echo "Set up automatic source switching..."
            change_Source
            break
            ;;
        2)
            echo "Set manual source change..."
            break
            ;;
        *)
            echo "Invalid selection, please re-enter！"
            ;;
    esac
done

echo "Initialization in progress, please wait..."
start
check
echo "Initialization successful! Please continue configuration"

echo "Please select the deployment network environment："
echo "1) Intranet"
echo "2) Public"
while true; do
    read -p "Please enter your selection: " net

    case $net in
        1)
            echo "Select Intranet Deployment..."
            private_ip=$(hostname -I | awk '{print $1}')
            sed -i "s|DOMAIN|$private_ip|g" ./config-auto/gz/appsettings.json
            break
            ;;
        2)
            echo "Choose public network deployment..."
            public_ip=$(curl -s https://api.ipify.org)
            IP_ADDR=$(hostname -I | awk '{print $1}')
            if [[ $IP_ADDR =~ ^10\. ]] || [[ $IP_ADDR =~ ^192\.168\. ]] || [[ $IP_ADDR =~ ^172\.1[6-9]\. ]] || [[ $IP_ADDR =~ ^172\.2[0-9]\. ]] || [[ $IP_ADDR =~ ^172\.3[0-1]\. ]]; then
                echo "The host is in a VPC network..."
                VPC=1
            else
                echo "The host is in a classic network..."
                VPC=0
            fi
            break
            ;;
        *)
            echo "Invalid selection, please re-enter！"
            ;;
    esac
done

echo "Please select the deployment method："
echo "1) Docker deployment (suitable for stand-alone deployment in small competitions)"
echo "2) docker+k3s deployment (suitable for single or multi-machine deployment for large-scale competitions)"
while true; do
    read -p "Please enter your selection: " setup

    case $setup in
        1)
            echo "Choose docker deployment..."
            sed -i "s|SETUPTYPE|Docker|g" ./config-auto/gz/appsettings.json
            sed -i "s|#K3S||g" ./config-auto/gz/appsettings.json
            sed -i "s|# - \"/var/run/docker.sock:/var/run/docker.sock\"|- \"/var/run/docker.sock:/var/run/docker.sock\"|g" ./config-auto/gz/docker-compose.yaml
            break
            ;;
        2)
            echo "Choose docker+k3s deployment..."
            hostnamectl set-hostname k3s-master
            sed -i "s|SETUPTYPE|Kubernetes|g" ./config-auto/gz/appsettings.json
            sed -i "s|#K3S|,\"KubernetesConfig\": {\"Namespace\": \"gzctf-challenges\",\"ConfigPath\": \"kube-config.yaml\",\"AllowCIDR\": [\"10.0.0.0/8\"],\"DNS\": [\"8.8.8.8\",\"223.5.5.5\"]}|g" ./config-auto/gz/appsettings.json
            sed -i "s|# - \"./kube-config.yaml:/app/kube-config.yaml:ro\"|- \"./kube-config.yaml:/app/kube-config.yaml:ro\"|g" ./config-auto/gz/docker-compose.yaml
            while true; do
                read -p "Please enter the number of k3s node machines (except this machine, for single machine deployment, fill in 0 ）： " hostNum
                if [ -z "$hostNum" ]; then
                    echo "The input is empty, please re-enter。"
                elif ! echo "$hostNum" | grep -qE '^[0-9]+$'; then
                    echo "The input is not a number, please re-enter。"
                else
                    echo "set up $hostNum Nodes..."
                    ip_array=()
                    for i in $(seq 1 $hostNum); do
                        while true; do
                            read -p "Please enter the IP address of the k3s node $i (will affect the automatic connection script）： " hostIP
                            echo "Please confirm the IP address of the k3s node $i (there must be no error, otherwise the connection will fail.）：$hostIP "
                            echo "1) confirm"
                            echo "2) Re-enter"
                            read -p "Confirm？: " confirm
                            case $confirm in
                                1)
                                    echo "Confirm the IP address of node $i：$hostIP"
                                    ip_array+=($hostIP)
                                    break
                                    ;;
                                2)
                                    ;;
                                *)
                                    echo "Invalid selection！"
                                    ;;
                            esac
                        done
                        sed -i "s|#AGENT_HOSTS|echo \"$hostIP k3s-agent-$i\" >> /etc/hosts\n#AGENT_HOSTS|g" config-auto/agent/agent-temp.sh
                        echo "$hostIP k3s-agent-$i" >> /etc/hosts
                    done
                    break
                fi
            done
            break
            ;;
        *)
            echo "Invalid selection, please re-enter："
            ;;
    esac
done

echo "Please select the mirror pull site for the contest topic："
echo "1) dockerhub (need to set up docker image source）"
echo "2) Alibaba Cloud Image Service (You need to log in to the Alibaba Cloud Docker account）"
while true; do
    read -p "Please enter your selection: " source

    case $source in
        1)
            echo "Select DockerHub..."
            read -p "Input mirror source (default built-in source）: " source_add

            if [ -z "$source_add" ]; then
                source_add="https://hub.docker-alhk.dkdun.com/"
            fi
            echo "The mirror source used is: $source_add"
            sed -i "s|\[\"[^\"]*\"\]|\[\"$source_add\"\]|g" ./config-auto/docker/daemon.json
            sed -i "s|https://hub.docker-alhk.dkdun.com/|$source_add|g" ./config-auto/agent/agent-temp.sh
            sed -i "s|https://hub.docker-alhk.dkdun.com/|$source_add|g" ./config-auto/k3s/registries.yaml
            break
            ;;
        2)
            echo "Select Alibaba Cloud Image Service..."
            login_docker
            sed -i "s|login=0|login=1|g" ./config-auto/agent/agent-temp.sh
            break
            ;;
        *)
            echo "Invalid selection, please re-enter："
            ;;
    esac
done

echo "Please select whether to enable traffic proxy："
echo "1) yes"
echo "2) no"
while true; do
    read -p "Please enter your selection: " proxy

    case $proxy in
        1)
            echo "Select Enable Traffic Proxy..."
            sed -i "s|Default|PlatformProxy|g" ./config-auto/gz/appsettings.json
            sed -i "s|\"EnableTrafficCapture\": false,|\"EnableTrafficCapture\": true,|g" ./config-auto/gz/appsettings.json
            if [ "$setup" -eq 1 ]; then
                docker network create challenges -d bridge --subnet 10.2.0.0/16
            fi
            break
            ;;
        2)
            echo "Select Turn off traffic proxy..."
            break
            ;;
        *)
            echo "Invalid selection, please re-enter："
            ;;
    esac
done

echo "Please select whether to enable SMTP mail service："
echo "1) yes"
echo "2) no"
while true; do
    read -p "Please enter your selection: " smtp

    case $smtp in
        1)
            echo "Select Enable SMTP mail service..."
            set_smtp
            break
            ;;
        2)
            echo "Select Close SMTP mail service..."
            sed -i "s|SMTP_PORT|1|g" ./config-auto/gz/appsettings.json
            break
            ;;
        *)
            echo "Invalid selection, please re-enter："
            ;;
    esac
done

if [ "$net" -eq 2 ]; then
    while true; do
        echo "Please select whether the domain name has been resolved (domestic servers need to be registered！！！)："
        echo "1) yes"
        echo "2) no"
        read -p "Please enter your selection: " select
        case $select in
            1)
                read -p "Please enter the resolved domain name: " domain

                domain_ip=$(dig +short "$domain")

                if [ "$public_ip" = "$domain_ip" ]; then
                    echo "Set up your domain name $domain success..."
                    sed -i "s|DOMAIN|$domain|g" ./config-auto/gz/appsettings.json
                    sed -i "s|DOMAIN|$domain|g" ./config-auto/caddy/Caddyfile
                    sed -i "s|SERVER|$public_ip|g" ./config-auto/agent/agent-temp.sh
                    sed -i "s|PORT|81|g" ./config-auto/caddy/Caddyfile
                    sed -i "s|PORT|81|g" ./config-auto/gz/docker-compose.yaml
                    break
                else
                    echo "domain name $domain Analytical IP ($domain_ip) Not the local public network IP ($public_ip)"
                    echo "Please check whether the domain name resolution is correct.!"
                    select=2
                fi
                ;;
            2)
                echo "Unresolved domain name..."
                sed -i "s|DOMAIN|$public_ip|g" ./config-auto/gz/appsettings.json
                sed -i "s|SERVER|$public_ip|g" ./config-auto/agent/agent-temp.sh
                set_port
                break
                ;;
            *)
                echo "Invalid selection, please re-enter："
                ;;
        esac
    done
fi

if [ "$net" -eq 1 ]; then
    set_port
    sed -i "s|SERVER|$private_ip|g" ./config-auto/agent/agent-temp.sh
fi

while true; do
    read -p "Please set an administrator password (must contain uppercase letters, lowercase letters and numbers): " adminpasswd
    if [[ $adminpasswd =~ [A-Z] && $adminpasswd =~ [a-z] && $adminpasswd =~ [0-9] ]]; then
        sed -i "s|ADMIN_PASSWD|$adminpasswd|g" ./config-auto/gz/docker-compose.yaml
        echo "Password set successfully！"
        break
    else
        echo "The password must contain uppercase letters, lowercase letters and numbers. Please re-enter。"
    fi
done

green_echo "Start deployment..."

systemctl disable --now ufw && systemctl disable --now iptables
mv ./config-auto/docker/daemon.json /etc/docker/
sudo systemctl daemon-reload && sudo systemctl restart docker

if [ "$setup" -eq 1 ]; then
    mkdir -p GZCTF
    mv ./config-auto/gz/appsettings.json ./GZCTF/
    mv ./config-auto/gz/docker-compose.yaml ./GZCTF/
else
    if [ "$net" -eq 2 ]; then
        if [ "$VPC" -eq 1 ]; then
            curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_EXEC="--kube-controller-manager-arg=node-cidr-mask-size=16" INSTALL_K3S_EXEC="--docker" INSTALL_K3S_MIRROR=cn sh -s - --node-external-ip="$public_ip" --flannel-backend=wireguard-native --flannel-external-ip --disable=traefik --kube-apiserver-arg=service-node-port-range=20000-50000 --kubelet-arg=config=/etc/rancher/k3s/kubelet.config
            if ! command -v kubectl &> /dev/null
            then
                red_echo "k3s Installation failed."
                exit 1
            else
                green_echo "k3s Installation Successful."
            fi
            sed -i "s|sh -|sh -s - --node-external-ip=PUBLIC_IP|g" config-auto/agent/agent-temp.sh
        else
            curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_EXEC="--kube-controller-manager-arg=node-cidr-mask-size=16" INSTALL_K3S_EXEC="--docker" INSTALL_K3S_MIRROR=cn sh -s - --disable=traefik --kube-apiserver-arg=service-node-port-range=20000-50000 --kubelet-arg=config=/etc/rancher/k3s/kubelet.config
            if ! command -v kubectl &> /dev/null
            then
                red_echo "k3s Installation failed."
                exit 1
            else
                green_echo "k3sInstallation Successful."
            fi
        fi
    else
        curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_EXEC="--kube-controller-manager-arg=node-cidr-mask-size=16" INSTALL_K3S_EXEC="--docker" INSTALL_K3S_MIRROR=cn sh -s - --disable=traefik --kube-apiserver-arg=service-node-port-range=20000-50000 --kubelet-arg=config=/etc/rancher/k3s/kubelet.config
        if ! command -v kubectl &> /dev/null
        then
            red_echo "k3s Installation failed."
            exit 1
        else
            green_echo "k3s Installation Successful."
        fi
    fi
    token=$(sudo cat /var/lib/rancher/k3s/server/token)
    sed -i "s|mynodetoken|$token|g" ./config-auto/agent/agent-temp.sh
    mv ./config-auto/k3s/kubelet.config /etc/rancher/k3s/
    mv ./config-auto/k3s/registries.yaml /etc/rancher/k3s/
    sudo systemctl daemon-reload && sudo systemctl restart k3s
    mkdir -p GZCTF
    sudo cat /etc/rancher/k3s/k3s.yaml > ./GZCTF/kube-config.yaml
    if [ "$net" -eq 2 ]; then
        sed -i "s|127.0.0.1|$public_ip|g" ./GZCTF/kube-config.yaml
        echo "$public_ip k3s-master" >> /etc/hosts
        sed -i "s|MASTER_IP|$public_ip|g" config-auto/agent/agent-temp.sh
    else
        sed -i "s|127.0.0.1|$private_ip|g" ./GZCTF/kube-config.yaml
        echo "$private_ip k3s-master" >> /etc/hosts
        sed -i "s|MASTER_IP|$private_ip|g" config-auto/agent/agent-temp.sh
    fi
    mv ./config-auto/gz/appsettings.json ./GZCTF/
    mv ./config-auto/gz/docker-compose.yaml ./GZCTF/
    mkdir -p k3s-agent
    cp ./config-auto/agent/agent-temp.sh k3s-agent/agent-temp
    mv ./config-auto/agent/add-agent.sh k3s-agent/add-agent.sh
    for i in $(seq 1 $hostNum); do
        cp ./config-auto/agent/agent-temp.sh k3s-agent/k3s-agent-$i.sh
        sed -i "s|NAME|k3s-agent-$i|g" k3s-agent/k3s-agent-$i.sh
        sed -i "s|PUBLIC_IP|${ip_array[$i-1]}|g" k3s-agent/k3s-agent-$i.sh
    done
fi

if [ "$net" -eq 2 ]; then
    if [ "$select" -eq 1 ]; then
        if ! command -v caddy &> /dev/null
        then
            echo "caddy Not installed, install."
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
            sudo apt-get -y update
            sudo DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install caddy
        else
            green_echo "caddy Already installed, skip installation."
        fi

        if ! command -v caddy &> /dev/null
        then
            red_echo "caddy Installation failed."
        else
            green_echo "caddy Installation Successful."
            mkdir -p caddy
            mv ./config-auto/caddy/Caddyfile ./caddy/
            
            cd caddy
            nohup caddy run > caddy.log 2>&1 &
            PID_TO_CHECK=$!

            if ps -p $PID_TO_CHECK > /dev/null
            then
                green_echo "caddy Process is running."
            else
                red_echo "caddy Startup failure！"
            fi
            cd ../
        fi
    else
        echo "Unresolved domain name, skip caddy configuration..."
    fi
else
    echo "Intranet deployment, skip caddy configuration..."
fi

rm -rf config-auto

cd GZCTF
docker compose up -d
if [ $? -eq 0 ]; then
    green_echo "GZCTF Startup Success."
else
    red_echo "GZCTF Startup failed."
    exit 1
fi

green_echo "============"
green_echo "||Deployment Success!||"
green_echo "============"

echo "==============================================================================================================="

if [ "$setup" -eq 2 ]; then
    echo "---------------------------------------------------------------------------------------------------------------"
    if [ "$hostNum" -eq 0 ]; then
        green_echo "Currently it is a single machine deployment, no need to execute the node machine joining script"
    else
        green_echo "Please copy the script in the k3s-agent folder to the corresponding other node machines and execute k3s-agent-*.sh"
    fi
    echo "If you add a new machine, please use the k3s-agent folder add-agent.sh Script added, and please add manually <ip> <hostname> To this machine /etc/hosts 中"
    echo "How to use: bash add-agent.sh [ip] [hostname]"
    echo "Where ip is the ip address of the newly added machine,  hostname is the hostname of the newly added machine, both are required"
    echo "The host name must meet the following standards: the length must be between 1 and 255 characters, and can only contain letters, numbers, and hyphens. It must not be the same as an existing host name.！！！"
    echo "例如: bash add-agent.sh 10.10.10.10 k3s-agent-example"
    green_echo "If you need to use QQ robot, you can use the project: https://github.com/MoRan23/GZCTF-BOT-QQ"
    echo "---------------------------------------------------------------------------------------------------------------"
fi

green_echo "GZCTF The relevant files have been saved in the GZCTF folder in the current directory"
if [ "$net" -eq 2 ]; then
    if [ "$select" -eq 1 ]; then
        green_echo "CaddyThe relevant files have been saved in the caddy folder in the current directory"
    fi
fi

if [ "$net" -eq 2 ]; then
    if [ "$select" -eq 1 ]; then
        green_echo "Please visit https://$domain Perform subsequent configuration"
        green_echo "Or visit http://$public_ip:81 Perform subsequent configuration"
    else
        green_echo "Please visit http://$public_ip:$gz_port Perform subsequent configuration"
    fi
else
    green_echo "Please visit http://$private_ip:$gz_port Perform subsequent configuration"
fi
green_echo "username: admin"
green_echo "password: $adminpasswd"
echo "==============================================================================================================="
