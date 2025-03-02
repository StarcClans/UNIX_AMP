#!/usr/bin/bash

# Constants
readonly USERNAME="username"
readonly NEW_USERNAME="newuser"
readonly OPT_DIR="/opt/"
readonly HOME_DIR="/home/$USERNAME/"
readonly DEFAULT_DIR="/usr/"


# Package variables
package1="ncurses-6.4"
package2="apr-1.7.4"
package3="apr-util-1.6.3"
package4="pcre2-10.43"
package5="php-8.3.6"
package6="openssl-3.3.0"
package7="m4-1.4.1"
package8="bison-1.25"
package9="zlib-1.3.1"
package10="libevent-2.1.12-stable"
package11="expat-2.6.2"
package12="httpd-2.4.59"
package13="mariadb-11.3.2"


# Functions
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root" >&2
        exit 1
    fi
}

install_dependencies() {
    sudo apt-get update
    sudo apt-get install -y build-essential cmake bzip2 ccache sqlite3 libtool autoconf re2c pkg-config git curl libaio-dev libpthread-stubs0-dev libncurses5-dev libxml2-dev libsqlite3-dev
}

create_user() {
    # Add user with password prompt
    adduser --gecos "" "$NEW_USERNAME"

    # Set ownership and permissions for directories
    chown "$NEW_USERNAME:$NEW_USERNAME" "$OPT_DIR" "$HOME_DIR" "$DEFAULT_DIR"
    chmod u+rwx,g+rx,o+rx "$OPT_DIR" "$HOME_DIR" "$DEFAULT_DIR"

    echo "User $NEW_USERNAME has been created with read and write access to /opt/, $HOME_DIR, and $DEFAULT_DIR"

    read -p "Switch to the newly created user ($NEW_USERNAME)? (y/n): " switch_user
    if [ "$switch_user" = "y" ]; then
        su -c "$(declare -f extract_packages); extract_packages" "$NEW_USERNAME"
    else
        echo "You chose not to switch user. Exiting script."
        exit 0
    fi
}

extract_packages() {
    for file in *.tar.gz; do
        tar -xzf "$file"
    done
}

cleanup() {
    rm *.tar.gz
}

# Main
check_root
install_dependencies


# Download packages
wget https://ftp.gnu.org/gnu/ncurses/$package1.tar.gz
wget https://dlcdn.apache.org//apr/$package2.tar.gz
wget https://dlcdn.apache.org//apr/$package3.tar.gz
wget https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.43/$package4.tar.gz
wget https://www.php.net/distributions/$package5.tar.gz
wget https://www.openssl.org/source/$package6.tar.gz
wget https://ftp.gnu.org/gnu/m4/$package7.tar.gz
wget http://ftp.man.poznan.pl/gnu/bison/$package8.tar.gz
wget http://www.zlib.net/$package9.tar.gz
wget https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/$package10.tar.gz
wget https://github.com/libexpat/libexpat/releases/download/R_2_6_2/$package11.tar.gz
wget https://dlcdn.apache.org/httpd/$package12.tar.gz
wget https://mariadb.mirror.serveriai.lt/mariadb-11.3.2/source/$package13.tar.gz

create_user
cleanup

# Set ownership and permissions for user's home directory
sudo chown -R $USERNAME $HOME_DIR
sudo chmod -R u+rwx $HOME_DIR

# Move packages to appropriate locations and install them
cd /home/$USERNAME/ && mv $package2 $package12/srclib/apr
cd /home/$USERNAME/ && mv $package3 $package12/srclib/apr-util
cd /home/$USERNAME/$package1 && ./configure && make && make install && rm -fr ../$package1
cd /home/$USERNAME/$package4 && ./configure --prefix=/opt/dependencies/pcre && make && make install && rm -fr ../$package4
cd /home/$USERNAME/$package6 && ./Configure && make && make install && rm -fr ../$package6
cd /home/$USERNAME/$package10 && ./configure && make && make install && rm -fr ../$package10
cd /home/$USERNAME/$package7 && ./configure && make && make install && rm -fr ../$package7
cd /home/$USERNAME/$package11 && ./configure --prefix=/opt/dependencies/$package11 && make && make install && rm -fr ../$package11
cd /home/$USERNAME/$package9 && ./configure && make && make install && rm -fr ../$package9
cd /home/$USERNAME/$package8 && ./configure && make && make install && rm -fr ../$package8

# Install main packages
cd /home/$USERNAME/$package13 && cmake . --install-prefix=/opt/mariadb && make -j4 && make install && rm -fr ../$package13
cd /home/$USERNAME/$package5 && ./configure --prefix=/opt/php && make && make install && rm -fr ../$package5
cd /home/$USERNAME/$package12 && ./configure --prefix=/opt/apache --with-expat=/opt/dependencies/$package11 --with-pcre=/opt/dependencies/pcre/bin/pcre2-config && make && make install && rm -fr ../$package12

# Test installations
cd /opt/apache && ./bin/httpd
cd /opt/mariadb/scripts && ./mariadb-install-db --basedir=/opt/mariadb
cd /opt/mariadb && mkdir data && ./bin/mariadbd-safe --datadir=data
cd /opt/mariadb/mariadb-test && perl mariadb-test-run.pl

echo "END"
