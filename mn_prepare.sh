#!/bin/bash

COIN_NAME='Aywa'
NEWUSERNAME='aywa'

EXTERNAL_IP=$(curl -s4 icanhazip.com)
INTERNAL_IP=$(ifconfig | grep -A 1 $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}') | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)
export MN_COUNT=1

BLUE="\033[0;34m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
PURPLE="\033[0;35m"
RED='\033[0;31m'
GREEN="\033[0;32m"
NC='\033[0m'
MAG='\e[1;35m'



function add_user(){

	echo -e  'Enter new or exist username (non root) for the MN Installation (ssh will be disabled for root):'
	read -e NEWUSERNAME
	useradd -m $NEWUSERNAME
	#-p $NEW_USER_PASS	
	passwd $NEWUSERNAME
	echo Added $NEWUSERNAME with pass $NEWUSERNAME
	#add it to sudoers
	usermod -aG sudo $NEWUSERNAME
	#allow ssh
	#does AllowUsers section already exists at sshd_config?
	
	#grep -crnw '/etc/ssh/sshd_config' -e 'AllowUsers'
	
	grep -q "AllowUsers $NEWUSERNAME" /etc/ssh/sshd_config
	if [ $? -ne 0 ]; then
		echo "Allow ssh for $NEWUSERNAME"
		rem echo "AllowUsers $NEWUSERNAME" >> /etc/ssh/sshd_config
	else
		echo 'no changes needed'
	fi
        grep -q "DenyUsers root" /etc/ssh/sshd_config
        if [ $? -ne 0 ]; then
                echo "Deny ssh for root"
                rem echo "DenyUsers root" >> /etc/ssh/sshd_config
        else
                echo 'no changes needed'
        fi

}

function add_swap() {
	# size of swapfile in megabytes
	swapsize=4096

	# does the swap file already exist?
	grep -q "swapfile" /etc/fstab

	# if not then create it
	if [ $? -ne 0 ]; then
		echo 'swapfile not found. Adding swapfile.'
		sudo fallocate -l ${swapsize}M /swapfile
		sudo chmod 600 /swapfile
		sudo mkswap /swapfile
		sudo swapon /swapfile
		echo '/swapfile none swap defaults 0 0' >> sudo /etc/fstab
	else
		echo 'swapfile found. No changes made.'
	fi

	# output results to terminal
	cat /proc/swaps
	cat /proc/meminfo | grep Swap
}


function install_dependencies() {

echo -e "Preparing the VPS to setup. ${CYAN}$COIN_NAME${NC} ${RED}Masternode${NC}"
sudo apt-get update
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade
sudo apt install -y software-properties-common
echo -e "${PURPLE}Adding bitcoin PPA repository"
sudo apt-add-repository -y ppa:bitcoin/bitcoin
echo -e "Installing required packages, it may take some time to finish.${NC}"
sudo apt-get update
sudo apt-get install libzmq3-dev ufw python virtualenv git fail2ban python-virtualenv -y 
sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev  libdb5.3++ unzip libzmq5
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev libdb5.3++ unzip libzmq5"
 exit 1
fi
#clear 
}


#declare -f download_aywacore

function download_aywacore() {

#sudo su $NEWUSERNAME; exit

cd ~
mkdir -p ~/.masternodes
mkdir -p ~/tmp
cd tmp
rm -f aywacore_cli_ubuntu1604.tar.gz
wget https://github.com/GetAywa/AywaCore/releases/download/v0.1.2.1/aywacore_cli_ubuntu1604.tar.gz
tar -zxvf aywacore_cli_ubuntu1604.tar.gz
mkdir -p ~/aywacore/bin
mv ~/tmp/aywad ~/aywacore/bin
mv ~/tmp/aywa-cli ~/aywacore/bin

cd ~ && git clone https://github.com/GetAywa/Aywa_Masternode

export LC_ALL=C
virtualenv ~/Aywa_Masternode/sentinel/.venv
 ~/Aywa_Masternode/sentinel/.venv/bin/pip install -r ~/Aywa_Masternode/sentinel/requirements.txt

echo 'Ready for setup MN'
echo -e ''
}


function install_sentinel () {

for i in `seq 1 $MN_COUNT` ;
do
echo $i
                mkdir -v -p ~/.masternodes/node$i
                cd ~/.masternodes/node$i
                mkdir -v -p ~/.masternodes/node$i/sentinel		
		ln -v -s ~/Aywa_Masternode/sentinel/bin ~/.masternodes/node$i/sentinel
		ln -v -s ~/Aywa_Masternode/sentinel/share ~/.masternodes/node$i/sentinel
		ln -v -s ~/Aywa_Masternode/sentinel/lib ~/.masternodes/node$i/sentinel
		ln -v -s ~/Aywa_Masternode/sentinel/sentinel.conf ~/.masternodes/node$i/sentinel

done
}




##### Main #####

#clear
MN_COUNT="$1"
MN_USER="$2"
MN_USER_PASS="$3"
add_user
add_swap
install_dependencies
su $NEWUSERNAME -c "$(declare -f download_aywacore); download_aywacore"
su $NEWUSERNAME -c "$(declare -f install_sentinel); install_sentinel"
echo "You dot't need to use root and sudo for Aywa MN management. Logon ssh again with user: $NEWUSERNAME"
echo 'MN Server need to Reboot to continue MN installation? Are you ready(y/n)' && read x && [[ "$x" == "y" ]] && /sbin/reboot
