#!/bin/bash

echo -n "ID: "
read userid
sudo htpasswd -m /etc/apache2/.svnpasswd $userid
