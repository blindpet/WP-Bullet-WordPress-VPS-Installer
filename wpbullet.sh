#!/bin/bash

show_credentials() {
#--------------------------------------------------------------------------------------------------------------------------------
# Show credentials
#--------------------------------------------------------------------------------------------------------------------------------
echo "MySQL root password ${MYSQLROOTPASS}"
echo "WordPress MySQL username ${WORDPRESSSQLUSER}"
echo "WordPress MySQL password ${WORDPRESSSQLPASS}"
echo "WordPress MySQL database ${WORDPRESSSQLDB}"
}

clear_bash_history() {
#--------------------------------------------------------------------------------------------------------------------------------
# Erase bash history because we used MySQL root password
#--------------------------------------------------------------------------------------------------------------------------------
#http://askubuntu.com/questions/191999/how-to-clear-bash-history-completely
cat /dev/null > ~/.bash_history
}

get_user_input () {
#--------------------------------------------------------------------------------------------------------------------------------
# Get user input for WordPress
#--------------------------------------------------------------------------------------------------------------------------------
#generate random passwords http://www.howtogeek.com/howto/30184/10-ways-to-generate-a-random-password-from-the-command-line/
MYSQLROOTPASS=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
MYSQLROOTPASS=$(whiptail --inputbox "Choose the MySQL root password" 8 78 $MYSQLROOTPASS --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
WORDPRESSSQLDB=$(whiptail --inputbox "Choose the WordPress MySQL database name" 8 78 "WordPressDB" --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
WORDPRESSSQLUSER=$(whiptail --inputbox "Choose the WordPress MySQL user" 8 78 "WordPressMySQLuser" --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
WORDPRESSSQLPASS=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
WORDPRESSSQLPASS=$(whiptail --inputbox "Choose the WordPress MySQL password" 8 78 $WORDPRESSSQLPASS --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
WORDPRESSSITE=$(whiptail --inputbox "Choose the WordPress sitename" 8 78 "WP-Bullet.com" --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
}

install_nginx_varnish () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install nginx and Varnish
#--------------------------------------------------------------------------------------------------------------------------------
get_user_input
install_dotdeb
install_nginx
cp configs/wordpressvarnish /etc/nginx/sites-available/wordpress
ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress
sed -i s"/example.com/${WORDPRESSSITE}/g" /etc/nginx/sites-enabled/wordpress
install_mariadb
install_varnish
cp configs/default.vcl /etc/varnish/default.vcl
sed -i s"/Web.Server.IP/${SERVERIP}/" /etc/varnish/default.vcl
install_wordpress
service nginx restart
service php5-fpm restart
service varnish restart
show_credentials
clear_bash_history
}

install_nginx_varnish_haproxy () {
#--------------------------------------------------------------------------------------------------------------------------------
# install nginx with Varnish SSL Terminal from haproxy
#--------------------------------------------------------------------------------------------------------------------------------
get_user_input
install_dotdeb
install_nginx
install_mariadb
install_varnish
install_wordpress
install_haproxy
service nginx restart
service php5-fpm restart
service varnish restart
service haproxy restart
show_credentials
clear_bash_history
}

install_dotdeb () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install dotdeb repo
#--------------------------------------------------------------------------------------------------------------------------------
wget -qO - http://www.dotdeb.org/dotdeb.gpg | apt-key add -
cat > /etc/apt/sources.list.d/dotdeb.list<<EOF
deb http://packages.dotdeb.org jessie all
EOF
}

install_nginx () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install nginx
#--------------------------------------------------------------------------------------------------------------------------------
install_dotdeb
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install nginx -y
unlink /etc/nginx/sites-enabled/default
service nginx restart
}

install_wordpress () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install wordpress
#--------------------------------------------------------------------------------------------------------------------------------

debconf-apt-progress -- apt-get install curl php5-curl php5-mysql php5-cli php5-fpm php5-gd -y

mkdir -p /var/www/${WORDPRESSSITE}
cd /var/www/${WORDPRESSSITE}
wget http://wordpress.org/latest.tar.gz
tar --strip-components=1 -xf latest.tar.gz
rm latest.tar.gz
chown -R www-data:www-data /var/www/${WORDPRESSSITE}

mysql -u root -p${MYSQLROOTPASS} -e "CREATE USER ${WORDPRESSSQLUSER}@localhost IDENTIFIED BY '${WORDPRESSSQLPASS}';"
mysql -u root -p${MYSQLROOTPASS} -e "CREATE DATABASE ${WORDPRESSSQLDB};"
mysql -u root -p${MYSQLROOTPASS} -e "GRANT ALL PRIVILEGES ON ${WORDPRESSSQLDB}.* TO ${WORDPRESSSQLUSER}@localhost IDENTIFIED BY '${WORDPRESSSQLPASS}';"
mysql -u root -p${MYSQLROOTPASS} -e "FLUSH PRIVILEGES;"

cp /var/www/${WORDPRESSSITE}/wp-config-sample.php wp-config.php
#replace wp-config variables with the WordPress MySQL user and password
sed -i "/define('DB_NAME', 'database_name_here');/c\define('DB_NAME', '${WORDPRESSSQLDB}');" /var/www/${WORDPRESSSITE}/wp-config.php
sed -i "/define('DB_USER', 'username_here');/c\define('DB_USER', '${WORDPRESSSQLUSER}');" /var/www/${WORDPRESSSITE}/wp-config.php
sed -i "/define('DB_PASSWORD', 'password_here');/c\define('DB_PASSWORD', '${WORDPRESSSQLPASS}');" /var/www/${WORDPRESSSITE}/wp-config.php
chown -R www-data:www-data /var/www/${WORDPRESSSITE}/
chmod 755 /var/www/${WORDPRESSSITE}/
chmod 644 /var/www/${WORDPRESSSITE}/wp-config.php
}

install_mariadb () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install mariadb
#--------------------------------------------------------------------------------------------------------------------------------
debconf-apt-progress -- apt-get install debconf -y
echo "mariadb-server-10.0 mysql-server/root_password password ${MYSQLROOTPASS}" | debconf-set-selections
echo "mariadb-server-10.0 mysql-server/root_password_again password ${MYSQLROOTPASS}" | debconf-set-selections
debconf-apt-progress -- apt-get -y install mariadb-server mariadb-client
}

install_varnish (){
#--------------------------------------------------------------------------------------------------------------------------------
# Install high-performance HTTP accelerator
#-------------------------------------------------------------------------------------------------------------------------------- 
apt-get install apt-transport-https -y
wget -qO - https://repo.varnish-cache.org/GPG-key.txt | apt-key add -
cat > /etc/apt/sources.list.d/varnish-cache.list<<EOF
deb https://repo.varnish-cache.org/debian/ jessie varnish-4.1
EOF
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install varnish -y
mkdir -p /etc/systemd/system/varnish.service.d/
cat > /etc/systemd/system/varnish.service.d/local.conf<<EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/varnishd -a :80 -T localhost:6082 -f /etc/varnish/default.vcl -S /etc/varnish/secret -s malloc,256m
EOF
systemctl daemon-reload
mv /etc/varnish/default.vcl /etc/varnish/default.vcl.bak
}

install_haproxy () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install haproxy
#--------------------------------------------------------------------------------------------------------------------------------
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 1C61B9CD
cat > /etc/apt/sources.list.d/haproxy.list<<EOF
deb http://ppa.launchpad.net/vbernat/haproxy-1.6/ubuntu trusty main
EOF
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install openssl haproxy -y
#openssl req -new -newkey rsa:2048 -nodes -out wpbullet.pem -keyout wpbullet.pem -subj "/C=US/ST=Oregon/L=Portland/O=Company Name/OU=Org/CN=www.example.com"
openssl req -new -newkey rsa:2048 -nodes -out /etc/ssl/wpbullet.pem -keyout /etc/ssl/wpbullet.pem -subj "/CN=localhost"
}

install_webmin () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install webmin
#--------------------------------------------------------------------------------------------------------------------------------
#install csf with webmin module
sudo apt-get update
sudo apt-get install libauthen-pam-perl libio-pty-perl libnet-ssleay-perl libapt-pkg-perl apt-show-versions libwww-perl -y
cd /tmp
wget http://www.webmin.com/download/deb/webmin-current.deb
dpkg -i webmin*
}

install_csf () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install csf
#--------------------------------------------------------------------------------------------------------------------------------
#install csf
apt-get install iptables unzip -y
cd /tmp
wget https://download.configserver.com/csf.tgz
tar -xvf csf.tgz -C /opt
cd /opt/csf
bash /opt/csf/install.sh
#install csf webmin module
cd /usr/share/webmin
perl install-module.pl /etc/csf/csfwebmin.tgz
#install nginx webmin module
cd /tmp
wget http://www.justindhoffman.com/sites/justindhoffman.com/files/nginx-0.08.wbm__0.gz
cd /usr/share/webmin
perl install-module.pl /tmp/nginx-0.08.wbm__0.gz
#install opcache webmin module
#cd /tmp
#wget http://github.com/jesucarr/webmin-php-opcache-status/releases/download/v1.0/php-opcache-status.wbm.gz
#cd /usr/share/webmin
#perl install-module.pl /tmp/php-opcache-status.wbm.gz
#install php module
cd /tmp
wget http://www.webmin.com/webmin/download/modules/phpini.wbm.gz
cd /usr/share/webmin
perl install-module.pl /tmp/phpini.wbm.gz
echo "CSF Firewall is installed, configure it with this guide"
}

install_suhosin () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install suhosin
#--------------------------------------------------------------------------------------------------------------------------------
debconf-apt-progress -- apt-get install php5-dev git build-essential -y
cd /tmp
SUHOSINLATEST=$(wget -q -O - https://github.com/stefanesser/suhosin/releases/ | grep tar.gz | awk -F [\"] 'NR==1 {print $2}')
wget https://github.com$SUHOSINLATEST -O suhosin.tar.gz
tar -xvf suhosin.tar.gz
cd suhosin*
phpize
./configure
make
make install
PHPINI=($(find / -iname php.ini))
for ini in "${PHPINI[@]}"
do
  echo "extension=suhosin.so" >> "${ini}"
done
service php5-fpm restart
}

#--------------------------------------------------------------------------------------------------------------------------------
# WELCOME SCREEN
#--------------------------------------------------------------------------------------------------------------------------------

whiptail --title "Welcome to the WP Bullet WordPress VPS Installer" --msgbox "This Ubuntu and Debian Installer will prompt for credentials and autoconfigure everything" 8 78
#get ip
SERVERIP=$(ifconfig eth0 | awk -F"[: ]+" '/inet addr:/ {print $4}')


#--------------------------------------------------------------------------------------------------------------------------------
# MAIN INSTALL
#--------------------------------------------------------------------------------------------------------------------------------

installer () {
ins_variable=$(whiptail --ok-button "Choose" --title "WP Bullet VPS Installer for Ubuntu/Debian (c) WP-Bullet.com" --menu "\nIP:   $serverIP\nFQDN: $HOSTNAMEFQDN\n\nChoose what you want to install:" 20 99 9 \
"nginx + fastcgi caching" "nginx with fastcgi caching        "  \
"nginx + Varnish" "nginx with Varnish caching        "  \
"nginx + Varnish + haproxy" "nginx with Varnish caching SSL termination by haproxy"  \
"Monit" "Monitor your programs"  \
"Webmin" "Easy GUI VPS administration"  \
"CSF Firewall" "Comprehensive Firewall"  \
"Suhosin" "Enable PHP Security"  \
"Enable CloudFlare for nginx" "Get real visitor IP for nginx"  \
"Enable CloudFlare for Varnish" "Get real visitor IP for Varnish"  \
"Create SWAP File" "Creates SWAP on your VPS"  3>&1 1>&2 2>&3) exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi


case $ins_variable in
	"nginx + fastcgi caching") 			install_nginx_fastcgi;;
	"nginx + Varnish") 					install_nginx_varnish;;
	"nginx + Varnish + haproxy") 		install_nginx_varnish_haproxy="true";;
	"Monit") 							install_monit;;
	"Webmin") 							install_webmin;;
	"CSF Firewall") 					install_csf;;
	"Suhosin") 							install_suhosin;;
	"Enable CloudFlare for nginx") 		install_cf_nginx;;
	"Enable CloudFlare for Varnish") 	install_cf_varnish;;
	"Create SWAP File") 				install_swap;;
                *)
                ;;
esac
		
}

installer
