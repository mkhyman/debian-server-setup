# debian-server-setup
basic scripts for setting up a debian server

This is a work in progress and currently untested, not recommended for use.

## Installation:

### Either retrieve individual files with wget:

wget --no-check-certificate https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/setup_server.sh  
wget --no-check-certificate https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/menu.csv  
  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/create_sftp_user.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/create_user.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/secure_user.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/set_site_ssl_cetificate.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/setup_apache.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/setup_apache_site.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/setup_composer.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/setup_git.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/setup_mysql.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/setup_npm.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/setup_php.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/setup_sftp.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/setup_ufw.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/scripts/update_linux.sh  

chmod +x setup_server.sh

### Or install unzip and retrieve zipped version

sudo apt update
sudo apt install unzip

wget --no-check-certificate https://raw.githubusercontent.com/mkhyman/debian-server-setup/refs/heads/main/files.zip  
rm files.zip

chmod +x setup_server.sh

## Usage

run setup_server.sh

## Known issues need to convert line endings to unix
