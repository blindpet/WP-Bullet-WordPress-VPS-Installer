#!/bin/bash
#make sure you are root
if [ $(id -u) != "0" ]; then
    echo "You must be root to run this script, use root or a sudo user."
    exit 1
fi

show_summary() {
#--------------------------------------------------------------------------------------------------------------------------------
# Show summary
#--------------------------------------------------------------------------------------------------------------------------------
if [ "${ins_nginx_fastcgi}" == "true" ] || [ "${ins_nginx_varnish}" == "true" ] || [ "${ins_nginx_varnish_haproxy}" == "true" ]; then
echo "MySQL root password ${MYSQLROOTPASS}"
echo "WordPress MySQL username ${WORDPRESSSQLUSER}"
echo "WordPress MySQL password ${WORDPRESSSQLPASS}"
echo "WordPress MySQL database ${WORDPRESSSQLDB}"
fi
if [ "${ins_monit}" == "true" ]; then
echo "Monit is running on https://$SERVERIP:2812"
echo "Monit username is ${MONITUSER}"
echo "Monit password is ${MONITPASS}"
fi
if [ "${ins_webmin}" == "true" ]; then
echo "Webmin is running on https://$SERVERIP:10000"
echo "Webmin username is system root or sudo user"
fi
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
#if (("$ASKED" != "true")); then
#generate random passwords http://www.howtogeek.com/howto/30184/10-ways-to-generate-a-random-password-from-the-command-line/
if (${ins_nginx_fastcgi} || ${ins_nginx_varnish} || ${ins_nginx_varnish_haproxy} == "true";) then
MYSQLROOTPASS=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
MYSQLROOTPASS=$(whiptail --inputbox "Choose the MySQL root password" 8 78 $MYSQLROOTPASS --title "WP-Bullet.com" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
WORDPRESSSQLDB=$(whiptail --inputbox "Choose the WordPress MySQL database name" 8 78 "WordPressDB" --title "WP-Bullet.com" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
WORDPRESSSQLUSER=$(whiptail --inputbox "Choose the WordPress MySQL user" 8 78 "WordPressMySQLuser" --title "WP-Bullet.com" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
WORDPRESSSQLPASS=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
WORDPRESSSQLPASS=$(whiptail --inputbox "Choose the WordPress MySQL password" 8 78 $WORDPRESSSQLPASS --title "WP-Bullet.com" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
WORDPRESSSITE=$(whiptail --inputbox "Choose the WordPress sitename" 8 78 "WP-Bullet.com" --title "WP-Bullet.com" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
fi
#fi
#ASKED="true"
}

install_nginx_fastcgi () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install nginx with fastcgi caching
#--------------------------------------------------------------------------------------------------------------------------------
get_user_input
#nginxssl=$(whiptail --ok-button "Choose" --title "fastcgi nginx security choice (c) WP-Bullet.com" --menu "\nChoose basic http or https:" 20 78 9 \
#"fastcgi http" "fastcgi http only        "  \
#"fastcgi https" "fastcgi https only        " 3>&1 1>&2 2>&3) exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
#if [ "$nginxssl" == "fastcgi https" ]; then
#install_nginx_fastcgissl
#fi
install_dotdeb
install_nginx
cp configs/wordpressfastcgi /etc/nginx/sites-available/wordpress
ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress
sed -i s"/example.com/${WORDPRESSSITE}/g" /etc/nginx/sites-enabled/wordpress
install_mariadb
install_wordpress
#Fix CloudFlare IP
cat > /etc/nginx/conf.d/cloudflare.conf<<EOF
#CloudFlare
set_real_ip_from   199.27.128.0/21;
set_real_ip_from   173.245.48.0/20;
set_real_ip_from   103.21.244.0/22;
set_real_ip_from   103.22.200.0/22;
set_real_ip_from   103.31.4.0/22;
set_real_ip_from   141.101.64.0/18;
set_real_ip_from   108.162.192.0/18;
set_real_ip_from   190.93.240.0/20;
set_real_ip_from   188.114.96.0/20;
set_real_ip_from   197.234.240.0/22;
set_real_ip_from   198.41.128.0/17;
set_real_ip_from   162.158.0.0/15;
set_real_ip_from   104.16.0.0/12;
set_real_ip_from   172.64.0.0/13;
set_real_ip_from   2400:cb00::/32;
set_real_ip_from   2606:4700::/32;
set_real_ip_from   2803:f800::/32;
set_real_ip_from   2405:b500::/32;
set_real_ip_from   2405:8100::/32;
#Set the real ip header
real_ip_header     CF-Connecting-IP;
EOF
service nginx restart
service php5-fpm restart

}

install_nginx_fastcgissl () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install nginx with fastcgi caching ssl
#--------------------------------------------------------------------------------------------------------------------------------
#generate ssl
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install openssl -y
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt -subj "/C=/ST=/L=/O=Company Name/OU=Org/CN=${WORDPRESSSITE}"
install_dotdeb
install_nginx
cp configs/wordpressfastcgissl /etc/nginx/sites-available/wordpress
ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress
sed -i s"/example.com/${WORDPRESSSITE}/g" /etc/nginx/sites-enabled/wordpress
install_mariadb
install_wordpress
#Fix CloudFlare IP
cat > /etc/nginx/conf.d/cloudflare.conf<<EOF
#CloudFlare
set_real_ip_from   199.27.128.0/21;
set_real_ip_from   173.245.48.0/20;
set_real_ip_from   103.21.244.0/22;
set_real_ip_from   103.22.200.0/22;
set_real_ip_from   103.31.4.0/22;
set_real_ip_from   141.101.64.0/18;
set_real_ip_from   108.162.192.0/18;
set_real_ip_from   190.93.240.0/20;
set_real_ip_from   188.114.96.0/20;
set_real_ip_from   197.234.240.0/22;
set_real_ip_from   198.41.128.0/17;
set_real_ip_from   162.158.0.0/15;
set_real_ip_from   104.16.0.0/12;
set_real_ip_from   172.64.0.0/13;
set_real_ip_from   2400:cb00::/32;
set_real_ip_from   2606:4700::/32;
set_real_ip_from   2803:f800::/32;
set_real_ip_from   2405:b500::/32;
set_real_ip_from   2405:8100::/32;
#Set the real ip header
real_ip_header     CF-Connecting-IP;
EOF
service nginx restart
service php5-fpm restart

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
#Fix CloudFlare IP
cat > /etc/nginx/conf.d/cloudflare.conf<<EOF
#CloudFlare
set_real_ip_from   199.27.128.0/21;
set_real_ip_from   173.245.48.0/20;
set_real_ip_from   103.21.244.0/22;
set_real_ip_from   103.22.200.0/22;
set_real_ip_from   103.31.4.0/22;
set_real_ip_from   141.101.64.0/18;
set_real_ip_from   108.162.192.0/18;
set_real_ip_from   190.93.240.0/20;
set_real_ip_from   188.114.96.0/20;
set_real_ip_from   197.234.240.0/22;
set_real_ip_from   198.41.128.0/17;
set_real_ip_from   162.158.0.0/15;
set_real_ip_from   104.16.0.0/12;
set_real_ip_from   172.64.0.0/13;
set_real_ip_from   2400:cb00::/32;
set_real_ip_from   2606:4700::/32;
set_real_ip_from   2803:f800::/32;
set_real_ip_from   2405:b500::/32;
set_real_ip_from   2405:8100::/32;
#Set the real ip header
set_real_ip_from   127.0.0.1/32;
real_ip_header     X-Actual-IP;
EOF
service nginx restart
service php5-fpm restart
service varnish restart
}

install_nginx_varnish_haproxy () {
#--------------------------------------------------------------------------------------------------------------------------------
# install nginx with Varnish SSL Terminal from haproxy
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
install_haproxy
install_wordpress
#WordPress SSL fix
echo "if (\$_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')
        \$_SERVER['HTTPS']='on';" >> /var/www/${WORDPRESSSITE}/wp-config.php
#Fix CloudFlare IP
cat > /etc/nginx/conf.d/cloudflare.conf<<EOF
#CloudFlare
set_real_ip_from   199.27.128.0/21;
set_real_ip_from   173.245.48.0/20;
set_real_ip_from   103.21.244.0/22;
set_real_ip_from   103.22.200.0/22;
set_real_ip_from   103.31.4.0/22;
set_real_ip_from   141.101.64.0/18;
set_real_ip_from   108.162.192.0/18;
set_real_ip_from   190.93.240.0/20;
set_real_ip_from   188.114.96.0/20;
set_real_ip_from   197.234.240.0/22;
set_real_ip_from   198.41.128.0/17;
set_real_ip_from   162.158.0.0/15;
set_real_ip_from   104.16.0.0/12;
set_real_ip_from   172.64.0.0/13;
set_real_ip_from   2400:cb00::/32;
set_real_ip_from   2606:4700::/32;
set_real_ip_from   2803:f800::/32;
set_real_ip_from   2405:b500::/32;
set_real_ip_from   2405:8100::/32;
#Set the real ip header
set_real_ip_from   127.0.0.1/32;
real_ip_header     X-Actual-IP;
EOF
service nginx restart
service php5-fpm restart
service varnish restart
service haproxy restart
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
cp configs/nginx.conf /etc/nginx/nginx.conf
unlink /etc/nginx/sites-enabled/default
debconf-apt-progress -- apt-get install curl php5-curl php5-mysql php5-cli php5-fpm php5-gd -y
cp configs/www.conf /etc/php5/fpm/pool.d/www.conf
}

install_wordpress () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install wordpress
#--------------------------------------------------------------------------------------------------------------------------------
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
mv /etc/mysql/my.conf /etc/mysql/my.conf.bak
cp configs/my.conf /etc/mysql/my.conf
service mysql restart
}

install_varnish (){
#--------------------------------------------------------------------------------------------------------------------------------
# Install high-performance HTTP accelerator
#-------------------------------------------------------------------------------------------------------------------------------- 
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install apt-transport-https -y
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
mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
cp configs/haproxy.cfg /etc/haproxy/haproxy.cfg
#openssl req -new -newkey rsa:2048 -nodes -out /etc/ssl/wpbullet.pem -keyout /etc/ssl/wpbullet.pem -subj "/C=US/ST=Oregon/L=Portland/O=Company Name/OU=Org/CN=www.example.com"
openssl req -new -x509 -days 365 -nodes -out /etc/ssl/wp-bullet.pem -keyout /etc/ssl/wp-bullet.pem -subj "/C=/ST=/L=/O=Company Name/OU=Org/CN=${WORDPRESSSITE}"

}

install_webmin () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install webmin
#--------------------------------------------------------------------------------------------------------------------------------
#install csf with webmin module
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install libauthen-pam-perl libio-pty-perl libnet-ssleay-perl libapt-pkg-perl apt-show-versions libwww-perl -y
cd /tmp
wget http://www.webmin.com/download/deb/webmin-current.deb
dpkg -i webmin*
}

install_csf () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install csf
#--------------------------------------------------------------------------------------------------------------------------------
#install csf
debconf-apt-progress -- apt-get remove ufw -y
debconf-apt-progress -- apt-get install iptables unzip -y
cd /tmp
wget -q https://download.configserver.com/csf.tgz
tar -xf csf.tgz -C /opt
cd /opt/csf
bash /opt/csf/install.sh
#copy template over
CSFTEMPLATE=$(find / -iname csf.conf | grep configs)
mv /etc/csf/csf.conf /etc/csf/csf.conf.bak
cp $CSFTEMPLATE /etc/csf/csf.conf
csf -r > /dev/null
#install csf webmin module
cd /usr/share/webmin
perl install-module.pl /etc/csf/csfwebmin.tgz
#install nginx webmin module
cd /tmp
wget -q http://www.justindhoffman.com/sites/justindhoffman.com/files/nginx-0.08.wbm__0.gz
cd /usr/share/webmin
perl install-module.pl /tmp/nginx-0.08.wbm__0.gz
#install opcache webmin module
#cd /tmp
#wget http://github.com/jesucarr/webmin-php-opcache-status/releases/download/v1.0/php-opcache-status.wbm.gz
#cd /usr/share/webmin
#perl install-module.pl /tmp/php-opcache-status.wbm.gz
#install php module
cd /tmp
wget -q http://www.webmin.com/webmin/download/modules/phpini.wbm.gz
cd /usr/share/webmin
perl install-module.pl /tmp/phpini.wbm.gz
echo "CSF Firewall is installed, configure it with this guide"
}

install_suhosin () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install suhosin
#--------------------------------------------------------------------------------------------------------------------------------
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install php5-dev git build-essential -y
cd /tmp
SUHOSINLATEST=$(wget -q -O - https://github.com/stefanesser/suhosin/releases/ | grep tar.gz | awk -F [\"] 'NR==1 {print $2}')
wget -q https://github.com$SUHOSINLATEST -O suhosin.tar.gz
tar -xf suhosin.tar.gz
cd suhosin*
phpize > /dev/null
./configure > /dev/null
make > /dev/null
make install > /dev/null
PHPINI=($(find / -iname php.ini))
for ini in "${PHPINI[@]}"
do
  echo "extension=suhosin.so" >> "${ini}"
done
service php5-fpm restart
}

install_redis () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install redis
#--------------------------------------------------------------------------------------------------------------------------------
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install php5-dev build-essential -y
cd /tmp
#build redis
wget http://download.redis.io/redis-stable.tar.gz
tar xzf redis*
cd redis*
echo "Building Redis"
make > /dev/null
make install PREFIX=/usr > /dev/null
mkdir /etc/redis
cp redis.conf /etc/redis/
cd ..
rm -Rf redis*
#add redis user
adduser --system --group --disabled-login redis --home /usr/bin/redis-server --shell /bin/nologin --quiet
mv /etc/redis/redis.conf /etc/redis/redis.conf.bak
#create redis configuration
cat > /etc/redis/redis.conf<<EOF
bind 127.0.0.1
daemonize yes
stop-writes-on-bgsave-error no
rdbcompression yes
maxmemory 50M
maxmemory-policy allkeys-lru
EOF
cat > /etc/systemd/system/redis-server.service<<EOF
[Unit]
Description=Redis Datastore Server
After=network.target

[Service]
Type=forking
Restart=always
User=redis
ExecStart=/sbin/start-stop-daemon --start --pidfile /var/run/redis/redis.pid --umask 007 --exec /usr/bin/redis-server -- /etc/redis/redis.conf

ExecReload=/bin/kill -USR2 $MAINPID

[Install]
WantedBy=multi-user.target
EOF
systemctl enable redis-server
service redis-server start
#build the php extension
cd /tmp
debconf-apt-progress -- git -y
git clone https://github.com/phpredis/phpredis
cd phpredis
echo "Building Redis pecl extension"
phpize > /dev/null
./configure > /dev/null
make > /dev/null
make install
PHPINI=($(find / -iname php.ini))
for ini in "${PHPINI[@]}"
do
  echo "extension=redis.so" >> "${ini}"
done
service php5-fpm restart
}

install_memcached () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install memcached
#--------------------------------------------------------------------------------------------------------------------------------
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install libmemcached* memcached libanyevent-perl libyaml-perl libterm-readkey-perl libevent-dev php5-dev pkg-config build-essential -y
MEMCACHELATEST=$(wget -q http://www.memcached.org -O - | grep tar.gz | awk -F "[\"]" '{print $2}')
cd /tmp
wget -q $MEMCACHELATEST -O memcached.tar.gz
tar -xf memcached.tar.gz
cd memcached*
./configure --prefix=/usr
make
make install
#adduser --system --group --disabled-login memcache --home /usr/bin/memcached --shell /bin/nologin --quiet
cat > /etc/memcached.conf<<EOF
# Run memcached as a daemon. This command is implied, and is not needed for the
# daemon to run. See the README.Debian that comes with this package for more
# information.
-d
# Log memcached's output to /var/log/memcached
logfile /var/log/memcached.log
# Be verbose
# -v
# Be even more verbose (print client commands as well)
# -vv
# Start with a cap of 64 megs of memory. It's reasonable, and the daemon default
# Note that the daemon will grow to this size, but does not start out holding this much
# memory
-m 64
# Default connection port is 11211
-p 11211
# Run the daemon as root. The start-memcached will default to running as root if no
# -u command is present in this config file
-u memcache
# Specify which IP address to listen on. The default is to listen on all IP addresses
# This parameter is one of the only security measures that memcached has, so make sure
# it's listening on a firewalled interface.
-l 127.0.0.1
# Limit the number of simultaneous incoming connections. The daemon default is 1024
# -c 1024
# Lock down all paged memory. Consult with the README and homepage before you do this
# -k
EOF
cp scripts/memcached-init /etc/init.d/memcached
cat > /etc/default/memcached<<EOF
# Set this to no to disable memcached.
ENABLE_MEMCACHED=yes
EOF
chmod +x /etc/init.d/memcached
update-rc.d memcached defaults
service memcached start
#build memcached pecl extension
#build libmemcached first
#debconf-apt-progress -- apt-get install libsasl2-dev git php5-dev pkg-config build-essential -y
#cd /tmp
#wget -q https://launchpad.net/libmemcached/1.0/1.0.18/+download/libmemcached-1.0.18.tar.gz
#tar -xf libmemcached-1.0.18.tar.gz
#cd libmemcached*
#./configure
#make
#make install
#build the actual pecl extension
cd /tmp
git clone https://github.com/php-memcached-dev/php-memcached
cd php-memcached
phpize
./configure --prefix=/usr --disable-memcached-sasl
make
make install
PHPINI=($(find / -iname php.ini))
for ini in "${PHPINI[@]}"
do
  echo "extension=memcached.so" >> "${ini}"
done
service php5-fpm restart
}

install_monit () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install monit
#--------------------------------------------------------------------------------------------------------------------------------
#monit credentials
MONITUSER=$(whiptail --inputbox "Choose the Monit username for the WebUI" 8 78 "WP-Bullet" --title "WP-Bullet.com" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
MONITPASS=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
MONITPASS=$(whiptail --inputbox "Choose the Monit password for the WebUI" 8 78 $MONITPASS --title "WP-Bullet.com" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
MONITCONFIGSFOLDER=$(find / -iname monit | grep configs)
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install monit openssl -y
openssl req -new -x509 -days 365 -nodes -out /etc/ssl/monit.pem -keyout /etc/ssl/monit.pem -subj "/C=/ST=/L=/O=Company Name/OU=Org/CN=Monit"
chmod 0700 /etc/ssl/monit.pem
mv /etc/monit/monitrc /etc/monit/monitrc.bak
cat > /etc/monit/monitrc<<EOF
set daemon 60 #check services every 60 seconds
  set logfile /var/log/monit.log
  set idfile /var/lib/monit/id
  set statefile /var/lib/monit/state

#Event queue
  set eventqueue
      basedir /var/lib/monit/events # set the base directory where events will be stored
      slots 100                     # optionally limit the queue size

#Mail settings
# set mail-format {
#     from: monit@\$HOST
#  subject: monit alert --  \$EVENT $SERVICE
#  message: \$EVENT Service \$SERVICE
#                Date:        \$DATE
#                Action:      \$ACTION
#                Host:        \$HOST
#                Description: \$DESCRIPTION
#
#           Your faithful employee,
#           Monit } 
#  set mailserver smtp.gmail.com port 587 
#     username "wp" password "bullet"
#  using TLSV1 with timeout 30 seconds
#  set alert wpbullet@gmail.com #email address which will receive monit alerts

#http settings
 set httpd port 2812 address 0.0.0.0  # allow port 2812 connections on all network adapters
    ssl enable
    pemfile  /etc/ssl/monit.pem
    allow 0.0.0.0/0.0.0.0 # allow all IPs, can use local subnet too
#    allow htpcguides.crabdance.com        # allow dynamicdns address to connect
    allow ${MONITUSER}:"${MONITPASS}"      # require user wp with password bullet

#allow modular structure
    include /etc/monit/conf.d/*
EOF
chmod 0700 /etc/monit/monitrc
#create array to iterate over
MONITCHECK=(nginx php5-fpm mysqld varnishd haproxy redis-server memcached lfd sshd)
#loop through array and copy monit configuration if binary exists
for monit in "${MONITCHECK[@]}"
do
  if hash "${monit}"  2>/dev/null; then
        cp $MONITCONFIGSFOLDER/${monit} /etc/monit/conf.d/${monit}
  fi
done
#hashing webmin doesn't work so check for the pid file instead
if (find /var/run -iname miniserv.pid > /dev/null); then
cp $MONITCONFIGSFOLDER/webmin /etc/monit/conf.d/webmin
fi
#make sure nginx is listening on the right port
if !(lsof | grep LISTEN | grep 8080 >/dev/null); then
sed -i 's/8080/80/' /etc/monit/conf.d/nginx
fi
service monit restart
}

install_wp () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install wp
#--------------------------------------------------------------------------------------------------------------------------------
#run commands inside WORDPRESSITE directory e.g. wp plugin install wordpress-seo --activate --allow-root
wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/bin/wp
chmod 755 /usr/bin/wp
PHPCLI=$(find / -iname php.ini | grep cli)
#grep suhosin.executor.include.whitelist
echo 'suhosin.executor.include.whitelist="phar"' >> $PHPCLI
}

install_swap () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install swap
#--------------------------------------------------------------------------------------------------------------------------------
swapoff -a
dd if=/dev/zero of=/swapfile bs=1M count=1024
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
echo "vm.swappiness = 10" >> /etc/sysctl.conf
echo "vm.vfs_cache_pressure = 50" >> /etc/sysctl.conf
sysctl -p
}

#--------------------------------------------------------------------------------------------------------------------------------
# WELCOME SCREEN
#--------------------------------------------------------------------------------------------------------------------------------

whiptail --title "Welcome to the WP Bullet WordPress VPS Installer" --msgbox "This Ubuntu and Debian Installer will prompt for credentials and autoconfigure everything" 8 78
#get ip
#SERVERIP=$(ifconfig eth0 | awk -F"[: ]+" '/inet addr:/ {print $4}')
#dig +short myip.opendns.com @resolver1.opendns.com
SERVERIP=$(wget http://ipinfo.io/ip -qO -)
#--------------------------------------------------------------------------------------------------------------------------------
# MAIN INSTALL
#--------------------------------------------------------------------------------------------------------------------------------

whiptail --ok-button "Install" --title "WP Bullet VPS Installer for Ubuntu/Debian (c) WP-Bullet.com" --checklist --separate-output "\nIP:   ${SERVERIP}\n\nChoose what you want to install:" 25 78 12 \
"nginx + fastcgi caching" "nginx with fastcgi caching        " off \
"nginx + fastcgi caching ssl" "nginx ssl with fastcgi caching        " off \
"nginx + Varnish" "nginx with Varnish caching        " off \
"nginx + Varnish + haproxy" "nginx + Varnish caching + haproxy SSL" off \
"Webmin" "Easy GUI VPS administration" off \
"CSF Firewall" "Comprehensive Firewall" off \
"Suhosin" "Enable PHP Security" off \
"Redis" "Install Redis Server" off \
"Memcached" "Install Memcached" off \
"Monit" "Monitor your programs" off \
"wp-cli" "WordPress command line" off \
"Create SWAP File" "Creates SWAP on your VPS" off 2>results
while read choice
do
case $choice in
	"nginx + fastcgi caching") 		ins_nginx_fastcgi="true";;
	"nginx + fastcgi caching ssl") 		ins_nginx_fastcgissl="true";;
	"nginx + Varnish") 			ins_nginx_varnish="true";;
	"nginx + Varnish + haproxy") 		ins_nginx_varnish_haproxy="true";;
	"Webmin") 				ins_webmin="true";;
	"CSF Firewall") 			ins_csf="true";;
	"Suhosin") 				ins_suhosin="true";;
	"Redis") 				ins_redis="true";;
	"Memcached") 				ins_memcached="true";;
	"Monit") 				ins_monit="true";;
	"wp-cli") 				ins_wp="true";;
	"Create SWAP File") 			ins_swap="true";;
                *)
                ;;
	esac
done < results
if [[ "$ins_nginx_fastcgi" == "true" ]]; 		then install_nginx_fastcgi;		fi
if [[ "$ins_nginx_fastcgissl" == "true" ]]; 		then install_nginx_fastcgissl;		fi
if [[ "$ins_nginx_varnish" == "true" ]]; 		then install_nginx_varnish;		fi
if [[ "$ins_nginx_varnish_haproxy" == "true" ]]; 	then install_nginx_varnish_haproxy;	fi
if [[ "$ins_webmin" == "true" ]]; 			then install_webmin;			fi
if [[ "$ins_csf" == "true" ]]; 				then install_csf;			fi
if [[ "$ins_suhosin" == "true" ]]; 			then install_suhosin;			fi
if [[ "$ins_redis" == "true" ]]; 			then install_redis;			fi
if [[ "$ins_memcached" == "true" ]]; 			then install_memcached;			fi
if [[ "$ins_monit" == "true" ]]; 			then install_monit;			fi
if [[ "$ins_wp" == "true" ]]; 				then install_wp;			fi
if [[ "$ins_swap" == "true" ]]; 			then install_swap;			fi

show_summary
clear_bash_history
