#!/bin/bash
#
#Taking user inputs
host=1
wordpress_installation_=0
read -p "[1] Do you want to install Wordpress? (Yes/No) : " wordpress_installation
wordpress_installation=$(echo $wordpress_installation | head -c 1)
if [ ! -z $wordpress_installation ] && [ $wordpress_installation  = 'Y' -o  $wordpress_installation = 'y' ] ; then 
wordpress_installation_=1
echo ".:Advanced Setting:. It is Optional"
read -p "Do you want to setup Wordpress Database? (Yes/No) : " wpdb_choice
wpdb_choice=$(echo $wpdb_choice | head -c 1) 
if [ $wpdb_choice = 'Y' -o  $wpdb_choice = 'y' ] ; then
read -p " [1.1] Enter Wordpress 'Database Name', you want to create : " wpdb_name
read -p " [1.2] Enter Wordpress 'Database Username', you want to create : " wpdb_user
read -p " [1.3] Enter Wordpress 'Database Password', you want to create : " wpdb_password
fi 
fi
read -p "[2] Enter Domain Name (leave Blank,if you don't have any) : " domain
if [ -z $domain ] && [ $wordpress_installation_ -eq 1 ] ; then domain='wordpress' ; host=0 ; fi
if [ -z $domain ] && [ $wordpress_installation_ -eq 0 ] ; then domain='mysite' ; host=0 ; fi
if [ -z $wpdb_name ] ; then wpdb_name='wordpress_DATABASE' ; fi
if [ -z $wpdb_user ] ; then wpdb_user='wordpress_USER' ; fi
if [ -z $wpdb_password ] ; then wpdb_password='wordpress_PASSWORD' ; fi
echo "[3] Do you want to install Remote Desktop(XRDP)?"
read -p " > It would take at least 1 hour to install. (Yes/No) : " xrdp_installtion
xrdp_installtion=$(echo $xrdp_installtion | head -c 1)
#
# installing sudo
printf "Y\n" | apt install sudo -y
#
# updating System
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get --yes upgrade 
sudo apt-get --yes dist-upgrade
sleep 5
#
if [ $xrdp_installtion = 'Y' -o  $xrdp_installtion = 'y' ] ; then
# Installing Kubuntu Desktop & its Dependencies
sudo apt-get --yes install xorg
sudo apt-get --yes install xrdp
sudo apt-get --yes install build-essential
sudo apt-get --yes install tasksel
sudo DEBIAN_FRONTEND=noninteractive tasksel install kubuntu-desktop
sudo service xrdp restart
sleep 10
# Setting Up Kubuntu Desktop
sudo apt-get --yes install nemo 
sudo xdg-mime default nemo.desktop inode/directory application/x-gnome-saved-search 
sudo apt-get --yes purge dolphin
sudo apt-get --yes purge kate
sudo apt-get --yes install gedit
sudo xdg-mime default gedit.desktop text/plain
sudo rm -f /*/Desktop/trash.desktop
sudo rm -f /*/*/Desktop/trash.desktop
sudo apt-get --yes purge gwenview
sudo apt-get autoclean
sudo apt-get autoremove
sleep 10
# Installing WINE to run Windows Applications
sudo dpkg --add-architecture i386
sudo wget -nc https://dl.winehq.org/wine-builds/winehq.key
sudo apt-key add winehq.key
sudo apt-add-repository https://dl.winehq.org/wine-builds/ubuntu/
sudo apt-get update
sudo apt-get install --install-recommends winehq-devel -y
sudo apt-get install winetricks -y
sleep 5
fi
#
# Installing LAMP (Apache Server, MySQL, Php) & Firewall
sudo apt-get update
sudo apt-get --yes install apache2
sudo apt-get --yes install ufw # Firewall
printf "y\n" | sudo ufw enable
sudo ufw allow 3389 # allowing remote desktop(xrdp) to Firewall
sudo ufw allow ssh
sudo ufw allow in "Apache Full"
sudo apt-get --yes install mysql-server
sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
sudo mysql -e "FLUSH PRIVILEGES"
sudo DEBIAN_FRONTEND=noninteractive apt-get --yes install php libapache2-mod-php php-mysql
sudo service apache2 restart
sudo chown -R $USER:root /var/www
sleep 10
#
# Preparing PhpMyAdmin installation
sudo apt-get --yes install debconf-utils
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/dbconfig-install boolean true'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/app-password-confirm password phpmyadmin_PASSWORD'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/admin-pass password phpmyadmin_PASSWORD'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/app-pass password phpmyadmin_PASSWORD'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2'
# PhpMyAdmin installation & configuration
sudo DEBIAN_FRONTEND=noninteractive apt-get install -q -y phpmyadmin
sudo mysql -e "UPDATE mysql.user SET authentication_string=PASSWORD('mysql_PASSWORD') where user='root'"
sudo mysql -e "UPDATE mysql.user SET plugin='mysql_native_password' where user='root'"
sudo mysql -e "FLUSH PRIVILEGES"
sudo echo -en "[mysql]\nuser=root\npassword=mysql_PASSWORD\n" > ~/.my.cnf
sudo chmod 0600 ~/.my.cnf
sleep 10
#
# Preparing Website
mkdir /var/www/html/$domain
sudo touch /var/www/html/$domain/.htaccess
sudo echo -en "<Directory /var/www/html/$domain>\n\tAllowOverride All\n</Directory>" > /etc/apache2/sites-available/$domain.conf
sudo echo -en "\n<VirtualHost *:80>\n\tServerAdmin admin@$domain\n\tServerName $domain\n\tDocumentRoot /var/www/html/$domain\n\tErrorLog ${APACHE_LOG_DIR}/error.log\n\tCustomLog ${APACHE_LOG_DIR}/access.log combined\n</VirtualHost>" >> /etc/apache2/sites-available/$domain.conf
sudo a2ensite $domain.conf
sudo systemctl reload apache2
sudo a2dissite 000-default.conf
sudo systemctl reload apache2
sudo a2enmod rewrite
sudo systemctl restart apache2
sleep 10
#
if [ $wordpress_installation_ -eq 1 ] ; then
	# Creating Wordpress Database
	sudo mysql -e "CREATE DATABASE $wpdb_name"
	sudo mysql -e "CREATE USER $wpdb_user@localhost IDENTIFIED BY '$wpdb_password'"
	sudo mysql -e "GRANT ALL PRIVILEGES ON $wpdb_name.* TO $wpdb_user@localhost" 
	sudo mysql -e "FLUSH PRIVILEGES"
	# Downloading Wordpress
	wget http://wordpress.org/latest.tar.gz
	tar xzvf latest.tar.gz
	sudo apt-get update
	sudo apt-get --yes install php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip
	sudo curl -s https://api.wordpress.org/secret-key/1.1/salt/ > ./wordpress/keys.txt
	# Pre Configuring Wordpress
	sudo cp ./wordpress/wp-config-sample.php ./wordpress/wp-config.php
	sudo sed -i 's/database_name_here/'$wpdb_name'/g' ./wordpress/wp-config.php
	sudo sed -i 's/username_here/'$wpdb_user'/g' ./wordpress/wp-config.php
	sudo sed -i 's/password_here/'$wpdb_password'/g' ./wordpress/wp-config.php
	sudo sed -i "s/require_once(ABSPATH . 'wp-settings.php');/define('FS_METHOD', 'direct');\r\nrequire_once(ABSPATH . 'wp-settings.php');/g" ./wordpress/wp-config.php
	# Installing & Configuring Wordpress
	sudo rsync -avP ./wordpress/ /var/www/html/$domain/
	sudo chown -R www-data:www-data /var/www/html/$domain/
	mkdir /var/www/html/$domain/wp-content/uploads
	sudo chown -R www-data:www-data /var/www/html/$domain/wp-content/uploads
	sudo service apache2 restart
	sudo find /var/www/html/$domain -type d -exec chmod 750 {} \;
	sudo find /var/www/html/$domain -type f -exec chmod 640 {} \;	
fi
sleep 10
#
# Cleaning Data
if [ $wordpress_installation_ -eq 1 ] ; then rm -f /var/www/html/index.html; rm -rf wordpress ; fi
rm -f ~/.my.cnf
sleep 5
#
# Renabling SSH
sudo /etc/init.d/ssh restart
sudo sed -i 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config
sudo /etc/init.d/ssh restart
sudo dpkg-reconfigure openssh-server
(cd /etc/NetworkManager/dispatcher.d/;echo sudo /etc/init.d/ssh restart > ./10ssh;chmod 755 ./10ssh)
sudo systemctl enable ssh.service
sleep 10
#
# Adding Domain name in Host file
if [ $host -eq 1 ] ; then sudo echo -e "$(curl ifconfig.me)\t$domain" >> /etc/hosts ; fi 
#
# Installing SSL
if [ $host -eq 1 ]
then
	sudo apt-get update
	sudo apt-get --yes install software-properties-common
	sudo add-apt-repository ppa:certbot/certbot -y
	sudo apt-get update
	sudo apt-get --yes install python-certbot-apache 
	echo -e "admin@$domain\nA\n" | sudo DEBIAN_FRONTEND=noninteractive certbot --apache -d $domain
	sudo sed -i 's/<\/VirtualHost>/RewriteEngine on\nRewriteCond %{SERVER_NAME} ='$domain'\nRewriteRule ^ https:\/\/%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]\n<\/VirtualHost>/g' /etc/apache2/sites-available/$domain.conf
	sudo systemctl restart apache2
fi
sleep 5
#
#sudo reboot
# now open SITE_URL_or_IP/wp-admin/install.php
# SSL test here https://www.ssllabs.com/ssltest/analyze.html?d=SITE_URL_or_IP
