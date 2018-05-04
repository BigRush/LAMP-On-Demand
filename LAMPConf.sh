#!/usr/bin/env #!/usr/bin/env bash

#######################################################################################
# Author	: BigRush
#
#License	: GPLv3
#
# Description	: Menu for installing and configuring LAMP/LEMP services automatically.
#
# Version	: 1.0.0
#######################################################################################

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
####ToDo####
#1) polish Functions
#2) add python 3 support
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

####Functions####

Root_Check () {		## checks that the script runs as root
	if [[ $EUID -eq 0 ]]; then
		:
	else
		printf "$line\n"
		printf "The script needs to run with root privileges\n"
		printf "$line\n"
		exit 1
	fi
}

Log_And_Variables () {		## set log path and variables for installation logs, makes sure whether log folder exists and if not, create it
	####Variables####
	line="***************************************"
	whiptail_install_stderr_log=/var/log/LAMP-On-Demand/Error_whiptail_install.log
	whiptail_install_stdout_log=/var/log/LAMP-On-Demand/whiptail_install.log
	web_install_stderr_log=/var/log/LAMP-On-Demand/Error_websrv_install.log
	web_install_stdout_log=/var/log/LAMP-On-Demand/websrv_install.log
	web_service_stderr_log=/var/log/LAMP-On-Demand/Error_websrv_service.log
	web_service_stdout_log=/var/log/LAMP-On-Demand/websrv_service.log
	db_install_stderr_log=/var/log/LAMP-On-Demand/Error_dbsrv_install.log
	db_install_stdout_log=/var/log/LAMP-On-Demand/dbsrv_install.log
	db_service_stdout_log=/var/log/LAMP-On-Demand/dbsrv_service.log
	db_service_stderr_log=/var/log/LAMP-On-Demand/Error_dbsrv_service.log
	lang_install_stderr_log=/var/log/LAMP-On-Demand/Error_lang_install.log
	lang_install_stdout_log=/var/log/LAMP-On-Demand/lang_install.log
	lang_service_stderr_log=/var/log/LAMP-On-Demand/Error_lang_service.log
	lang_service_stdout_log=/var/log/LAMP-On-Demand/lang_service.log
	repo_stderr_log=/var/log/LAMP-On-Demand/Error_repo.log
	repo_stdout_log=/var/log/LAMP-On-Demand/repo.log
	firewall_log=/var/log/LAMP-On-Demand/firewall.log
	php_conf=/etc/httpd/conf.d/php.conf
	php_fpm_conf=/etc/php-fpm.d/www.conf
	php_ini_conf=/etc/php.ini
	log_folder=/var/log/LAMP-On-Demand
	tempLAMP=$log_folder/LAMP_choise.tmp
	apache_index_path=/var/www/html/index.html
	nginx_index_path=/usr/share/nginx/html/index.html
	nginx_conf_path=/etc/conf.d/default.conf
	read -r -d '' my_index_html <<- EOF
    <!DOCTYPE html>
    <html>
      <head>
        <title>LAMP-On-Demand</title>
      </head>
      <body>
        <h1>This page is badly writen</h1>

        <p>Best Distro (from top to bottom)</p>

        <ul>
          <li>ArchLinux</li>
          <li>Manjaro</li>
          <li>Fedora</li>
          <li>OpenSuse</li>
          <li>SteamOS</li>
          <li>Debian</li>
        </ul>

      </body>
    </html>
EOF
	read -r -d '' nginx_conf_file <<- EOF
    server {
      listen       80;
      server_name  127.0.0.1;

      root   /usr/share/nginx/html;
      index index.php index.html index.htm;

      location / {
        try_files $uri $uri/ =404;
      }
      error_page 404 /404.html;
      error_page 500 502 503 504 /50x.html;
      location = /50x.html {
        root /usr/share/nginx/html;
      }

      location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
      }
    }
EOF
	####Variables####

	if [[ -d $log_folder ]]; then
		:
	else
		mkdir -p $log_folder
	fi
}

Progress_Bar () {		## progress bar that runs while the installation process is running

	{
		i=3		## i represents the completion percentage, the progress bar will start at 3%
		while true ;do		## endless loop
			ps aux |awk '{print $2}' |egrep -Eo "$!" &> /dev/null		## checks if our process is still alive by checking if his PID shows in ps command
			if [[ $? -eq 0 ]]; then		## checks exit status of last command, if succeed

				## make sure that if our process takes a long time that the percentage will not exceed 94%
				## if it doesn't print the current percentage, add 7 to the percentage variable and wait 2.5 seconds
				if [[ $i -le 94 ]]; then
					printf "$i\n"
					i=$(expr $i + 7)
					sleep 2.5
				fi
			else		## when ps fails to get the process break the loop
				break
			fi
		done

		## when the loop is done print 96%, 98%, and 100%, wait 0.5 second between each and lastly wait 1 second
		printf "96\n"
		sleep 0.5
		printf "98\n"
		sleep 0.5
		printf "100\n"
		sleep 1
	} |whiptail --gauge "Please wait while installing..." 6 50 0
}

Distro_Check () {		## checking the environment the user is currenttly running on to determine which settings should be applied
	cat /etc/*-release |grep ID |cut  -d "=" -f "2" |egrep "^arch$|^manjaro$" &> /dev/null

	if [[ $? -eq 0 ]]; then
	  	Distro_Val="arch"
	else
	  	:
	fi

  cat /etc/*-release |grep ID |cut  -d "=" -f "2" |egrep "^debian$|^\"Ubuntu\"$" &> /dev/null

  if [[ $? -eq 0 ]]; then
    	Distro_Val="debian"
  else
    	:
  fi

	cat /etc/*-release |grep ID |cut  -d "=" -f "2" |egrep "^\"centos\"$|^\"fedora\"$" &> /dev/null

	if [[ $? -eq 0 ]]; then
	   	Distro_Val="centos"
	else
		:
	fi
}

Repo_Check () { 		## check for existing repositories
	if [[ $Distro_Val =~ "centos" ]]; then
		if [[ -e /etc/yum.repos.d/remi.repo ]]; then
			remi_repo=0
		else
			remi_repo=1
		fi

		if [[ -e /etc/yum.repos.d/epel.repo ]]; then
			epel_repo=0
		else
			epel_repo=1
		fi
	fi
}

Whiptail_Check () {		## checks if whiptail is installed, if it doesn't then install whiptail
	command -v whiptail &> /dev/null
	if [[ $? -eq 0 ]]; then
		:
	elif [[ $? -eq 1 ]]; then
		printf "Whiptail is needed to run this script and it's not installed...\n"
		read -p "Would you like to install whiptail to run this script? [y/n]: " answer
		until [[ $answer =~ [y|Y|n|N] ]]; do
			printf "Invalid option\n"
			printf "Whiptail is not installed...\n"
			read -p "Would you like to install whiptail to run this script? [y/n]: " answer
		done
		if [[ $answer =~ [y|Y] ]]; then
			if [[ $Distro_Val =~ "centos" ]]; then
				yum install whiptail -y 2>> $whiptail_install_stderr_log_log >> $whiptail_install_stdout_log_log
			elif [[ $Distro_Val =~ "debian" ]]; then
				apt-get install whiptail -y 2>> $whiptail_install_stderr_log_log >> $whiptail_install_stdout_log_log
			fi
				if [[ $? -eq 0 ]]; then
					:
				else
					printf "$line\n"
					printf "Something went wrong during whiptail installation\n"
					printf "Please check the log file under /var/log/LAMP-On-Demand/Error_whiptail_install.log\n"
					printf "$line\n"
					exit 1
				fi
		elif [[ $answer =~ [n|N] ]]; then
			printf "$line\n"
			printf "Exiting, have a nice day!\n"
			printf "$line\n"
			exit 0
		fi
	fi

}

Web_Server_Installation () {		## choose which web server would you like to install

	## prompt the user with a menu to select whether to install apache or nginx web server,
	## the user's input will be stored in a temporary file,
	## by checking the value we stored in the temporary file the script will install the chosen web server according to the user's distro.
	whiptail --title "LAMP-On-Demand" \
	--menu "Please choose web server to install:" 15 55 5 \
	"Apache" "Open-source cross-platform web server" \
	"Nginx" "Web, reverse proxy server and more" \
	"<---Back" "Back to main menu" \
	"Exit" "Walk away from the path to LAMP stack :(" 2> $tempLAMP
	clear

	if [[ $(cat $tempLAMP) =~ "Apache" ]]; then		## check the temp file to see the user's choice
		if [[ $Distro_Val =~ "centos" ]]; then		## check the user's distribution
			## install apache server, send stderr & stdout to log files
			## put the process in the background so we could use "$!" (PID of the most recently executed background command) later to get the PID
			yum install httpd -y 2>> $web_install_stderr_log >> $web_install_stdout_log &
			status=$?
			Progress_Bar		## call "Progress_Bar" function

		elif [[ $Distro_Val =~ "debian" ]]; then		## check the user's distribution
			## install apache server, send stderr & stdout to log files
			## put the process in the background so we could use "$!" (PID of the most recently executed background command) later to get the PID
			apt-get install apache2 -y 2>> $web_install_stderr_log >> $web_install_stdout_log &
			status=$?
			Progress_Bar		## call "Progress_Bar" function
		fi

		if [[ $status -eq 0 ]]; then		## check exit status, let the user know if the installation was successfull
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nApache installation completed successfully, have a nice day!." 8 65

			## prompets yes/no and ask the user whether he wants to configure apache
			if (whiptail --title "LAMP-On-Demand" --yesno "Would you like to configure Apache?" 8 40); then
				Web_Server_Configuration
			else
				Main_Menu
			fi

		else
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nSomething went wrong during Apache installation.\nPlease check the log file under:\n$web_install_stderr_log" 10 60
			exit 1
		fi

	elif [[ $(cat $tempLAMP) =~ "Nginx" ]]; then
		if [[ $Distro_Val =~ "centos" ]]; then
			if [[ $epel_repo -eq 0 ]]; then
				yum -y install epel-release 2>> $repo_stderr_log >> $repo_stdout_log &
				status=$?
				Progress_Bar
				if [[ $status -eq 0 ]]; then
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nEPEL repo installation complete." 8 37
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nSomething went wrong, EPEL repo installation failed." 8 57
					exit 1
				fi
			fi

			yum --enablerepo=epel -y install nginx 2>> $web_install_stderr_log >> $web_install_stdout_log &
			status=$?
			Progress_Bar
			if [[ $status -eq 0 ]]; then
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nNginx installation completed successfully, have a nice day!" 8 65
				if (whiptail --title "LAMP-On-Demand" --yesno "Would you like to configure Nginx?" 8 40); then
					Web_Server_Configuration
				else
					Main_Menu
				fi

			else
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nSomething went wrong during Nginx installation.\nPlease check the log file under:\n$web_install_stderr_log" 10 60
				exit 1
			fi

		elif [[ $Distro_Val =~ "debian" ]]; then
			apt-get install nginx -y 2>> $web_install_stderr_log >> $web_install_stdout_log &
			status=$?
			Progress_Bar
		fi

		if [[ $status -eq 0 ]]; then
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nNginx installation completed successfully, have a nice day!." 8 65
			if (whiptail --title "LAMP-On-Demand" --yesno "Would you like to configure Nginx?" 8 40); then
				Web_Server_Configuration
			else
				Main_Menu
			fi

		else
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nSomething went wrong during Nginx installation.\nPlease check the log file under:\n$web_install_stderr_log" 10 60
			exit 1
		fi

	elif [[ "$(cat $tempLAMP)" == "<---Back" ]]; then
		Main_Menu

	elif [[ "$(cat $tempLAMP)" =~ "Exit" ]]; then
		whiptail --title "LAMP-On-Demand" \
		--msgbox "\nExit - I hope you feel safe now" 8 37
		exit 0
	fi
	}

Web_Server_Configuration () {		## start the web server's service
	if [[ "$(cat $tempLAMP)" =~ "Apache" ]]; then
		printf "$my_index_html\n" > $apache_index_path
		if [[ $Distro_Val =~ "centos" ]]; then
			systemctl enable httpd 2>> $web_service_stderr_log >> $web_service_stdout_log
			if [[ $? -eq 0 ]]; then
				:
			else
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nSomething went wrong while enabling the service.\nPlease check the log file under:\n$web_service_stderr_log" 10 60
				exit 1
			fi
			systemctl restart httpd 2>> $web_service_stderr_log >> $web_service_stdout_log
			if [[ $? -eq 0 ]]; then
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nApache web server is up and running!" 8 40
			else
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nSomething went wrong while enabling the service.\nPlease check the log file under:\n$web_service_stderr_log" 10 60
				exit 1
			fi
			systemctl status firewalld |awk '{print $2}' |egrep 'active' &> /dev/null
			if [[ $? -eq 0 ]]; then
				firewall-cmd --add-service=http --permanent &> $firewall_log
				if [[ $? -eq 0 ]]; then
					:
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nFailed to add HTTP service to firewall rules" 8 50
					exit 1
				fi
				firewall-cmd --reload
				if [[ $? -eq 0 ]]; then
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nFireWall rule added for Apache" 8 40
					Main_Menu
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nFailed to reload firewall.\nPlease check the log file under $firewall_log" 8 78
					exit 1
				fi
			else
				Main_Menu
			fi
		elif [[ $Distro_Val =~ "debian" ]]; then
			systemctl enable apache2 2>> $web_service_stderr_log >> $web_service_stdout_log
			if [[ $? -eq 0 ]]; then
				:
			else
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nSomething went wrong while enabling the service.\nPlease check the log file under:\n$web_service_stderr_log" 10 60
				exit 1
			fi
			systemctl restart apache2 2>> $web_service_stderr_log >> $web_service_stdout_log
			if [[ $? -eq 0 ]]; then
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nApache web server is up and running!" 8 40
			else
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nSomething went wrong while enabling the service.\nPlease check the log file under:\n$web_service_stderr_log" 10 60
				exit 1
			fi
		fi

	elif [[ "$(cat $tempLAMP)" =~ "Nginx" ]]; then
		printf "$my_index_html\n" > $nginx_index_path
		systemctl enable nginx 2>> $web_service_stderr_log >> $web_service_stdout_log
		if [[ $? -eq 0 ]] ;then
			:
		else
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nSomething went wrong while enabling the service.\nPlease check the log file under:\n$web_service_stderr_log" 10 60
			exit 1
		fi
		systemctl restart nginx 2>> $web_service_stderr_log >> $web_service_stdout_log
		if [[ $? -eq 0 ]] ;then
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nNginx web server is up and running!" 8 40
		else
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nSomething went wrong while enabling the service.\nPlease check the log file under:\n$web_service_stderr_log" 10 60
			exit 1
		fi

		if [[ $Distro_Val =~ "centos" ]]; then
			systemctl status firewalld |awk '{print $2}' |egrep 'active' &> /dev/null
			if [[ $? -eq 0 ]]; then
				firewall-cmd --add-service=http --permanent &> $firewall_log
				if [[ $? -eq 0 ]]; then
					:
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nFailed to add HTTP service to firewall rules" 8 50
					exit 1
				fi
				firewall-cmd --reload
				if [[ $? -eq 0 ]]; then
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nFireWall rule added for Nginx" 8 40
					Main_Menu
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nFailed to reload firewall.\nPlease check the log file under $firewall_log" 8 78
					exit 1
				fi
			else
				Main_Menu
			fi
		else
			Main_Menu
		fi
	fi
}

DataBase_Installation () {		## choose which data base server would you like to install
	## prompt the user with a menu to select whether to install apache or nginx web server
	whiptail --title "LAMP-On-Demand" \
	--menu "Please choose sql server to install:" 15 55 5 \
	"MariaDB" "Fork of the MySQL relational database"\
	"PostgreSQL" "Object-relational database" \
	"<---Back" "Back to main menu" \
	"Exit" "Walk away from the path to LAMP stack :(" 2> $tempLAMP

	if [[ "$(cat $tempLAMP)" =~ "MariaDB" ]]; then
		if [[ $Distro_Val =~ "centos" ]]; then
			yum install mariadb-server mariadb -y 2>> $db_install_stderr_log >> $db_install_stdout_log &
			status=$?
			Progress_Bar
		elif [[ $Distro_Val =~ "debian" ]]; then
			apt-get install mariadb-server mariadb-client -y 2>> $db_install_stderr_log >> $db_install_stdout_log &
			status=$?
			Progress_Bar
		fi

		if [[ $status -eq 0 ]]; then
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nMariaDB installation completed successfully, have a nice day!" 8 70
			if (whiptail --title "LAMP-On-Demand" --yesno "Would you like to configure MariaDB?" 8 40); then
				Web_Server_Configuration
			else
				Main_Menu
			fi

		else
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nSomething went wrong during MariaDB installation.\nPlease check the log file under:\n$db_install_stderr_log" 10 60
			exit 1
		fi

	elif [[ "$(cat $tempLAMP)" =~ "PostgreSQL" ]]; then
		if [[ $Distro_Val =~ "centos" ]]; then
			yum install postgresql-server postgresql-contrib -y 2>> $db_install_stderr_log >> $db_install_stdout_log &
			status=$?
			Progress_Bar

		elif [[ $Distro_Val =~ "debian" ]]; then
			apt-get install postgresql postgresql-contrib -y 2>> $db_install_stderr_log >> $db_install_stdout_log &
			status=$?
			Progress_Bar
		fi

		if [[ $status -eq 0 ]]; then
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nPostgresql installation completed successfully, have a nice day!" 8 70
			if (whiptail --title "LAMP-On-Demand" --yesno "Would you like to set up PostgreSQL?" 8 40); then
				DataBase_Configuration
			else
				Main_Menu
			fi

		else
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nSomething went wrong during PostgreSQL installation.\nPlease check the log file under:\n$db_install_stderr_log" 10 60
			exit 1
		fi

	elif [[ "$(cat $tempLAMP)" == "<---Back" ]]; then
		Main_Menu

	elif [[ "$(cat $tempLAMP)" =~ "Exit" ]]; then
		whiptail --title "LAMP-On-Demand" \
		--msgbox "\nExit - I hope you feel safe now." 8 37
		exit 0
	fi
}

DataBase_Configuration () {		## configure data base
	if [[ "$(cat $tempLAMP)" =~ "MariaDB" ]]; then
		mysql_secure_installation
		if [[ $? -eq 0 ]]; then
			:
		else
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nFailed to securly configure MariaDB server" 8 50
			exit 1
		fi

		systemctl enable mariadb 2>> $db_service_stderr_log >> $db_service_stdout_log
		if [[ $? -eq 0 ]]; then
			:
		else
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nSomething went wrong while enabling the service.\nPlease check the log file under:\n$db_service_stderr_log" 10 60
			exit 1
		fi
		systemctl restart mariadb 2>> $db_service_stderr_log >> $db_service_stdout_log
		if [[ $? -eq 0 ]] ;then
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nMariaDB server is up and running!" 8 40
		else
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nSomething went wrong while enabling the service.\nPlease check the log file under:\n$db_service_stderr_log" 10 60
			exit 1
		fi

		if [[ $Distro_Val =~ "centos" ]]; then
			systemctl status firewalld |awk '{print $2}' |egrep 'active' &> /dev/null
			if [[ $? -eq 0 ]]; then
				firewall-cmd --add-service=mysql --permanent &> $firewall_log
				if [[ $? -eq 0 ]]; then
					:
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nFailed to add MariaDB service to firewall rules.\nPlease check the log file under $firewall_log" 8 78
					exit 1
				fi
				firewall-cmd --reload
				if [[ $? -eq 0 ]]; then
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nFireWall rule added for MariaDB" 8 40
					Main_Menu
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nFailed to reload firewall.\nPlease check the log file under $firewall_log" 8 78
					exit 1
				fi
			else
				Main_Menu
			fi
		else
			Main_Menu
		fi

	elif [[ "$(cat $tempLAMP)" =~ "PostgreSQL" ]]; then
		postgresql-setup initdb
		if [[ $? -eq 0 ]]; then
			:
		else
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nSomething went wrong while initiating the PostgreSQL DataBase" 9 65
			exit 1
		fi

		systemctl enable postgresql 2>> $db_service_stderr_log >> $db_service_stdout_log
		if [[ $? -eq 0 ]]; then
			:
		else
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nSomething went wrong while enabling the service.\nPlease check the log file under:\n$db_service_stderr_log" 10 60
			exit 1
		fi
		systemctl restart postgresql 2>> $db_service_stderr_log >> $db_service_stdout_log
		if [[ $? -eq 0 ]]; then
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nPostgresql server is up and running!" 8 40
		else
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nSomething went wrong while restarting the service.\nPlease check the log file under $db_service_stderr_log" 8 78
			exit 1
		fi
		if [[ $Distro_Val =~ "centos" ]]; then
			systemctl status firewalld |awk '{print $2}' |egrep 'active' &> /dev/null
			if [[ $? -eq 0 ]]; then
				firewall-cmd --add-service=postgresql --permanent &> $firewall_log
				if [[ $? -eq 0 ]]; then
					:
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nFailed to add PostgreSQL service to firewall rules.\nPlease check the log file under $firewall_log" 8 78
					exit 1
				fi
				firewall-cmd --reload
				if [[ $? -eq 0 ]]; then
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nFireWall rule added for PostgreSQL" 8 40
					Main_Menu
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nFailed to reload firewall.\nPlease check the log file under $firewall_log" 8 78
					exit 1
				fi
			else
				Main_Menu
			fi
		else
			Main_Menu
		fi
	fi
}

Lang_Installation () {	## installs language support of user choice
	whiptail --title "LAMP-On-Demand" \
	--menu "Please choose lang server to install:" 15 55 5 \
	"PHP 5.4" "PHP Version 5.4 (***CentOS_7 only***)" \
	"PHP 7.0" "PHP Version 7.0" \
	"Python" "Python Version 3" \
	"<---Back" "Back to main menu" \
	"Exit" "Walk away from the path to LAMP stack :(" 2> $tempLAMP

	if [[ "$(cat $tempLAMP)" == "PHP 5.4" ]]; then
		if [[ $Distro_Val =~ "centos" ]]; then
			yum install php php-mysql php-fpm -y 2>> $lang_install_stderr_log >> $lang_install_stdout_log &
			status=$?
			Progress_Bar
			if [[ $status -eq 0 ]]; then
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nPHP 5.4 installation completed successfully, have a nice day!" 8 70
				if (whiptail --title "LAMP-On-Demand" --yesno "Would you like to configure MariaDB?" 8 40); then
					Lang_Configuration
				else
					Main_Menu
				fi

			else
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nSomething went wrong during PHP 5.4 installation.\nPlease check the log file under:\n$lang_install_stderr_log" 10 60
				exit 1
			fi

		elif [[ $Distro_Val =~ "debian" ]]; then
			whiptail --title "LAMP-On-Demand" \
			--msgbox "\nSorry, this script doesn't support php 5.4 installation for Debian." 8 78
			Lang_Installation
		fi

	elif [[ "$(cat $tempLAMP)" == "PHP 7.0" ]]; then
		if [[ $Distro_Val =~ "centos" ]]; then
			if [[ $remi_repo -eq 0 ]]; then
				yum -y install http://rpms.famillecollet.com/enterprise/remi-release-7.rpm 2>> $repo_stderr_log >> $repo_stdout_log &
				status=$?
				Progress_Bar
				if [[ $status -eq 0 ]]; then
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nRemi's repo installation complete." 8 40
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nSomething went wrong, Remi's repo installation failed." 8 60
					exit 1
				fi
			fi

			yum --enablerepo=remi-safe -y install php70 php70-php-pear php70-php-mbstring php70-php-fpm 2>> $lang_install_stderr_log >> $lang_install_stdout_log &
			status=$?
			Progress_Bar
			if [[ $? -eq 0 ]]; then
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nPHP 7.0 installation completed successfully, have a nice day!" 8 70
				if (whiptail --title "LAMP-On-Demand" --yesno "Would you like to configure MariaDB?" 8 40); then
					Lang_Configuration
				else
					Main_Menu
				fi

			else
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nSomething went wrong during PHP 7.0 installation.\nPlease check the log file under:\n$lang_install_stderr_log" 10 60
				exit 1
			fi

		elif [[ $Distro_Val =~ "debian" ]]; then
			apt-get install php7.0 php7.0-mysql libapache2-mod-php7.0 -y 2>> $lang_install_stderr_log >> $lang_install_stdout_log &
			status=$?
			Progress_Bar
			if [[ $? -eq 0 ]]; then
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nPHP 7.0 installation completed successfully, have a nice day!" 8 70
				if (whiptail --title "LAMP-On-Demand" --yesno "Would you like to configure MariaDB?" 8 40); then
					Lang_Configuration
				else
					Main_Menu
				fi
				
			else
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nSomething went wrong during PHP 7.0 installation.\nPlease check the log file under:\n$lang_install_stderr_log" 10 60
			fi
		fi

	elif [[ "$(cat $tempLAMP)" == "<---Back" ]]; then
		Main_Menu

	elif [[ "$(cat $tempLAMP)" =~ "Exit" ]]; then
		whiptail --title "LAMP-On-Demand" \
		--msgbox "\nExit - I hope you feel safe now." 8 37
		exit 0
	fi
}

Lang_Configuration () {

	if [[ "$(cat $tempLAMP)" == "PHP 5.4" ]]; then
		systemctl status httpd |awk '{print $2}' |egrep 'active' &> /dev/null

		if [[ $? -eq 0 ]]; then
			systemctl restart httpd 2>> $web_service_stderr_log
			if [[ $? -eq 0 ]]; then
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nPHP 7.0 support is up and running!" 8 40
			else
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nSomething went wrong while enabling the service.\nPlease check the log file under:\n$web_service_stderr_log" 10 60
				exit 1
			fi

		else
			systemctl status nginx |awk '{print $2}' |egrep 'active' &> /dev/null
			if [[ $? -eq 0 ]]; then
				sed -ie 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' $php_ini_conf 2>> $lang_service_stderr_log
				sed ie 's/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm\/php-fpm.sock/' $php_fpm_conf 2>> $lang_service_stderr_log
				sed -ie 's/user = apache/user = nginx/' $php_fpm_conf 2>> $lang_service_stderr_log

				systemctl restart php-fpm 2>> $lang_service_stderr_log
				if [[ $? -eq 0 ]]; then
					printf "$nginx_conf_file\n" > $nginx_conf_path		## reconfig nginx to work with php-fpm
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nSomething went wrong while restarting php-fpm service.\nPlease check the log file under:\n$lang_service_stderr_log" 10 60
					exit 1
				fi

				systemctl restart nginx 2>> $web_service_stderr_log
				if [[ $? -eq 0 ]]; then
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nPHP support is up and running!" 8 40
					Main_Menu
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nSomething went wrong while restarting nginx service.\nPlease read:\n$web_service_stderr_lognnd:\n$Error_lang_service" 8 60
					exit 1
				fi

			else
				whiptail --title "LAMP-On-Demand" \
				--msgbox "\nCould not detect a running web server, please make sure apache or nginx is running." 8 78
				exit 1
			fi
		fi




	elif [[ "$(cat $tempLAMP)" == "PHP 7.0" ]]; then
		if [[ $Distro_Val =~ "centos" ]]; then
			systemctl status httpd |awk '{print $2}' |egrep 'active' &> /dev/null
			if [[ $? -eq 0 ]]; then
				sed -ie 's/SetHandler.*/SetHandler \"proxy:fcgi://127.0.0.1:9000\"/' $php_conf
				if [[ $? -eq 0 ]]; then
					systemctl restart httpd 2>> $web_service_stderr_log >> $web_service_stdout_log
					if [[ $? -eq 0 ]]; then
						whiptail --title "LAMP-On-Demand" \
						--msgbox "\nPHP 7.0 support is up and running!" 8 40
					else
						whiptail --title "LAMP-On-Demand" \
						--msgbox "\nSomething went wrong while enabling the service.\nPlease check the log file under:\n$web_service_stderr_log" 10 60
						exit 1
					fi
				else
					whiptail --title "LAMP-On-Demand" \
					--msgbox "\nThere was a problem with sed command or the \"php.conf\" file doesn't exists" 8 78
					exit 1
				fi

			else
				exit 1
			fi



		elif [[ $Distro_Val =~ "debian" ]]; then
			printf "$line\n"
			printf "The script dows not support language configuration for debian at the moment...\n"
			printf "$line\n"

		fi
	fi
}

Main_Menu () {
	####function calls####
	Root_Check
	Distro_Check
	Log_And_Variables
	Whiptail_Check
	Repo_Check
	####function calls####

	if [[ $Distro_Val =~ "centos" ]]; then
		:

	elif [[ $Distro_Val =~ "debian" ]]; then
		:

	elif [[ $Distro_Val =~ "arch" ]]; then
		whiptail --title "LAMP-On-Demand" \
		--msgbox "\nThe script does not support arch based distribution" 8 55
		exit 1

	else
		whiptail --title "LAMP-On-Demand" \
		--msgbox "\nThe script does not support your distribution" 8 55
		exit 1
	fi

	whiptail --title "LAMP-On-Demand" \
	--menu "Please choose what whould you like to install:" 15 70 5 \
	"Web server" "Apache2, Nginx" \
	"DataBase server" "MariaDB, PostgreSQL" \
	"Language" "PHP, Python 3.6" \
	"Exit" "Walk away from the path to LAMP stack :(" 2> $tempLAMP

	if [[ "$(cat $tempLAMP)" == "Web server" ]]; then
		Web_Server_Installation
	elif [[ "$(cat $tempLAMP)" == "DataBase server" ]]; then
		DataBase_Installation
	elif [[ "$(cat $tempLAMP)" == "Language server" ]]; then
		Lang_Installation
	elif [[ "$(cat $tempLAMP)" == "Exit" ]]; then
		whiptail --title "LAMP-On-Demand" \
		--msgbox "\nExit - I hope you feel safe now." 8 37
		exit 0
	fi
}

Main_Menu
