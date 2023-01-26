# STILL TO DO
# LOG ERRORS SO WE CAN FIND FAILURES DURING MIGRATIONS 100K SITES
# ADJUST WEBSITE PHP VERSION TO 4.4

#!/bin/sh

 echo "What is the cPanel username!"
 read cpuser

 cd /home/{cpuser}/public_html

# Locate the relevant config (in this case wp-config)

$wpconf = "find . -name wp-config.php -type f"

$dbname = grep "DB_NAME" $wpconf

$username = grep "DB_USER" $wpconf

$userpass = grep "DB_PASSWORD" $wpconf

$sqldump = "find . -name \*.sql -type f"

# Create the db
# If /root/.my.cnf exists then it won't ask for root password

if [ -f /root/.my.cnf ]; then

	   
	echo "Creating new MySQL database..."
	mysql -e "CREATE DATABASE ${dbname} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
	echo "Database successfully created!"
	
    
	echo "Creating new user..."
	mysql -e "CREATE USER ${username}@localhost IDENTIFIED BY '${userpass}';"
	echo "User successfully created!"

	echo "Granting ALL privileges on ${dbname} to ${username}!"
	mysql -e "GRANT ALL PRIVILEGES ON ${dbname}.* TO '${username}'@'localhost';"
	mysql -e "FLUSH PRIVILEGES;"
	echo "You're good now on that, just importing the dump"

    mysql -e ${dbname} < {$sqldump}

    echo "Awesome, all done!"

	exit

#Map the DB to a user

    /usr/local/cpanel/bin/dbmaptool ${cpuser} --type mysql --dbs ${dbname}

    echo "We've added ${dbname} to the dbmap for account ${cpuser}"

#ADVISE OF ERRORS
