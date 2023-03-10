#!/bin/sh

cpuser=$1

cd "/home/$cpuser/public_html"

#find SQL DUMP

sqldump=$(find . -name _schemas.sql -type f)

if [ -z $sqldump ];

#If no sql, then echo nothing

then echo "No sql file, nothing to do"

#If SQL found then amend the entries required in the schema

else

dbusers=$(grep -Pzo '(?s)INTO .?db.? VALUES[^(]\K[^;]*' $sqldump | grep -Pao '\(([^,]*,){2}\K[^,]*' | grep -Pzo [^\']);
dbnames=$(grep -Pzo '(?s)INTO .?db.? VALUES[^(]\K[^;]*' $sqldump | grep -Pao '\(([^,]*,){1}\K[^,]*' | grep -Pzo [^\']);
dbnames=$(echo $dbnames | xargs -n1 | sort| uniq);

for dbuser in $dbusers
do
        if [[ $dbuser != ${cpuser}\_* ]]
        then
                sed -i "/INTO \`db\` VALUES/ s/$dbuser\\b/${cpuser}\_${dbuser}/g" $sqldump
        fi
done

for dbname in $dbnames
do
if [[ $dbname != ${cpuser}\_* ]]
        then
                sed -i "/INTO \`db\` VALUES/ s/$dbname\\b/${cpuser}\_${dbname}/g" $sqldump
        fi
done

find . -name '_schemas.sql' -exec sed -i "s/\\(CREATE DATABASE [^\`]*\`\\)/\\1${cpuser}_/" {} +
find . -name '_schemas.sql' -exec sed -i "s/\\(USE [^\`]*\`\\)/\\1${cpuser}_/" {} +
find . -name '_schemas.sql' -exec sed -i "s/char(16)/char(32)/g" {} +

fi

mysql -f -u root < ${sqldump}

#find SQL version

sqlver=$(awk '/Server version/ { split($NF,a,"."); print a[1] "." a[2] }' _schemas.sql)

#Map the DBs & users to a cpanel user (4.1)

if [ "$sqlver" == "4.1" ];

then

echo "alter table "$cpuser"_mysql.db
add Create_tmp_table_priv enum('N','Y') CHARACTER SET utf8 NOT NULL DEFAULT 'N',
add Lock_tables_priv enum('N','Y') CHARACTER SET utf8 NOT NULL DEFAULT 'N',
add Create_view_priv enum('N','Y') CHARACTER SET utf8 NOT NULL DEFAULT 'N',
add Show_view_priv enum('N','Y') CHARACTER SET utf8 NOT NULL DEFAULT 'N',
add Create_routine_priv enum('N','Y') CHARACTER SET utf8 NOT NULL DEFAULT 'N',
add Alter_routine_priv enum('N','Y') CHARACTER SET utf8 NOT NULL DEFAULT 'N',
add Execute_priv enum('N','Y') CHARACTER SET utf8 NOT NULL DEFAULT 'N',
add Event_priv enum('N','Y') CHARACTER SET utf8 NOT NULL DEFAULT 'N',
add Trigger_priv enum('N','Y') CHARACTER SET utf8 NOT NULL DEFAULT 'N';" | mysql -u root;

echo "INSERT INTO mysql.db SELECT * from "$cpuser"_mysql.db;" | mysql -u root;
else
echo "No 4.1 SQL Found"
fi

if [ "$sqlver" == "5.1" ];

then

echo "INSERT INTO mysql.db SELECT * from "$cpuser"_mysql.db;" | mysql -u root;
else
echo "No 5.1 SQL Found"

fi

if [ "$sqlver" == "5.7" ];

then

echo "INSERT INTO mysql.db SELECT * from "$cpuser"_mysql.db;" | mysql -u root;
else
echo "No 5.7 SQL Found"

fi

#Assign DBs to cpanel user

dbdbalter=($(grep $sqldump -Poe "CREATE DATABASE [^\`]*\`\K[^\`]*"))
for i in "${dbdbalter[@]}"; do /usr/local/cpanel/bin/dbmaptool $cpuser --type mysql --dbs $i; done

#Look for wpconfigs

wpconfig=($(find . -name wp-config.php -type f))

if [ -z $wpconfig ]; 

then echo "No WP Config, skipping section, migration completed"

else

#newwpuser=$cpuser"_"$wpuser
#newwpdb=$cpuser"_"$wpdb
#wpdb=($(find . -name "wp-config.php" -print0 | xargs -0 -r grep -e "DB_NAME" | cut -d \' -f 4))
#wpuser=($(find . -name "wp-config.php" -print0 | xargs -0 -r grep -e "DB_USER" | cut -d \' -f 4))

wpconfigchanges=($(find . -name wp-config.php))

for i in "${wpconfigchanges[@]}"; do
  wpdb=$(grep -e "DB_NAME" $i | cut -d \' -f 4)
  wpuser=$(grep -e "DB_USER" $i | cut -d \' -f 4)
  newwpuser=$cpuser"_"$wpuser
  newwpdb=$cpuser"_"$wpdb
  sed -i "/DB_USER/s/'$wpuser'/'$newwpuser'/" $i
  sed -i "/DB_NAME/s/'$wpdb'/'$newwpdb'/" $i

done


wpconfigs=($(find . -name "wp-config.php"))
for i in "${wpconfigs[@]}"; do 

cpuser=$cpuser
wpdb=$(grep -e "DB_NAME" $i | cut -d \' -f 4)
wpuser=$(grep -e "DB_USER" $i | cut -d \' -f 4)
wppass=$(grep -e "DB_PASS" $i | cut -d \' -f 4)

uapi --output=jsonpretty --user="$cpuser" Mysql create_user name="${wpuser}" password="${wppass}"; done

wpusers=($(find . -name "wp-config.php"))

for i in "${wpusers[@]}"; do 

cpuser=$cpuser
wpdb=$(grep -e "DB_NAME" $i | cut -d \' -f 4)
wpuser=$(grep -e "DB_USER" $i | cut -d \' -f 4)
wppass=$(grep -e "DB_PASS" $i | cut -d \' -f 4)

uapi --output=jsonpretty --user="$cpuser" Mysql set_privileges_on_database user="${wpuser}" database="${wpdb}" privileges="ALL PRIVILEGES"; done

fi

echo Migration completed!

# error report
