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

packs=(
		"subversion"
		"apache2"
		"libapache2-svn"
		"apache2-utils"
		"libapache2-mod-python"
		"python-setuptools"
		"python-dev"
		"python-genshi"
		"trac"
		"mysql-server"
		"python-mysqldb"
	)

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

dav_svn_conf=(
		"2 i\\</Location>"
		"2 i\\allow from all"
		"2 i\\Order allow,deny"
		"2 i\\Require valid-user"
		"2 i\\AuthUserFile /etc/apache2/.svnpasswd"
		"2 i\\AuthName \"SVN Web\""
		"2 i\\AuthType Basic"
		"2 i\\SVNListParentPath on"
		"2 i\\SVNParentPath /usr/src/svn"
		"2 i\\DAV svn"
		"2 i\\<Location /svn>"
	)

trac_conf=(
		"<Location /trac>"
		"SetHandler mod_python"
		"PythonHandler trac.web.modpython_frontend"
		"PythonOption TracEnvParentDir /usr/src/trac"
		"PythonOption TracUriRoot /trac"
		"AuthType Basic"
		"AuthName \"Trac repository\""
		"AuthUserFile /etc/apache2/.svnpasswd"
		"Require valid-user"
		"Order allow,deny"
		"allow from all"
		"</Location>"
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



###  INSTALL PACKAGES  ###

apt-get install -y -f
for(( i=0; i<${#packs[@]}; i++ )); do
	apt-get install -y ${packs[$i]}
done



###  DB SETTING  ###

touch temp_sql.txt
echo "CREATE DATABASE ${name_repository} DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;" > temp_sql.txt
echo "GRANT ALL ON ${name_repository}.* TO ${user_id}@localhost IDENTIFIED BY '${user_pw}';" >> temp_sql.txt

mysql -u root -p < temp_sql.txt
rm -rf temp_sql.txt
echo -e "\033[7;33m"DB Setting complete"\033[0m"



###  CREATE DIRECTORIES AND FILES  ###

mkdir -p /usr/src/svn/
svnadmin create /usr/src/svn/${name_repository}

mkdir /usr/src/trac
mkdir /usr/src/trac/${name_repository}

echo -e "\033[7;33m"trac DB Setting"\033[0m"
touch temp_input.txt
echo "${name_repository}" > temp_input.txt
echo "mysql://${user_id}:${user_pw}@localhost/${name_repository}" >> temp_input.txt

trac-admin /usr/src/trac/${name_repository} initenv < temp_input.txt
rm -rf temp_input.txt

touch /etc/apache2/sites-available/trac.conf
touch /etc/apache2/mods-enabled/dav_svn.conf

cd /usr/src/svn/${name_repository}/hooks/
cp post-commit.tmpl post-commit
cp post-revprop-change.tmpl post-revprop-change



###  CHANGE OWNER AND RIGHTS  ###

chown -R www-data:www-data /usr/src/svn
chown -R www-data:www-data /usr/src/trac

chmod 755 /usr/src/svn/${name_repository}/hooks/post-commit
chmod 755 /usr/src/svn/${name_repository}/hooks/post-revprop-change
chmod 644 /usr/src/trac/${name_repository}/conf/trac.ini
chmod 644 /etc/apache2/sites-available/trac.conf



###  Configurations  ###

cd ${aPath[0]}
for value in "${svn_conf[@]}"; do
	sed -i "$value" ${aFile[0]}
done

cd ${aPath[1]}
for value in "${dav_svn_conf[@]}"; do
	sed -i "$value" ${aFile[1]}
done

cd ${aPath[2]}
for value in "${trac_conf[@]}"; do
	echo "$value" >> ${aFile[2]}
done

cd ${aPath[3]}
for value in "${trac_ini[@]}"; do
	sed -i "$value" ${aFile[3]}
done

########################################
#for value in "${trac_ini[@]}"; do
#    echo "$value" >> ${aFile[3]}
#done

#for value in "${trac_ini[@]}"; do
#    sed -i "$value" txt
#done
########################################

# post-commit file
cd ${aPath[4]}
find -iname 'post-commit' -exec sed -i 's/"$REPOS"/# "$REPOS"/g' {} \;
find -iname 'post-commit' -exec sed -i '2 i\export PYTHON_EGG_CACHE="/path/to/cache/dir"' {} \;
find -iname 'post-commit' -exec sed -i '3 i\/usr/bin/trac-admin /usr/src/trac/${name_reposiroty} changeset added "$1" "$2"' {} \;

# post-revprop-change file
find -iname 'post-revprop-change' -exec sed -i 's/"$REPOS"/# "$REPOS"/g' {} \;
find -iname 'post-revprop-change' -exec sed -i 's/  "$USER"/# "$USER"/g' {} \;
find -iname 'post-revprop-change' -exec sed -i '2 i\export PYTHON_EGG_CACHE="/path/to/cache/dir"' {} \;
find -iname 'post-revprop-change' -exec sed -i '3 i\/usr/bin/trac-admin /usr/src/trac/${name_repository} changeset modified "$1" "$2"' {} \;



###  ACTIVATE  ###

find /etc -iname 'rc.local' -exec sed -i '2 i\svnserve -d -r /usr/src/svn' {} \;
a2ensite trac
service apache2 reload



###  ETC  ###

# Add user ID
touch temp_login.txt
echo "$user_pw" > temp_login.txt
echo "$user_pw" >> temp_login.txt

echo -e "\033[7;33m"User Add..."\033[0m"
htpasswd -c /etc/apache2/.svnpasswd $user_id < temp_login.txt
rm -rf temp_login.txt

# Copy others

cd $saved_path
cp data/add_repository.sh .
cp data/usr_add.sh .


# Install complete message

echo -e "\033[7;33m"INSTALLATION COMPLETE..."\033[0m"
echo -n "You can connect to the SVN with \""
echo "`hostname -I`/svn\""
echo -n "and also can connect to the TRAC with \""
echo "`hostname -I`/trac\""
echo "Enjoy :)"

# Delete itself

rm -rf ./data
rm -rf ./SVN_TRAC_INSTALL.sh
rm -rf ./usr_add_first.sh
