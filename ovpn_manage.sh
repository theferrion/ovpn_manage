#!/bin/bash

#Changelog
#CentOS only.(version 7)
#add CentOS version 8
#27.09.2021 add Ubuntu 20.04
#10.08.2023 add local git repository.

#Error Code:
#100 Directory not exist
#101 File not exist
#102 Parameter false
#103 Other distrib

#https://accounts.google.com/DisplayUnlockCaptcha
#This link need for unlock email via gmail

#sudo iptables -t nat -A POSTROUTING -s 10.34.1.0/24 -o eth0 -j MASQUERADE
#net.ipv4.ip_forward = 1 /etc/sysctl.conf
#sysctl -p


Check_dirs_files () {
	if [ ! -f $CA ]; then
		echo "CA file dos not exist"
		echo "copy or create CA cert"
	fi


	if [ ! -d $DIR_OPENVPN ]; then
		echo "Directory openvpn dos not exist!!!"
		echo "Openvpn installed???"
		exit 100
	fi

	if [ ! -d /var/log/openvpn/ ]; then
		echo "Create logs directory for openvpn"
		mkdir /var/log/openvpn/
	fi

	if [ ! -d $DIR_INFR_KEYS ]; then
		echo "Directory pki infrastructure does not exist!!!"
		echo "wget https://github.com/OpenVPN/easy-rsa/archive/master.zip"
		echo "or yum install easyrsa"
		exit 100
	fi
}

Check_Dir_Easyrsa () {
	if [ ! -d $DIR_EASYRSA ]; then
		echo "Directory easyrsa not exist"
		echo "create this directory"
		mkdir -p $DIR_EASYRSA
	else echo "Директоря $DIR_EASYRSA существует. Возможно надо всё в ней удалить..."
		read -p "Удалить всё в директории $DIR_EASYRSA ? yes/no " yesno
		if [ "$yesno" = "yes" ]; then
			rm -rf $DIR_EASYRSA/*
		elif [ "$yesno" = "no" ]; then
			echo "Не трогаю директорию $DIR_EASYRSA. Ты уверен(а)?"
		else echo "Надо было набрать yes или no. Пропускаем."
			exit 102
		fi
	fi
}

Select_install_method () {
	if [ "${CA_LOCATION}" = "local" ]; then
		Create_local_ca_pki_infrs
	elif [ "${CA_LOCATION}" = "remote" ]; then
		Create_pki_infrs
	else echo "Не указано, где расположен ЦС. Выходим."
		exit 102
	fi
}

Define_OS_and_ver () {
	distr_name=`cat /etc/os-release | grep ^NAME | awk -F"\"" '{print $2}'`
	distr_ver=`cat /etc/os-release | grep ^VERSION_ID | awk -F"\"" '{print $2}'`
	if [ "$distr_name" = "CentOS Linux" ]; then
		DIR_OPENVPN_CONFS="/etc/openvpn"
		if [ $distr_ver -eq "7" ]; then
			secret_param_ovpn_ta="--secret" #Переменная нужна для правильного формирования ключа ta.key
			easyrsa_params="build-client-full $NAME_CRT nopass" #Переменная нужня для создания пользовательсного сертификата
		elif [ $distr_ver -eq "8" ]; then
			easyrsa_params="build-client-full $NAME_CRT nopass inline" #Переменная нужня для создания пользовательсного сертификата
		else echo "this is distrib CentOS or RedHat Linux???"
		exit 103
		fi
	elif [ "$distr_name" = "Ubuntu" ]; then
		DIR_OPENVPN_CONFS="/etc/openvpn/server"
		secret_param_ovpn_ta="secret" #Переменная нужна для правильного формирования ключа ta.key
		easyrsa_params="build-client-full $NAME_CRT nopass inline" #Переменная нужня для создания пользовательсного сертификата
		else echo "this is distrib Ubuntu???"
		exit 103
	fi
}

Install_packeges () {
	#Устанавливаем epel-release репозиторий, zip, unzip, wget, openvpn. Скачиваем и распаковываем easyrsa. Создаём инфраструктуру ключей.
	Define_OS_and_ver
	if [ "$distr_name" = "CentOS Linux" ]; then
		DIR_OPENVPN_CONFS="/etc/openvpn"
		if [ $distr_ver -eq "7" ]; then
			Install_packets_for_centos_7
		elif [ $distr_ver -eq "8" ]; then
			Install_packets_for_centos_8
		fi
	elif [ "$distr_name" = "Ubuntu" ]; then
		DIR_OPENVPN_CONFS="/etc/openvpn/server"
		Install_packets_for_Ubuntu
	fi
}

Install_packets_for_centos_7 () {
	if [ "${CA_LOCATION}" = "local" ]; then
		PARAM_PKG_MNGR="openvpn tofrodos.x86_64 mutt git"
	elif [ "${CA_LOCATION}" = "remote" ]; then
		PARAM_PKG_MNGR="tofrodos.x86_64 mutt git"
	fi
	PKG_MNGR=yum
	sudo $PKG_MNGR -y install epel-release
	sudo $PKG_MNGR -y install ${PARAM_PKG_MNGR}
	git clone $EASYRSA_URL
	if [ "$?" -eq "0" ]; then
		ln -s $DIR_EASYRSA/easyrsa3/* $DIR_EASYRSA
	else echo "Download git repository easy-rsa not complite!!! Correct this. Exit!"
		exit 101
	fi	
	sudo mkdir ${DIR_OPENVPN_KEYS} -p
	sudo mkdir /var/log/openvpn
	mkdir ${DIR_OPENVPN_KEYS_CLIENTS} -p
	mkdir ${CONF_FILES_DIR}
	sudo semanage port -a -t openvpn_port_t -p $OPENVPN_PROTO $OPENVPN_PORT #SeLinux
}

Install_packets_for_centos_8 () {
	if [ "${CA_LOCATION}" = "local" ]; then
		PARAM_PKG_MNGR="openvpn zip unzip wget easy-rsa.noarch tofrodos.x86_64 mutt"
	elif [ "${CA_LOCATION}" = "remote" ]; then
		PARAM_PKG_MNGR="zip unzip wget easy-rsa.noarch tofrodos.x86_64 mutt"
	fi
	PKG_MNGR=yum
	sudo $PKG_MNGR -y install epel-release.noarch
	sudo $PKG_MNGR -y install ${PARAM_PKG_MNGR}
	sudo mkdir ${DIR_OPENVPN_KEYS} -p
	ln -s /usr/share/easy-rsa/3/* $DIR_EASYRSA
	mkdir ${DIR_OPENVPN_KEYS_CLIENTS} -p
	mkdir ${CONF_FILES_DIR}
}

Install_packets_for_Ubuntu () {
	if [ "${CA_LOCATION}" = "local" ]; then
		PARAM_PKG_MNGR="openvpn easy-rsa tofrodos mutt msmtp"
	elif [ "${CA_LOCATION}" = "remote" ]; then
		PARAM_PKG_MNGR="easy-rsa tofrodos mutt msmtp"
	fi
	sudo apt update
	sudo apt install ${PARAM_PKG_MNGR} -y
	sudo mkdir ${DIR_OPENVPN_KEYS} -p
	ln -s /usr/share/easy-rsa/* $DIR_EASYRSA
	mkdir ${DIR_OPENVPN_KEYS_CLIENTS} -p
	mkdir ${CONF_FILES_DIR}
}

Create_vars_file_for_easyrsa () {
	for_who=$1
	if [ "$for_who" = "openvpn" ]; then
		cat <<EOF > ${DIR_INFR_KEYS}/vars
set_var EASYRSA_ALGO            "ec"
set_var EASYRSA_DIGEST          "sha512"
set_var EASYRSA_CURVE           "secp384r1"
EOF
		return
	else
		cat <<EOF > ${DIR_INFR_KEYS}/vars
set_var EASYRSA_REQ_COUNTRY     "${EASYRSA_REQ_COUNTRY}"
set_var EASYRSA_REQ_PROVINCE    "${EASYRSA_REQ_PROVINCE}"
set_var EASYRSA_REQ_CITY        "${EASYRSA_REQ_CITY}"
set_var EASYRSA_REQ_ORG			"${EASYRSA_REQ_ORG}"
set_var EASYRSA_REQ_EMAIL       "${EASYRSA_REQ_EMAIL}"
set_var EASYRSA_REQ_OU          "${EASYRSA_REQ_OU}"
set_var EASYRSA_KEY_SIZE		"${EASYRSA_KEY_SIZE}"
set_var EASYRSA_CA_EXPIRE		"${EASYRSA_CA_EXPIRE}"
set_var EASYRSA_CERT_EXPIRE		"${EASYRSA_CERT_EXPIRE}"
set_var EASYRSA_CERT_RENEW		"${EASYRSA_CERT_RENEW}"
set_var EASYRSA_CRL_DAYS		"${EASYRSA_CRL_DAYS}"
EOF
	fi
	Create_conf_template
	Create_muttrc
	Create_msmtprc
	#Create_ovpn_server_conf
}

Create_local_ca_pki_infrs () {
	echo "Этот скрипт разворачивает CA(Certificate authority), устанавливает OpenVPN, создаёт сертификаты и управляет ими."
	echo "Надо определить, где находится(или будет находиться) сам сервер с OpenVPN: на этой машине или другой."
	echo "От этого зависит будут ли копироваться конфиги для сервера локально или их нужно будет переносить самостоятельно."
	echo "Также это определит будет ли устанавилваться сам OpenVPN или нет. В первом случае да, во втором - нет."
	echo "1) Сервер OpenVPN находится на этой машине. Этот вариант выбирается по умолчанию."
	echo "2) Он находятся на другой машине."
	read ca_location
	case "$ca_location" in
		1 ) CA_LOCATION="local";;
		2 ) CA_LOCATION="remote";;
	esac
	if [ -z "${CA_LOCATION}" ];then
		CA_LOCATION="local"
	fi
	echo "CA_LOCATION=${CA_LOCATION}"
	Check_Dir_Easyrsa
	Install_packeges
	cd $DIR_EASYRSA
	echo "Создаем структуру публичных PKI ключей:"
	$EASYRSA init-pki #Создаем структуру публичных PKI ключей
	echo
	echo "Создаём предварительно настроенный файл vars"
	Create_vars_file_for_easyrsa ca
	read -n1 -p "Поправь или проверь конфиг vars. Лежит в папке ${DIR_EASYRSA}/pki. Минимальные настройки уже проведены. См. функцию Create_vars_file_for_easyrsa в этом скрипте. И потом нажми здесь любую клавишу"
	echo
	echo "Создаём удостоверяющий центр CA:"
	$EASYRSA build-ca nopass #Создайём удостоверяющий центр CA
	echo
	Create_dh_key
	echo
	echo "Создаем запрос сертификата для сервера:"
	$EASYRSA gen-req $NAME_CRT nopass
	echo
	echo "Подписываем запрос на получение сертификата у нашего CA:"
	$EASYRSA --batch sign-req server $NAME_CRT
	echo
	#echo "Создаём полный набор ключей для сервера и файл со всеми этими ключами и сертификатами."
	#./easyrsa build-server-full $NAME_CRT nopass inline
	echo "Создаём ключ ta.key"
	openvpn --genkey ${secret_param_ovpn_ta} $TA_KEY
	echo
	#Формируем список отозванных сертификатов.
	$EASYRSA gen-crl
	echo "Создаём конфиг сервера server.conf"
	Create_ovpn_server_conf
	echo
	if [ "${CA_LOCATION}" = "local" ]; then
		Copy_Files
	elif [ "${CA_LOCATION}" = "remote" ]; then
		read -n1 -p "Жми любую any key и да будет Выход."
		exit 0
	fi
	
}

Copy_Files () {
	echo "Создаём диресторию $DIR_OPENVPN/ccd, если она ещё не существует"
	if [ ! -d $DIR_OPENVPN/ccd ]; then
		sudo mkdir $DIR_OPENVPN/ccd
	fi
	echo
	echo "Копируем ключи и конфиг по директориям."
	sudo cp $TA_KEY $CA $CRT $KEY ${CRL_PEM} ${DIR_OPENVPN_KEYS}
	sudo cp $SERVER_CONF $DIR_OPENVPN_CONFS
	echo
	echo "Теперь отредактируй конфиг openvpn и затем можно будет создавать ключи и конфиги для клиентов. А теперь выход."
	echo "Да, не забудь настроить firewall. Читай маны по нему."
	read -n1 -p "Жми любую any key и да будет Выход."
	exit 0
}

Create_dh_key () {
	read -p "Создать ключ Диффи-Хелмана? (yes/no) " dh
	if [ $dh = "yes" ]; then
		echo "Создаем ключ Диффи-Хеллмана"
		$EASYRSA gen-dh #Создаем ключ Диффи-Хеллмана
		sudo cp $DH_KEY $DIR_OPENVPN_KEYS
		DH_NO=0
	elif [ $dh = "no" ]; then
	       echo "Не создаём ключ Диффи-Хелмана. Значит в конфиге openvpn надо указат \"dh none\""
	       echo "Возможно, надо в конфиг добавить параметр \"ecdh-curve secp384r1\""
		   DH_NO=1
	else 
		echo "Надо было набрать yes или no. По умолчанию будет без ключа Диффи-Хелмана, с эллиптическими кривыми."
		DH_NO=1
	fi
}

Create_Certs () {
	echo "This is func Create_Certs"
	cd ${DIR_EASYRSA}
	echo "Создаём клиентский сертификат"
	#Создаём клиентские сертификаты.
	#У CentOS 7 старый openssl. И при создании пользовательского сертификата предупреждает, что не поддерживается опция "-ext". При этом сертификат создаётся и подключение работает.
	$EASYRSA $easyrsa_params
	echo "End func Create_Certs"
}

Create_Configs () {
	#Создаём конфиги для винды и линукса
	if [ ! -d $CONF_FILES_DIR ]; then
		echo "Directory with confs dos not exist"
		exit 100
	fi
	if [ ! -f $TMPL_CONF_CONF ]; then
		echo "Template file for clients dos not exist"
		echo "Create it."
		exit 101
	fi
	if [ ! -f $CRT ]; then
		echo "Certificate file $NAME_CRT.crt dos not exist"
		echo "Create it and try again"
		exit 101
	fi
	if [ ! -f $KEY ]; then
		echo "Key file $NAME_CRT.key dos not exist"
		echo "Create it and try again"
		exit 101
	fi

	cd $CONF_FILES_DIR
	#cp $TMPL_CONF_OVPN $CONF_FILE_WINDOWS
	cp $TMPL_CONF_CONF $CONF_FILE_LINUX

	#echo "" >> $CONF_FILE_WINDOWS
	#echo "<ca>" >> $CONF_FILE_WINDOWS
	#cat $CA >> $CONF_FILE_WINDOWS
	#echo "</ca>" >> $CONF_FILE_WINDOWS
	#echo "<cert>" >> $CONF_FILE_WINDOWS
	#cat $CRT >> $CONF_FILE_WINDOWS
	#echo "</cert>" >> $CONF_FILE_WINDOWS
	#echo "<key>" >> $CONF_FILE_WINDOWS
	#cat $KEY >> $CONF_FILE_WINDOWS
	#echo "</key>" >> $CONF_FILE_WINDOWS
        #echo "<tls-crypt>" >> $CONF_FILE_WINDOWS
        #cat $TA_KEY >> $CONF_FILE_WINDOWS
        #echo "</tls-crypt>" >> $CONF_FILE_WINDOWS
	#Конвертируем конец строки для винды.

	echo "" >> $CONF_FILE_LINUX
        echo "<ca>" >> $CONF_FILE_LINUX
        cat $CA >> $CONF_FILE_LINUX
        echo "</ca>" >> $CONF_FILE_LINUX
        echo "<cert>" >> $CONF_FILE_LINUX
        cat $CRT >> $CONF_FILE_LINUX
        echo "</cert>" >> $CONF_FILE_LINUX
        echo "<key>" >> $CONF_FILE_LINUX
        cat $KEY >> $CONF_FILE_LINUX
        echo "</key>" >> $CONF_FILE_LINUX
        echo "<tls-crypt>" >> $CONF_FILE_LINUX
        cat $TA_KEY >> $CONF_FILE_LINUX
        echo "</tls-crypt>" >> $CONF_FILE_LINUX

	cp $CONF_FILE_LINUX $CONF_FILE_WINDOWS

	$PROGRAMM_CONVERT_CRLF $PARAMETERS_PROGRAMM_CONVERT_CRLF $CONF_FILE_WINDOWS

	#---------------------------- Test to future ------------------------
#	cat ${BASE_CONFIG} \
#    <(echo -e '<ca>') \
#    ${KEY_DIR}/ca.crt \
#    <(echo -e '</ca>\n<cert>') \
#    ${KEY_DIR}/${1}.crt \
#    <(echo -e '</cert>\n<key>') \
#    ${KEY_DIR}/${1}.key \
#    <(echo -e '</key>\n<tls-auth>') \
#    ${KEY_DIR}/ta.key \
#    <(echo -e '</tls-auth>') \
#    > ${OUTPUT_DIR}/${1}.ovpn
	#------------------------------ End ---------------------------------
}

Sent_Email () {
        echo "Внимание!!! Передача конфигов по почте потенциально не безопопасный метод!"
		echo "Укажите емаил на какой высылать конфиг (Enter email address)"
        read Email
        echo "Выбрать от 1 до 3"
        echo "1) Отправить конфиг только для винды"
        echo "2) Отправить конфиг только для линукс"
        echo "3) Отправить оба конфига"
        read how_many_sent_files
        case "$how_many_sent_files" in
                1 ) echo "" | mutt -F ${CONF_MUTT} -s "Config file $NAME_CRT for openvpn" -a $CONF_FILE_WINDOWS -- $Email;;
                2 ) echo "" | mutt -F ${CONF_MUTT} -s "Config file $NAME_CRT for openvpn" -a $CONF_FILE_LINUX -- $Email;;
                3 ) echo "" | mutt -F ${CONF_MUTT} -s "Config file $NAME_CRT for openvpn" -a $CONF_FILE_WINDOWS $CONF_FILE_LINUX -- $Email;;
        esac
}

Revoke_Cert () {
	echo "Отзываем сертификат"
	cd $DIR_EASYRSA
	$EASYRSA revoke $NAME_CRT
	$EASYRSA gen-crl
	echo "Копируем список отозванных сертификатов в нужную директорию."
	sudo cp ${CRL_PEM} ${DIR_OPENVPN_KEYS}
	read -n1 -p "Restart openvpn. Press any key."
	sudo systemctl restart openvpn-server@server.service
	sudo systemctl status openvpn-server@server.service
}

List_Certs () {
echo ""
#sh -c "ls $CRT_DIR/*.crt" | awk -F / '{print $6}'
List_certs=`ls $CRT_DIR/*.crt`
for i in $List_certs
do
	basename $i | awk -F'.' '{print $1}'
done
}

Delete_all_keys_and_easyrsa () {
	echo "Удаление ВСЕХ ключей."
	echo "Удаляем ВСЕ ключи для того, чтобы развернуть инфраструктуру с НУЛЯ."
	echo "Будь внимателен(льна) АЛАРМ!!! ВАРНИНГ!!! АХТУНГ!!! ВНИМАНИЕ!!!"
	while true
	do
		read -p "Сейчас удалю ВСЕ ключи. Это то что нужно? (yes/no)" yesno
		if [ "$yesno" = "yes" ]; then
			sudo rm -rf $DIR_OPENVPN_KEYS/*
			rm -rf $DIR_EASYRSA
			if [ "$?" -eq "0" ];then
				echo "Файлы удалены"
			else echo "Файлы не удалены."
			fi
			break
		elif [ "$yesno" = "no" ]; then
			break
		else echo "Надо набрать yes или no. Будь внимательнее!"
		fi
	done
}


Get_name_crt () {
echo "Укажите имя сертификата."
echo "Скрипт принимает параметр имени сертификата без расширения. Желательно указывать осмысленное название. Например, buhgalteriya"
echo "Если разворачиваем первый раз openvpn на сервере, то лучше указать имя сервера. Например, server-vpn"
read NAME_CRT
echo
if [ -z "$NAME_CRT" ]; then
        echo "Надо указать имя сертификата. Пример: alex"
        echo "Enter certificate name. Example: alex"
       exit 102
sleep 2
fi
}

Create_conf_template () {
cat <<EOF > ${TMPL_CONF_CONF}
client
dev tun0
proto $OPENVPN_PROTO
remote $OPENVPN_IP
port $OPENVPN_PORT
resolv-retry infinite
nobind
keepalive 10 120
persist-key
persist-tun
#ns-cert-type server
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
key-direction 0
comp-lzo
verb 1
EOF

cat <<EOF > ${TMPL_CONF_OVPN}
client
dev tun
proto $OPENVPN_PROTO
remote $OPENVPN_IP $OPENVPN_PORT
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
key-direction 0
topology subnet
comp-lzo
verb 1
EOF
}

Create_muttrc () {
cat <<EOF > ${CONF_MUTT}
set realname='root from $NAME_CRT'
set from='$MSMTPRC_EMAIL'
set sendmail="/usr/bin/msmtp --file=${CONF_MSMTP}"
set envelope_from=yes
EOF
}

Create_msmtprc () {
cat <<EOF > ${CONF_MSMTP}
defaults
logfile ~/.msmtp.log
tls on
tls_starttls on
tls_certcheck off
# Gmail
account         gmail
auth            on
host            smtp.gmail.com
port            587
from            $MSMTPRC_EMAIL
user            $MSMTPRC_USER
password        $MSMTPRC_PASSWORD
EOF
chmod 0600 ${CONF_MSMTP}

}

Create_ovpn_server_conf () {
	if [ "$DH_NO" -eq "1" ]; then
		echo_dh=$(cat <<EOF
dh none
ecdh-curve secp384r1
EOF
)
		elif [ "$DH_NO" -eq "0" ]; then
			echo_dh="dh $DIR_OPENVPN_KEYS/dh.key"
		else echo "Что-то пошло не так с ключом Диффи-Хелмана"
	fi
	
	if [ "$distr_name" = "Ubuntu" ]; then
		group_name="nogroup"
		elif [ "$distr_name" = "CentOS Linux" ]; then
		group_name="nobody"
		else group_name="nobody"
	fi

	read -n1 -p "Функция Create_ovpn_server_conf"
	echo
cat <<EOF > ${SERVER_CONF}
port $OPENVPN_PORT
multihome
proto $OPENVPN_PROTO
dev tun0
ca ${DIR_OPENVPN_KEYS}/ca.crt
cert ${DIR_OPENVPN_KEYS}/${NAME_CRT}.crt
key ${DIR_OPENVPN_KEYS}/${NAME_CRT}.key
tls-crypt ${DIR_OPENVPN_KEYS}/ta.key
crl-verify ${DIR_OPENVPN_KEYS}/crl.pem
${echo_dh}
topology subnet
server $OPENVPN_NETWORK $OPENVPN_NETWORK_MASK
client-to-client
client-config-dir ${DIR_OPENVPN}/ccd
keepalive 10 120
cipher AES-256-GCM
auth SHA256
#compress lz4-v2
tls-server
comp-lzo
max-clients 100
key-direction 1
user nobody
group ${group_name}
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 1
explicit-exit-notify 1
EOF
	read -n1 -p "Конец функции Create_ovpn_server_conf"
	echo
}

clear
if [ "$NAME_CRT" = "" ]; then
	Get_name_crt
fi



CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $CURRENT_DIR/vars
Define_OS_and_ver

echo "При настройке может понадобиться второе подклчючение к серверу для редактирования или просмотра файлов."
echo "Файл vars в той же директории, что и этот скрипт должен быть настроен. В нём должны быть указаны правильные переменные."
echo "Также нужно настроенное sudo"
while true
do
echo ""
echo "0) Выход (Exit)"
echo "1) Развернуть openvpn, easyrsa(CA) и инфраструктуру ключей."
echo "2) Создать для клиента сертификат, ключ, конфиг для OpenVPN и отправить на почту."
echo "3) Создать клиентский конфиг для OpenVPN и отправить его на почту."
echo "4) Создать клиентский конфиг для OpenVPN."
echo "5) Созадть для клиента сертификат, ключ и конфиг для OpenVPN."
echo "6) Отправить клиентский конфиг для OpenVPN по почте."
echo "7) Отзыв клиентского сертификата."
echo "8) Список созданных клиентских сертификатов."
echo "9) Изменить имя сертификата."
echo "00) Удаляем все ключи. АЛАРМ!!! Это удалит всю инфраструктуру ключей!!!"

read press_button
case "$press_button" in
	0 ) exit 0;;
	1 ) Create_local_ca_pki_infrs;;
	2 ) Check_dirs_files
		Create_Certs
		Create_Configs
		Sent_Email;;
	3 ) Create_Configs
		Sent_Email;;
	4 ) Create_Configs;;
	5 ) Check_dirs_files
		Create_Certs
		Create_Configs;;
	6 ) Sent_Email;;
	7 ) Revoke_Cert;;
	8 ) List_Certs;;
	9 ) Get_name_crt;;
	00 ) Delete_all_keys_and_easyrsa;;
esac
done

exit 0