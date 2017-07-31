#!/bin/bash
saved_path=$(pwd)

###  GET USER INPUT  ###

echo -n "SVN) Repository name? "
read name_repository

echo -n "SVN) User ID to create? "
read user_id

echo -n "SVN) Password for $user_id? "
read user_pw



###  VARIABLES  ###

aPath=(
		"/usr/src/svn/$name_repository/conf"
		"/etc/apache2/mods-enabled"
		"/etc/apache2/sites-available"
		"/usr/src/trac/$name_repository/conf"
		"/usr/src/svn/$name_repository/hooks"
	)

aFile=(
		"svnserve.conf"
		"dav_svn.conf"
		"trac.conf"
		"trac.ini"
		"post-commit"
		"post-revprop-change"
	)

svn_conf=(
		"s/# anon-access/ anon-access/g"
		"s/# auth-access/ auth-access/g"
		"s/# password-db/ password-db/g"
		"s/# authz-db/ authz-db/g"
		"s/# realm/ realm/g"
	)

trac_ini=(
		"s/repository_sync_per_request = (default)/repository_sync_per_request = /g"
		"2 i\\${name_repository}.type=svn"
		"2 i\\${name_repository}.dir=/usr/src/svn/${name_repository}"
		"2 i\\.alias=${name_repository}"
		"2 i\\[repositories]"
		"2 i\\ "
		"2 i\\tracopt.ticket.commit_updater.*=enabled"
		"2 i\\tracopt.versioncotrol.svn.*=enabled"
		"2 i\\[components]"
	)



###  DB SETTING  ###
touch temp_sql.txt
echo "CREATE DATABASE ${name_repository} DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;" > temp_sql.txt
echo "GRANT ALL ON ${name_repository}.* TO $user_id@localhost IDENTIFIED BY '$user_pw';" >> temp_sql.txt

echo -e "\033[7;33m"@ INPUT DB ADMIN PASSWORD"\033[0m"
mysql -u root -p < temp_sql.txt
rm -rf temp_sql.txt

echo "DB SETTING COMPLETE..."



###  CREATE DIRECTORIES AND FILES  ###

svnadmin create /usr/src/svn/${name_repository}

mkdir /usr/src/trac/${name_repository}

touch temp_input.txt
echo "${name_repository}" > temp_input.txt
echo "mysql://$user_id:$user_pw@localhost/${name_repository}" >> temp_input.txt

trac-admin /usr/src/trac/${name_repository} initenv < temp_input.txt
rm -rf temp_input.txt

cd /usr/src/svn/${name_repository}/hooks/
cp post-commit.tmpl post-commit
cp post-revprop-change.tmpl post-revprop-change



###  CHANGE OWNER AND RIGHTS  ###

chown -R www-data:www-data /usr/src/svn
chown -R www-data:www-data /usr/src/trac

chmod 755 /usr/src/svn/${name_repository}/hooks/post-commit
chmod 755 /usr/src/svn/${name_repository}/hooks/post-revprop-change
chmod 644 /usr/src/trac/${name_repository}/conf/trac.ini



###  Configurations  ###

cd ${aPath[0]}
for value in "${svn_conf[@]}"; do
	sed -i "$value" ${aFile[0]}
done

cd ${aPath[3]}
for value in "${trac_ini[@]}"; do
	sed -i "$value" ${aFile[3]}
done



# post-commit file
cd ${aPath[4]}
find -iname 'post-commit' -exec sed -i 's/"$REPOS"/# "$REPOS"/g' {} \;
find -iname 'post-commit' -exec sed -i '2 i\export PYTHON_EGG_CACHE="/path/to/cache/dir"' {} \;
find -iname 'post-commit' -exec sed -i '3 i\/usr/bin/trac-admin /usr/src/trac/${name_repository} changeset added "$1" "$2"' {} \;

# post-revprop-change file
find -iname 'post-revprop-change' -exec sed -i 's/"$REPOS"/# "$REPOS"/g' {} \;
find -iname 'post-revprop-change' -exec sed -i 's/  "$USER"/# "$USER"/g' {} \;
find -iname 'post-revprop-change' -exec sed -i '2 i\export PYTHON_EGG_CACHE="/path/to/cache/dir"' {} \;
find -iname 'post-revprop-change' -exec sed -i '3 i\/usr/bin/trac-admin /usr/src/trac/${name_repository} changeset modified "$1" "$2"' {} \;



###  ACTIVATE  ###

service apache2 reload



###  ETC  ###

# Add user ID
touch temp_login.txt
echo "$user_pw" > temp_login.txt
echo "$user_pw" >> temp_login.txt

echo -e "\033[7;33m"INPUT USER ${user_id}\'s PASSWORD"\033[0m"
htpasswd -m /etc/apache2/.svnpasswd $user_id < temp_login.txt	# TODO doesn't work
rm -rf temp_login.txt


# Copy others
cd $saved_path


# Install complete message
server_ip=$(hostname -I)
echo -e "\033[7;33m"INSTALLATION COMPLETE..."\033[0m"
echo -n "You can connect to the SVN with \""
echo "$server_ip/svn\""
echo -n "and also can connect to the TRAC with \""
echo "$server_ip/trac\""
echo "Enjoy :)"
