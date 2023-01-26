#!/bin/sh

 	echo "What is the cPanel username!"
	read cpuser

 	cd /home/${cpuser}/public_html

# Variable settings & file finding

	 wpconf=$(find . -name wp-config.php -type f)
	 dbname=$(grep "DB_NAME" ${wpconf} | cut -d \' -f 4)
 	 username=$(grep "DB_USER" ${wpconf} | cut -d \' -f 4)
	 userpass=$(grep "DB_PASSWORD" ${wpconf} | cut -d \' -f 4)
	 sqldump=$(find . -name \*.sql -type f)
	 newdbname=$cpuser"_"$dbname
	 newdbuser=$cpuser"_"$username
	 hostname=$(hostname)
 	 wpbackup=$(cp ${wpconf} wpconf-backup.php)
 	 wpbackuplocation=$(find . -name wpconf-backup.php -type f)
	 sitebackuplocation=$(find . -name sitefiles -type d)
	 sitelocation=$(/home/${cpuser}/public_html)

# Check the SQL version being used



# Create the db
# If /root/.my.cnf exists then it won't ask for root password

if [ -f /root/.my.cnf ]; then

	   
	echo "Creating new MySQL database..."
	mysql -e "CREATE DATABASE ${newdbname} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
	echo "Database successfully created!"
	
    
	echo "Creating new user..."
	mysql -e "CREATE USER ${newdbuser}@localhost IDENTIFIED BY '${userpass}';"
	echo "User successfully created!"

	echo "Granting ALL privileges on ${newdbname} to ${newdbuser}!"
	mysql -e "GRANT ALL PRIVILEGES ON ${newdbname}.* TO '${newdbuser}'@'localhost';"
	mysql -e "FLUSH PRIVILEGES;"
	echo "You're good now on that, just importing the dump"

## Other DB's in dump need creating

    mysql -e ${newdbname} < ${sqldump}
    echo "Awesome, all done!"
	exit

#Map the DB to a user

    /usr/local/cpanel/bin/dbmaptool ${cpuser} --type mysql --dbs ${newdbname}
    echo "We've added ${newdbname} to the dbmap for account ${cpuser}"

# Make a copy of wp-config

	cp $wpconf wpconf-backup
	echo "We've made a backup of your config prior to these changes"
	echo "This can be found at $wpbackuplocation"

# Add DB & USER prefix in wp-config

	$wpconf -exec sed -i s/$dbname/$newdbname/gI {} \;
	echo "We've now replaced $dbname with $newdbname in the WP Config"

	$wpconf -exec sed -i s/$username/$newdbuser/gI {} \;
	echo "We've now replaced $username with $newdbuser in the WP Config"

# Add info to advise wp-config auto updated

# CLEANUP // DELETE SQL DUMP

	rm $sqldump -f
	echo "SQL Dump succesfully removed"

# CLEANUP // MOVE SITE FILES TO PUBLIC_HTML

	mv -v $sitebackuplocation $sitelocation
	echo "Migrated files moved to correct location"

	rm $sitebackuplocation -f
	echo "Old directory removed"
# ADVISE OF ERRORS

# CP INSTANCE NAME

	echo You have migrated this account to $hostname
