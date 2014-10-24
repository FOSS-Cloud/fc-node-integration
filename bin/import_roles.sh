#!/bin/bash
#
# Copyright (C) 2006 - 2014 FOSS-Group
#                    Germany
#                    http://www.foss-group.de
#                    support@foss-group.de
#
# Authors:
# Beat Stebler <beat.stebler@foss-group.ch>
#  
# Licensed under the EUPL, Version 1.1 or higher as soon they
# will be approved by the European Commission - subsequent
# versions of the EUPL (the "Licence"); You may not use this
# work except in compliance with the Licence.
# 
# You may obtain a copy of the Licence at:
# https://joinup.ec.europa.eu/software/page/eupl
#
# Unless required by applicable law or agreed to in
# writing, software distributed under the Licence is
# distributed on an "AS IS" basis,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied.
# See the Licence for the specific language governing
# permissions and limitations under the Licence.
#
#
#
# Change the security to be able to run the script

sed -i -e 's/TLS_REQCERT demand/TLS_REQCERT never/' /etc/openldap/ldap.conf

# Ask user for LDAP Password
clear
echo ""
echo ""
echo "Please enter your ADMIN password of the LDAP"
echo ""
read -s -p "Password: " ldappasswd 
echo ""
echo ""

# Evaluating LDAP URI
rawldapuri="$(cat /etc/openldap/ldap.conf | grep 'URI.*ldaps:/')"
ldapuri=${rawldapuri:13:30}

# search nextfreeuid
rawNextFreeUID="$(ldapsearch -H "$ldapuri" -D "cn=Manager,dc=foss-cloud,dc=org" -w $ldappasswd -b "cn=nextfreeuid,ou=administration,dc=foss-cloud,dc=org" | grep uid:)"
if [ "$?" = "1" ]; then
    # set back security
    sed -i -e  's/TLS_REQCERT never/TLS_REQCERT demand/' /etc/openldap/ldap.conf
    clear
    echo ""
    echo "Wrong password. Try again to start the script!" 1>&2
    exit 1
fi

# Cat the UID out of the resultat of the search
NextFreeUID=${rawNextFreeUID:5:7}
echo "Actual NestFreeUID = $NextFreeUID"
echo ""

# Increase nextfreeuid + value
COUNTER=$[${NextFreeUID} + 3]
echo "New NextFreeUID = $COUNTER"
echo ""

# To load up the new nextfreeuuid into the LDAP, we need a tempfile to store the datas.
# Create tempfile
TEMPFILE=/tmp/$$.tmp
# Store new nextfreeuid in tempfile
echo  > $TEMPFILE
echo dn: cn=nextfreeuid,ou=administration,dc=foss-cloud,dc=org >> ${TEMPFILE}
echo changetype: modify >> ${TEMPFILE}
echo replace: uid >> ${TEMPFILE}
echo uid: ${COUNTER} >> ${TEMPFILE}

# Modify nextfreeuuid in LDAP
ldapmodify -v -H "$ldapuri" -D "cn=Manager,dc=foss-cloud,dc=org" -w $ldappasswd -f ${TEMPFILE}

# Delete TEMPFILE
unlink ${TEMPFILE}

# Find out what is the UID in the File
rawFileUID="$(grep uid: /etc/openldap/data/23_roles.ldif)"
FileUID=${rawFileUID:5:7}


# set appropriate uid in /etc/openldap/data/23_roles.ldiff
sed -i -e  's/'${FileUID}'/'${NextFreeUID}'/' /etc/openldap/data/23_roles.ldif
sed -i -e  's/'$[${FileUID} +1]'/'$[${NextFreeUID} + 1]'/' /etc/openldap/data/23_roles.ldif
sed -i -e  's/'$[${FileUID} +2]'/'$[${NextFreeUID} + 2]'/' /etc/openldap/data/23_roles.ldif

# Add the values into the LDAP
ldapadd -xv -H "$ldapuri" -D "cn=Manager,dc=foss-cloud,dc=org" -w $ldappasswd -f /etc/openldap/data/23_roles.ldif 

# set back security
sed -i -e  's/TLS_REQCERT never/TLS_REQCERT demand/' /etc/openldap/ldap.conf

# EOF