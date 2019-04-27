#!/bin/bash
# set -v on
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'

if [ $(uname) != "Linux" ];then
echo -e "\033[31m This script is only for Linux! \033[0m"
exit 1
fi

[[ $EUID -ne 0 ]] && echo -e " ${RED}Error:${PLAIN} This script must be run as root!" && exit 1

if [ -f /etc/redhat-release ]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
fi

setMirrors() {
    if [ $release == "ubuntu" ];then
        sed -i 's|archive.ubuntu.com|mirrors.ustc.edu.cn|g' /etc/apt/sources.list
        sed -i 's|archive.ubuntu.com|mirrors.ustc.edu.cn|g' /etc/apt/sources.list.d/*.list
    elif [ $release == "debian" ];then
        sed -i 's|deb.debian.org|mirrors.ustc.edu.cn|g' /etc/apt/sources.list
        sed -i 's|deb.debian.org|mirrors.ustc.edu.cn|g' /etc/apt/sources.list.d/*.list
        sed -i 's|security.debian.org/debian-security|mirrors.ustc.edu.cn/debian-security|g' /etc/apt/sources.list
        sed -i 's|security.debian.org/debian-security|mirrors.ustc.edu.cn/debian-security|g' /etc/apt/sources.list.d/*.list
    elif [ $release == "centos" ];then
        echo "${YELLOW}This script does not support Centos replacement source!${PLAIN}"
    fi
    apt update
    apt upgrade
}
installZsh() {
    apt-get install zsh
    chsh -s /bin/zsh
    set -i 's|/bin/bash|/bin/zsh|g' /etc/passwd
    apt-get install git
    sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
    apt-get install autojump
    echo ". /usr/share/autojump/autojump.sh" >> ~/.zshrc
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
    mv zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
    echo "source \$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc
    # zsh
    git clone https://github.com/zsh-users/zsh-autosuggestions.git
    mv zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
    sed -i 's|plugins=(|plugins=(zsh-autosuggestions |g' ~/.zshrc
    echo "source \$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" >> ~/.zshrc
    sed -i 's|ZSH_THEME="robbyrussell"|ZSH_THEME="agnoster"|g' ~/.zshrc
    echo "export TERM=xterm-256color" >> ~/.zshrc
    source ~/.zshrc
}
installDocker() {
    curl -sSL https://get.docker.com/ | sh
    curl -L https://github.com/docker/compose/releases/download/1.17.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    if [ $1 != "null" ];then
        mkdir -p /etc/docker
        echo "{" > /etc/docker/daemon.json
        echo '  "registry-mirrors": ["'$1'"]' >> /etc/docker/daemon.json
        echo "}" >> /etc/docker/daemon.json
        systemctl daemon-reload
        systemctl restart docker
    fi
}
installGitea() {
    docker run -d --name=gitea -p $1:22 -p $2:3000 -v $3:/data gitea/gitea:latest
}
installJenkins() {
    docker run -itd -p $1:8080 -p $2:50000 --name jenkins --privileged=true  -v $3:/var/jenkins_home jenkins/jenkins:latest
    docker stop jenkins
    chown -R 1000:1000 $3
    docker start jenkins
}
installSonarqube() {
    mkdir $2
    cd $2
    wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-7.7.zip
    unzip sonarqube-7.7.zip
    cd sonarqube-7.7
    mv conf ../
    mv data ../
    mv extensions ../
    mv logs ../
    cd ../
    rm sonarqube-7.7* -rf
    cd ../
    chmod 777 -R sonarqube
    cd sonarqube/extensions/plugins
    wget https://github.com/SonarQubeCommunity/sonar-l10n-zh/releases/download/sonar-l10n-zh-plugin-1.27/sonar-l10n-zh-plugin-1.27.jar
    docker run -d --name sonarqube -p $1:9000 -v $2/conf:/opt/sonarqube/conf -v $2/data:/opt/sonarqube/data \\n-v $2/logs:/opt/sonarqube/logs -v $2/extensions:/opt/sonarqube/extensions -e SONARQUBE_JDBC_USERNAME=$3 -e SONARQUBE_JDBC_PASSWORD=$4 -e "SONARQUBE_JDBC_URL=jdbc:mysql://$5:3306/sonar?useUnicode=true&characterEncoding=utf8&rewriteBatchedStatements=true&useConfigs=maxPerformance&useSSL=false" sonarqube
}
installRuncher() {
    docker run -d --restart=unless-stopped -p $1:8080 rancher/server
}
installPortainer() {
    docker run -d -p $1:9000 -v /var/run/docker.sock:/var/run/docker.sock -v $2:/data portainer/portainer
}
installCodeServer() {
    docker run -it --name=code-server -p $1:8443 -p $2:$2 -v $3:/home/coder/project codercom/code-server --allow-http --password=$4
}
# main
# until [ -z $1 ]
# do
#     case $1 in
#
#     esac
# shift
# done
echo -e "------ Otstar-Cloud部署脚本 ------"
echo -e ""
echo -e "请选择你的操作"
echo -e "  ${YELLOW}1.${PLAIN} 设置镜像源"
echo -e "  ${YELLOW}2.${PLAIN} 安装Zsh,并进行相关配置"
echo -e "  ${YELLOW}3.${PLAIN} 安装Docker并配置镜像"
echo -e "  ${YELLOW}4.${PLAIN} 安装Gitea(Docker)"
echo -e "  ${YELLOW}5.${PLAIN} 安装Jenkins(Docker)"
echo -e "  ${YELLOW}6.${PLAIN} 安装Sonarqube(Docker)"
echo -e "  ${YELLOW}7.${PLAIN} 安装Runcher(Docker)"
echo -e "  ${YELLOW}8.${PLAIN} 安装Portainer(Docker)"
echo -e "  ${YELLOW}9.${PLAIN} 安装CodeServer(Docker)"
echo -e "  ${YELLOW}q.${PLAIN} 退出"

echo -e "请选择菜单:"
read operate

if [ $operate == "1" ];then
echo "operate 1"
setMirrors

elif [ $operate == "2" ];then
echo "operate 2"
installZsh

elif [ $operate == "3" ];then
echo "operate 3"
echo -e "请输入镜像地址？若输入${SKYBLUE}null${PLAIN}表示不设置:"
read dockermirror
installDocker $dockermirror

elif [ $operate == "4" ];then
echo "请输入SSH端口:"
read sshport
echo "请输入HTTP端口:"
read httpport
echo "请输入挂载的目录:"
read directory
installGitea $sshport $httpport $directory

elif [ $operate == "5" ];then
echo "请输入HTTP端口:"
read httpport
echo "请输入另一个端口:"
read otherport
echo "请输入挂载的目录:"
read directory
installJenkins $httpport $otherport $directory

elif [ $operate == "6" ];then
echo "请输入HTTP端口:"
read httpport
echo "请输入挂载的目录:"
read directory
echo "请输入Mysql用户名"
read mysqluser
echo "请输入Mysql密码"
read mysqlpasswd
echo "请输入Mysql地址"
read mysqlurl
installSonarqube $mysqluser $mysqlpasswd $mysqlurl

elif [ $operate == "7" ];then
echo "请输入HTTP端口:"
read httpport
installRuncher $httpport

elif [ $operate == "8" ];then
echo "请输入HTTP端口:"
read httpport
echo "请输入挂载的目录:"
read directory
installPortainer $httpport $directory

elif [ $operate == "9" ];then
echo "请输入HTTP端口:"
read httpport
echo "请输入其他要映射的端口"
read otherport
echo "请输入挂载的目录:"
read directory
echo "请设置登陆密码"
read passwd
installCodeServer $httpport $otherport $directory $passwd

elif [ $operate == "q" ];then
exit 0
fi
