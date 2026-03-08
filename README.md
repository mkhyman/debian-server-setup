# debian-server-setup
basic scripts for setting up a debian server

This is a work in progress and currently untested, not recommended for use.

### Usage:

Retrieve files with wget (could use git clone if you have that installed but this assumes you dont have git installed yet):

wget --no-check-certificate https://raw.githubusercontent.com/user/repo/refs/heads/main/setup_server.sh  
wget --no-check-certificate https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/menu.csv  
  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/create_sftp_user.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/create_user.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/secure_user.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/set_site_ssl_cetificate.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/setup_apache.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/setup_apache_site.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/setup_composer.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/setup_git.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/setup_mysql.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/setup_npm.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/setup_php.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/setup_sftp.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/setup_ufw.sh  
wget --no-check-certificate -P scripts https://raw.githubusercontent.com/user/repo/refs/heads/main/scripts/update_linux.sh  


make setup_server.sh executable then run.
