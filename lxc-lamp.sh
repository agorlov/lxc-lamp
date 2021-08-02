#!/bin/bash
# Project development environment initialization
#
# LAMP/LEMP: Ubuntu 20.04 nginx php7.4 MariaDB
#
# Project working direcory mapped to container /www dir
#   /www/index.php - is starting point
#   /www/public - is web root
#
# This script prepares all that needed to development:
#   - install contaier;
#   - installs packages;
#   - services, database
#
# Author: Alexandr Gorlov https://github.com/agorlov
# Coauthor: Kirill Artemov

# Any subsequent(*) commands which fail will cause the shell script to exit immediately
set -e

LXC_NAME=$1
DB_NAME=$1

[ -z "$LXC_NAME" ] && echo "Hey, tell me plz container name. Example: $ sudo ./lxc-lamp.sh myapp" && exit 1


LXC_PATH="/var/lib/lxc/${LXC_NAME}"
LXC_ROOT="/var/lib/lxc/${LXC_NAME}/rootfs"

if [ -z ${SUDO_UID+x} ]; then
  echo "Hm, run this script using sudo plz:"
  echo "$ sudo ./initenv.sh [container-name]"
  exit 255
fi

# SUDO_USER is original user name of developer
# check that $SUDO_USER != 'root'
if [ "$SUDO_USER" = "root" ]; then
    echo "Not root plz. Swithch to user you working as, then run it"
    exit 255
fi

MY_GROUP=`id -gn $SUDO_USER`

if lxc-ls -f | grep "${LXC_NAME}"; then
  read -p "Container '${LXC_NAME}' already exists. Destroy it, and create new one from scratch (y/n)? " CONT
  if [ "$CONT" = "y" ]; then
    lxc-destroy -n "${LXC_NAME}" -f;
  else
    echo "Exiting...";
    exit 1;
  fi

fi

# Container creation: Ubuntu 20.04
echo "Creationg container: ${LXC_NAME}"
lxc-create -t download -n "${LXC_NAME}" -- -d ubuntu -r focal -a amd64 --no-validate

# Lxc config tweaks
{
  echo ""
  echo "# Map Host project directory to /www"
  echo "lxc.mount.entry = ${PWD} www none bind,create=dir,rw 0 0"
} >> "${LXC_PATH}/config"

echo "Starting ${LXC_NAME}...";
lxc-start -n "${LXC_NAME}"

# Recreate default user, his login, uid, gid equal to host user
lxc-attach -n "${LXC_NAME}" -- userdel -r ubuntu
lxc-attach -n "${LXC_NAME}" -- groupadd -g ${SUDO_GID} ${MY_GROUP}
lxc-attach -n "${LXC_NAME}" -- useradd -s /bin/bash --gid ${SUDO_GID} -G sudo --uid ${SUDO_UID} -m ${SUDO_USER}

# wait untill it starts
until [[ `lxc-ls -f | grep "${LXC_NAME}" | grep "RUNNING" | grep "10.0.3"` ]]; do sleep 1; done;
#echo `lxc-ls -f`

# Packages installation
echo "Packages installation...";

## Predefined variables to install postfix
## https://blog.bissquit.com/unix/debian/postfix-i-dovecot-v-kontejnere-docker/
{
  echo "postfix postfix/main_mailer_type string Internet site"
  echo "postfix postfix/mailname string mail.domain.tld"
} >> "${LXC_ROOT}/tmp/postfix_silent_install.txt"

lxc-attach -n "${LXC_NAME}" -- debconf-set-selections /tmp/postfix_silent_install.txt

lxc-attach -n "${LXC_NAME}" -- apt update
lxc-attach -n "${LXC_NAME}" -- sh -c "DEBIAN_FRONTEND=noninteractive apt install -q -y locales-all"
lxc-attach -n "${LXC_NAME}" -- sh -c "DEBIAN_FRONTEND=noninteractive apt install -q -y \
    php7.4-cli php7.4-mysql php7.4-mbstring php7.4-xml php7.4-curl \
    php7.4-fpm php7.4-zip wget nginx mc mariadb-server composer postfix \
    php7.4-soap"  # sphinxsearch

## Install composer packages, if composer.json on place
if [[ -f "/www/composer.json" ]]; then
  lxc-attach -n "${LXC_NAME}" -- su - ${SUDO_USER} -c "cd /www && composer update"
fi

# /etc/hosts
{
  echo "# ${LXC_NAME}"
  echo "127.0.0.1 dbhost"
} >> "${LXC_ROOT}/etc/hosts"


# nginx configuration
{
cat <<EOFNGINX
server {
    listen 8000;
    server_name ${LXC_NAME};
    fastcgi_read_timeout 600;
    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log;
    client_max_body_size 50m;
    set_real_ip_from 10.0.3.1; # set if container is behind proxy (on host machine)
    root /www/public;
    gzip off;
    location / {
        try_files \$uri @php;
        index index.php;
    }

    location /adminer {
        allow 127.0.0.1;
        # Your trusted addresses
        # allow 192.168.0.155;
        allow 10.0.3.1;
        deny all;

        root /adminer;
        fastcgi_pass unix:///run/php/php7.4-fpm.sock;
        fastcgi_index  adminer-4.8.0-mysql.php;
        fastcgi_param  SCRIPT_FILENAME  \$document_root/adminer-4.8.0-mysql.php;
        include        fastcgi_params;
    }

    location @php {
        root /www;
        fastcgi_pass unix:///run/php/php7.4-fpm.sock;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  \$document_root/index.php;
        include        fastcgi_params;
    }
}
EOFNGINX
} > "${LXC_ROOT}/etc/nginx/sites-available/${LXC_NAME}"

lxc-attach -n "${LXC_NAME}" -- ln -s /etc/nginx/sites-available/${LXC_NAME} /etc/nginx/sites-enabled/

# change www-data in container to this user
sed -i "/^user www-data/s/user www-data/user ${SUDO_USER}/"\
    "${LXC_PATH}/rootfs/etc/nginx/nginx.conf"
sed -i "/^user = www-data/s/user = www-data/user = ${SUDO_USER}/"\
    "${LXC_ROOT}/etc/php/7.4/fpm/pool.d/www.conf"
sed -i "/^group = www-data/s/group = www-data/group = ${MY_GROUP}/"\
    "${LXC_ROOT}/etc/php/7.4/fpm/pool.d/www.conf"
sed -i "/^listen.owner = www-data/s/listen.owner = www-data/listen.owner = ${SUDO_USER}/"\
    "${LXC_ROOT}/etc/php/7.4/fpm/pool.d/www.conf"
sed -i "/^listen.group = www-data/s/listen.group = www-data/listen.group = ${MY_GROUP}/"\
    "${LXC_ROOT}/etc/php/7.4/fpm/pool.d/www.conf"

# Php configuration customization
{
  echo "php_admin_value[upload_max_filesize] = 50M"
  echo "php_admin_value[post_max_size] = 50M"
} >> "${LXC_ROOT}/etc/php/7.4/fpm/pool.d/www.conf"


lxc-attach -n "${LXC_NAME}" -- systemctl restart php7.4-fpm
lxc-attach -n "${LXC_NAME}" -- systemctl restart nginx

# Databases initialization
echo "Databases initialization"
lxc-attach -n "${LXC_NAME}" -- mysqladmin create ${DB_NAME}

if [[ -f "./db.sql" ]]; then
    cat db.sql | lxc-attach -n "${LXC_NAME}" -- mysql ${DB_NAME} -uroot
    echo "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_NAME}'@'localhost' IDENTIFIED BY '${DB_NAME}';" |\
    lxc-attach -n "${LXC_NAME}" -- mysql ${DB_NAME} -uroot
fi


# Sphinxsearch

#cat sphinx.conf > "${LXC_ROOT}/etc/sphinxsearch/sphinx.conf"
#echo "START=yes" > "${LXC_ROOT}/etc/default/sphinxsearch"
#lxc-attach -n "${LXC_NAME}" -- indexer --all
#lxc-attach -n "${LXC_NAME}" -- systemctl restart sphinxsearch


# Crontab
#{
#  echo "*/5 * * * *     cd /www && /usr/bin/php ./sync_boxes.php"
#  echo "*/30 * * * *    indexer --all --rotate"
#} | lxc-attach -n "${LXC_NAME}" -- crontab -u${SUDO_USER} -


# Adminer
lxc-attach -n "${LXC_NAME}" -- \
    mkdir -p /adminer
lxc-attach -n "${LXC_NAME}" -- \
    sh -c 'cd /adminer && wget -q https://github.com/vrana/adminer/releases/download/v4.8.0/adminer-4.8.0-mysql.php'

# Help messages
LXC_IP=`lxc-info -n ${LXC_NAME} -iH`

echo
echo "======================= HA, ALL DONE! ==========================="
echo
echo "Open in browser: http://${LXC_IP}:8000"
echo
echo "Your database name: {$DB_NAME} (user: {$DB_NAME}, passw: {$DB_NAME})"
echo "                    Accesible from inside container only. From localhost."
echo
echo "To start adminer run:"
echo
echo "    http://${LXC_IP}:8000/adminer"
echo "    or"
echo "    http://10.0.3.21:8000/adminer.php?server=dbhost&username={$DB_NAME}&db={$DB_NAME}"
echo
echo "For production, or to open app outside yor pc, forward port:"
echo "    $ sudo iptables -t nat -A PREROUTING -i [eth0] -p tcp --dport 8000 -j DNAT --to-destination ${LXC_IP}:8000"
echo "    where"
echo "        -i eth0 - is your exernal network interface"
echo "        --dport 8000 - is external port for your web-app"
echo
echo "More instructions in README: https://github.com/agorlov/lxc-lamp"
echo
echo "Hope to be helpful. Happy coding :o)"
