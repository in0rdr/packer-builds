#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

# Installation on Debian like OS:
# * https://docs.nextcloud.com/server/latest/admin_manual/installation/example_ubuntu.html
# * https://docs.nextcloud.com/server/latest/admin_manual/installation/source_installation.html

# install Apache and tools
apt-get install -y apache2 libapache2-mod-php
apt-get install -y php-gd php-mysql php-curl php-mbstring php-intl
apt-get install -y php-gmp php-bcmath php-imagick php-xml php-zip php-apcu
apt-get install -y curl bzip2 sudo certbot python-certbot-apache

# download and install Nextcloud
curl -O https://download.nextcloud.com/server/releases/latest.tar.bz2
tar -C /var/www/ -xf latest.tar.bz2
chown -R www-data:www-data /var/www/nextcloud/

# configure Apache
cat << EOF > /etc/apache2/sites-available/nextcloud.conf
Alias $NEXTCLOUD_REWRITE_BASE "/var/www/nextcloud/"

<Directory /var/www/nextcloud/>
  Require all granted
  AllowOverride All
  Options FollowSymLinks MultiViews

  <IfModule mod_dav.c>
    Dav off
  </IfModule>

</Directory>
EOF

# tune php mem limit
sed -i 's/memory_limit = 128M/memory_limit = 512M/g' /etc/php/7.3/apache2/php.ini

# enable opcache
# https://docs.nextcloud.com/server/16/admin_manual/installation/server_tuning.html
sed -i 's/;opcache.enable=1/opcache.enable=1/g' /etc/php/7.3/apache2/php.ini

# enable apcu cli
# https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/caching_configuration.html
cat << EOF > /etc/php/7.3/mods-available/nextcloud-cli.ini                                                                                             
apc.enable_cli=1                                                                                                                                                       
EOF                                                                                                                                                                    
ln -s /etc/php/7.3/mods-available/nextcloud-cli.ini /etc/php/7.3/cli/conf.d/99-nexcloud.ini

# enable config
a2ensite nextcloud.conf

# enable Apache modules
a2enmod rewrite
a2enmod headers
a2enmod env
a2enmod dir
a2enmod mime
a2enmod ssl

OCC=/var/www/nextcloud/occ
APACHE_USER=www-data
APACHE_GROUP=www-data

# status
which php
sudo -u www-data php $OCC status

# install nextcloud
sudo -u "$APACHE_USER" -g "$APACHE_GROUP" php "$OCC" maintenance:install \
 --database "$NEXTCLOUD_DATABASE" --database-name "$NEXTCLOUD_DATABASE_NAME" --database-host "$NEXTCLOUD_DATABASE_HOST" --database-port "$NEXTCLOUD_DATABASE_PORT" \
 --database-user "$NEXTCLOUD_DATABASE_USER" --database-pass "$NEXTCLOUD_DATABASE_PASS" \
 --admin-user "$NEXTCLOUD_ADMIN_USER" --admin-pass "$NEXTCLOUD_ADMIN_PASSWORD" \
 --data-dir "$NEXTCLOUD_DATADIR" || exit 0

sudo -u www-data php $OCC status

# set trusted domains
urls=($NEXTCLOUD_URLS)
for u in "${urls[@]}"; do
  sudo -u "$APACHE_USER" -g "$APACHE_GROUP" php "$OCC" config:system:set trusted_domains 1 --value="$u"
done;

# configure certbot
#certbot --apache --non-interactive --agree-tos --email "$CERTBOT_MAIL" --domain "${urls[0]}"

# configure strict transport security
# https://docs.nextcloud.com/server/19/admin_manual/installation/harden_server.html
#sed -i '/^<\/VirtualHost\>/i <IfModule mod_headers.c>\nHeader always set Strict-Transport-Security "max-age=15552000; includeSubDomains"\n<\/IfModule>' \
# /etc/apache2/sites-available/000-default-le-ssl.conf
#a2ensite 000-default-le-ssl

# add additional users
users=($NEXTCLOUD_ADDITIONAL_USERS)
passwords=($NEXTCLOUD_ADDITIONAL_PASSWORDS)
no_users="${#users[@]}"
for ((i = 0 ; i < $no_users ; i++)); do
  sudo -u "$APACHE_USER" -g "$APACHE_GROUP" OC_PASS="${passwords[$i]}" php "$OCC" user:add ${users[$i]} --password-from-env
done;

# install totp 2fa
sudo -u "$APACHE_USER" -g "$APACHE_GROUP" php "$OCC" app:install twofactor_totp

# remove features
sudo -u "$APACHE_USER" -g "$APACHE_GROUP" php "$OCC" config:app:set text workspace_available --value=0
sudo -u "$APACHE_USER" -g "$APACHE_GROUP" php "$OCC" app:disable recommendations

# configure rewrite base and cli url
sudo -u "$APACHE_USER" -g "$APACHE_GROUP" php "$OCC" config:system:set htaccess.RewriteBase --value="$NEXTCLOUD_REWRITE_BASE"
sudo -u "$APACHE_USER" -g "$APACHE_GROUP" php "$OCC" config:system:set overwrite.cli.url --value="$NEXTCLOUD_CLI_URL"
sudo -u "$APACHE_USER" -g "$APACHE_GROUP" php "$OCC" maintenance:update:htaccess

# enable cron jobs
cat << EOF > /etc/systemd/system/nextcloudcron.service
[Unit]
Description=Nextcloud cron.php job

[Service]
User=www-data
ExecStart=/usr/bin/php -f /var/www/nextcloud/cron.php
EOF

cat << EOF > /etc/systemd/system/nextcloudcron.timer
[Unit]
Description=Run Nextcloud cron.php every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=nextcloudcron.service

[Install]
WantedBy=timers.target
EOF

systemctl start nextcloudcron.timer

# enable APCU data cache in Nextcloud
sudo -u "$APACHE_USER" -g "$APACHE_GROUP" php "$OCC" config:system:set memcache.local --value="\OC\Memcache\APCu"
