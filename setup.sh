#!/bin/bash

apt install acl curl composer fping git graphviz imagemagick mariadb-client mariadb-server mtr-tiny nginx-full -y
apt install nmap php7.4-cli php7.4-curl php7.4-fpm php7.4-gd php7.4-gmp php7.4-json php7.4-mbstring php7.4-mysql php7.4-snmp php7.4-xml -y
apt install php7.4-zip python3-dotenv python3-pymysql python3-redis python3-setuptools python3-systemd python3-pip rrdtool snmp snmpd whois -y

useradd librenms -d /opt/librenms -M -r -s "$(which bash)"

cd /opt
git clone https://github.com/librenms/librenms.git

chown -R librenms:librenms /opt/librenms
chmod 771 /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/

sudo -H -u librenms bash -c './scripts/composer_wrapper.php install --no-dev'

wget https://getcomposer.org/composer-stable.phar
mv composer-stable.phar /usr/bin/composer
chmod +x /usr/bin/composer

sed -i 's/;date.timezone =/date.timezone = Etc\/Utc/' /etc/php/7.4/fpm/php.ini
sed -i 's/;date.timezone =/date.timezone = Etc\/Utc/' /etc/php/7.4/cli/php.ini

timedatectl set-timezone Etc/UTC

rm /etc/mysql/mariadb.conf.d/50-server.cnf
cp -a conf.txt /etc/mysql/mariadb.conf.d/50-server.cnf

systemctl enable mariadb
systemctl restart mariadb

mysql -e 'CREATE DATABASE librenms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -e 'CREATE USER librenms@localhost IDENTIFIED BY "password"'
mysql -e 'GRANT ALL PRIVILEGES ON librenms.* TO librenms@localhost'
mysql -e 'FLUSH PRIVILEGES'

cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/librenms.conf

sed -i 's/www/librenms/' /etc/php/7.4/fpm/pool.d/librenms.conf

sed -i 's/user = librenms-data/user = librenms/' /etc/php/7.4/fpm/pool.d/librenms.conf
sed -i 's/group = librenms-data/group = librenms/' /etc/php/7.4/fpm/pool.d/librenms.conf

sed -i 's/listen = \/run\/php\/php7.4-fpm.sock/listen = \/run\/php-fpm-librenms.sock/' /etc/php/7.4/fpm/pool.d/librenms.conf

cp -a serv.txt /etc/nginx/sites-enabled/librenms.vhost

rm /etc/nginx/sites-enabled/default

fuser -k 80/tcp
fuser -k 443/tcp
systemctl restart nginx.service

ln -s /opt/librenms/lnms /usr/bin/lnms
cp /opt/librenms/misc/lnms-completion.bash /etc/bash_completion.d/

cp /opt/librenms/snmpd.conf.example /etc/snmp/snmpd.conf

curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro

chmod +x /usr/bin/distro

systemctl enable snmpd
systemctl restart snmpd

cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms

cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms