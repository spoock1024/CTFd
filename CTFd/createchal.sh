#!/bin/bash

mysql_user="root"
mysql_pwd="fulabc303"
unzip() {
	echo "unziping "$chalfilepath
	if [ ! -f $chalfilepath ]
	then
		echo "File \"$chalfilepath\" dose not exist"
		exit 0
	fi

    echo "store  the file to the  folder"
    if [ ! -d /home/ctfquestions ]
    then    
        sudo mkdir /home/ctfquestions
    fi
    if [ ! -d /home/ctfquestions/$chaltype ]
    then    
        sudo mkdir /home/ctfquestions/$chaltype
    fi

    sudo mv $chalfilepath /home/ctfquestions/$chaltype/$filepath.zip
    sudo mkdir /var/www/questions/$filepath/

    sudo unzip -od /var/www/questions/$filepath /home/ctfquestions/$chaltype/$filepath.zip
    sudo mv /var/www/questions/$filepath/*/src/* /var/www/questions/$filepath
    sudo mkdir /var/www/questions/$filepath/db
    sudo mkdir /var/www/questions/$filepath/config
    sudo mv /var/www/questions/$filepath/*/sql/* /var/www/questions/$filepath/db
    sudo mv /var/www/questions/$filepath/*/config/* /var/www/questions/$filepath/config
    sudo rm -rf /var/www/questions/$filepath/*/src
}

setprivilege() {
	sudo chmod -R +x /var/www/questions/$filepath
}

exesql() {
	sqlpath=/var/www/questions/$filepath/db/
	if [ ! -d $sqlpath ]
	then
		echo "Directory \"$sqlpath\" dose not exist"
		exit 0
	fi
	#get the sql filename
	# sqlfile=`find $sqlpath|grep *\.sql`
    sqlfile=`find $sqlpath |grep .sql`
	if [ ! -f $sqlfile ]
	then
		echo "The \"$sqlpath\" Directory dose not have sql file"
		exit 0
	fi

	#connect the sql
    database='db'$RANDOM
    user='user'$RANDOM
    dbpwd='pwd'$RANDOM
    create_db=$(printf 'DROP database if exists %s;create database %s;grant all privileges on %s.* to %s@localhost identified by "%s";use %s;source %s;' $database $database $database $user $dbpwd $database $sqlfile)
    # create_db='show database;'
    echo $create_db | mysql -u$mysql_user -p$mysql_pwd 
	echo "execuet the sql success"
	# delete the sqllfile
	# sudo rm -rf $sqlpath
	echo "delete the sql file success"

    #modify the config.php
    modifyphpconf
}


modifyphpconf() {
    phpconfigpath=/var/www/questions/$filepath/config
    if [ ! -d $phpconfig ]
    then
        echo "Directory \"$phpconfig\" dose not exist"
        exit 0
    fi
    configfile=`find $phpconfigpath|grep config.php`
    echo $configfile  
    if [ ! -f $configfile ]
    then
        echo "The \"$configfile\" Directory dose not have config.php"
        exit 0
    fi
    userpattern=$(printf 's/"USER",".*"/"USER","%s"/g' $user)
    sudo sed -i $userpattern $configfile
    pwdpattern=$(printf 's/"PASS",".*"/"PASS","%s"/g' $dbpwd)
    sudo sed -i $pwdpattern $configfile
    dbpattern=$(printf 's/"DB",".*"/"DB","%s"/g' $database)
    sudo sed -i $dbpattern $configfile
}

setapachesetting() {
	fileDir=/var/www/questions/$filepath
	printf '
<VirtualHost *:%s>
DocumentRoot %s
DirectoryIndex index.php index.html
<Directory %s>
	Options Indexes FollowSymLinks MultiViews
	AllowOverride None
	Order allow,deny
	Allow from all
	#set can not access the config.php
	<Files ~ "config\.php">
        Order allow,deny
        Deny from all
	</Files>
</Directory>
ErrorLog ${APACHE_LOG_DIR}/error.log
CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>' $port $fileDir $fileDir| sudo tee /etc/apache2/sites-available/site$filepath.conf
	echo "create available_conf success"
	available_conf=/etc/apache2/sites-available/site$filepath.conf
	enable_conf=/etc/apache2/sites-enabled/site$filepath.conf
	sudo ln -s $available_conf $enable_conf
	echo "create the enable_conf success"

	#modify the port.conf to add the listen port
	echo "listen $port" | sudo tee -a /etc/apache2/ports.conf

	#reboot the apache2
	sudo /etc/init.d/apache2 restart


}

deletedb() {
    #read the config.php
    #get the user
    userline=$(grep \"USER\"   /var/www/questions/$chalfile/config/config.php)
    userstart=${userline#*,\"}
    dbuser=${userstart%\"*}

    #get the db
    dbline=$(grep \"DB\"   /var/www/questions/$chalfile/config/config.php)
    dbstart=${dbline#*,\"}
    db=${dbstart%\"*}

    delsql="drop USER '$dbuser'@'localhost';drop database $db;"
    #execute the delete sql
    echo $delsql | mysql -u$mysql_user -p$mysql_pwd
}

removeapacheconfig() {
    delvalfile=/etc/apache2/sites-available/site$chalfile.conf
    sudo rm -f $delvalfile
    delenablefile=/etc/apache2/sites-enabled/site$chalfile.conf
    sudo rm -f $delenablefile

    #modify the port.conf
    pattern=$(printf '/%s/d' $port)
    echo $pattern
    sudo sed -i $pattern /etc/apache2/ports.conf
    sudo /etc/init.d/apache2 restart

}   

removefile() {
    quesfile=/var/www/questions/$chalfile
    sudo rm -rf quesfile
}

isnumeric() {
    echo "$@" | grep -q -v "[^0-9]"
}

hiddenchal() {
    #remove the listen port
    pattern=$(printf '/%s/d' $port)
    sudo sed -i $pattern  /etc/apache2/ports.conf
    sudo /etc/init.d/apache2 restart
}

unhiddenchal() {
    #add the listening port
    
    echo "listen $port" | sudo tee -a /etc/apache2/ports.conf
    sudo /etc/init.d/apache2 restart
}

helpinfo() {
    echo "create chal Usage:$createchal.sh -c --chalfilepath <chalfilepath> --port <port> --chaltype <chaltype>"
    echo "delete chal Usage:$createchal.sh -d --port <port> --chalfile <chalfile>"
    echo "hidden chal Usage:$createchal.sh -h --port <port>"
    echo "unhidden chal Usage:$createchal.sh -u --port <port>"
    echo "example $createchal.sh -c --chalfilepath sqli.zip --port 8080 --chaltype web"
    echo "example delete chal:$createchal.sh -d --port 8080 --chalfile 34567" 
    echo "example hidden chal:$createchal.sh -h --port 8080"
    echo "example unhidden chal:$createchal.sh -u --port 8080"   
}
#the entry code
case "$1" in
    -c | --create)
    while [ $# -gt 1 ] ; do
        case "$2" in
            --chalfilepath)
            shift
            if [ -z "$2" ] ; then
                printf "\033[31mError: Please provide a filepath string.\033[m\n\n"
                exit 1
            fi
            chalfilepath=$2
            shift
            ;;

            --port)
            shift
            if !(isnumeric "$2")
            then
                printf "\033[31mError: Please provide a valid port.\033[m\n\n"
                exit 1
            fi
            port=$2
            shift
            ;;

            --chaltype)
            shift
            if [ -z $2 ] ; then
                printf "\033[31mError: Please provide a chaltype string.\033[m\n\n"
                exit 1
            fi
            chaltype=$2
            shift
            ;;

            *)
            printf "\033[31mError: Unkown option '$2'.\033[m\n\n"
            exit 1
            ;;
        esac
    done

    if [ -z "$chalfilepath" ] || [ -z "$port" ] || [ -z "$chaltype" ] ; then
        printf "\033[31mError: More Args needed.\033[m\n\n"
        exit 1
    fi

    if [ $port -ge 65535 ]
    then
        printf "\033[31mError: The port number must be less than 65535.\033[m\n\n"
        helpinfo
        exit 1
    fi

    filepath=$RANDOM
    unzip
    setprivilege
    exesql
    setapachesetting
    echo $filepath
    exit 1
    ;;

    -d | --delete)
    while [ $# -gt 1 ] ; do
        case "$2" in
            --port)
            shift
            if !(isnumeric "$2")
            then
                printf "\033[31mError: Please provide a valid port.\033[m\n\n"
                exit 1
            fi
            port=$2
            shift
            ;;

            --chalfile)
            shift
            if !(isnumeric "$2")
            then
                printf "\033[31mError: Please provide a chalfile.\033[m\n\n"
                exit 1
            fi
            chalfile=$2
            shift
            ;;

            *)
            printf "\033[31mError: Unkown option '$2'.\033[m\n\n"
            exit 1
            ;;
        esac
    done
    if [ -z "$port" ] || [ -z "$chalfile" ] ; then
        printf "\033[31mError: More Args needed.\033[m\n\n"
        helpinfo
        exit 1
    fi

    deletedb
    removeapacheconfig
    removefile
    exit 0
    ;;

    -u | --unhidden)
    while [ $# -gt 1 ] ; do
        case "$2" in
            --port)
            shift
            if !(isnumeric "$2")
            then
                printf "\033[31mError: Please provide a valid port.\033[m\n\n"
                exit 1
            fi
            port=$2
            shift
            ;;

            *)
            printf "\033[31mError: Unkown option '$2'.\033[m\n\n"
            exit 1
            ;;
        esac
    done

    if [ -z "$port" ]  ; then
        printf "\033[31mError: More Args needed.\033[m\n\n"
        helpinfo
        exit 1
    fi
    unhiddenchal
    exit 0
    ;;

    -h | --hidden)
    while [ $# -gt 1 ] ; do
        case "$2" in
            --port)
            shift
            if !(isnumeric "$2")
            then
                printf "\033[31mError: Please provide a valid port.\033[m\n\n"
                exit 1
            fi
            port=$2
            shift
            ;;

            *)
            printf "\033[31mError: Unkown option '$2'.\033[m\n\n"
            exit 1
            ;;
        esac
    done

    if [ -z "$port" ]  ; then
        printf "\033[31mError: More Args needed.\033[m\n\n"
        helpinfo
        exit 1
    fi
    hiddenchal
    exit 0
    ;;

    *)
    if [ "$#" != "0" ] ; then
        printf "\033[31mError: Unkown option '$1'.\033[m\n\n"
    fi
    helpinfo
    exit 1
    ;;


esac