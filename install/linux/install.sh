#!/bin/bash
#Create empty directories
IO_USER=$USER
NODE=`which node`
#Create user if first install
#if [ ! -f "/opt/iobroker/conf/iobroker.json" ]; then
#    if [ $(cat /etc/passwd | grep "/home" |cut -d: -f1 | grep '^iobroker$' | wc -l) -eq 0 ]
#    then
#        read -p "Use current user '$USER' for iobroker? If not, the 'iobroker' user will be created.! [Y/n]" yn
#        case $yn in
#            [Nn]* ) echo "Create user iobroker ...";
#                    apt-get install sudo;
#                    useradd iobroker;
#                    adduser iobroker sudo;
#                    IO_USER=iobroker;
#                    break;;
#            [Yy]* ) echo "Use user '$USER' for iobroker.";;
#            * ) echo "Use user $USER for iobroker.";;
#        esac
#    else
#        IO_USER=iobroker
#    fi
#else
    if [ $(cat /etc/passwd | grep "/home" |cut -d: -f1 | grep '^iobroker$' | wc -l) -eq 0 ]
    then
        IO_USER=$USER
    else
        IO_USER=iobroker
    fi
    echo "Use user $IO_USER for install."
#fi

#Modify /etc/couchdb/local.ini. Replace ";bind_address = 127.0.0.1" with "bind_address = 0.0.0.0"
#if grep -Fq ";bind_address = 127.0.0.1" /etc/couchdb/local.ini; then
#    sed -i -e 's/;bind_address = 127\.0\.0\.1/bind_address = 0.0.0.0/g' /etc/couchdb/local.ini
#    /usr/bin/couchdb -d
#    /usr/bin/couchdb -b
#fi

## if iobroker.sh not exists. Copy it
if [ ! -f "/etc/init.d/iobroker.sh" ]; then
    cp @@PATH@@../iobroker/install/linux/iobroker.sh /etc/init.d/iobroker.sh
fi
if [ ! -f "/usr/bin/iobroker" ]; then
    echo 'node @@PATH@@iobroker.js $1 $2 $3 $4 $5' > /usr/bin/iobroker
fi

#Set rights
echo "Set permissions..."
#find @@PATH@@ -type d -exec chmod 777 {} \;
#find @@PATH@@ -type f -exec chmod 777 {} \;
#chown -R $IO_USER:$IO_USER @@PATH@@
chmod 755 /etc/init.d/iobroker.sh
chmod 755 /usr/bin/iobroker

#Replace user pi with current user
sed -i -e "s/IOBROKERUSER=.*/IOBROKERUSER=$IO_USER/" /etc/init.d/iobroker.sh
NODE=${NODE//\//\\/}
sed -i -e s/NODECMD=.*/NODECMD=$NODE/ /etc/init.d/iobroker.sh
chown root:root /etc/init.d/iobroker.sh
update-rc.d iobroker.sh defaults

# Start the service!
echo "Start iobroker..."
cd @@PATH@@
#chmod -R 777 *
./iobroker start
echo "call http://ip_address:8081/ in browser to get the AdminUI of ioBroker"