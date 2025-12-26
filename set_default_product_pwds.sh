#!/bin/bash
#|
#+====================================================================================================================================
#|
#| File Name:
#| set_default_product_pwds.sh
#|
#| Description:
#| Changes all the product passwords (AR,AP,GL and so on) in eBS instance to the default ones.
#| Can only be used to change product passwords, not SYSTEM or USER. Migth be an addon later on.
#|
#| Usage:
#| ./set_default_product_pwds.sh
#|
#| Change History:
#|
#| 2025-10-02   0.1     Fredrik Lindkvist                         Creation
#+======================================================================================================================================
#set -x

PROGRAM_VERSION=0.1

SCRIPT_DIR="$( pwd )"                           # Location of the script
DATE=$(date +"%Y-%m-%d_%H:%M:%S")               # Sysdate Variable
LOG_DIR=${SCRIPT_DIR}/log                       # Log directory
LOG_FILE="change_pwds_${DATE}.log"              # Log file Name
USERNAME_FILE=${SCRIPT_DIR}/products.txt        # contains all products in eBS


if [ -z "$APPL_TOP" ]; then
    echo "EBSapps.env has not been sourced, please source the environment before using this script : Terminating Program"
    return 1 2>/dev/null || exit 1
fi


# Prompt user for APPS Password
read -s -p "Enter password for APPS User: " apps_password

# Set APPS User Credentials
APPS_USER=apps
apps_connection_string=${APPS_USER}/${apps_password}

# Removing the apps_password content, not needed anymore
unset apps_password

# Attempt to access the database in order to test the connection string
sqlplus -S -L "${apps_connection_string}" << EOF > /dev/null 2>&1
        EXIT;
EOF

# Check exit status of connection attempt.
if [ $? -ne 0 ]; then
        sleep 1
        echo "APPS Password is incorrect, Terminating The Program"
        return 1 2>/dev/null || exit 1
else
        sleep 1
        echo ""
        echo "Login as APPS was sucessful."
fi

printf "\n"

# Prompt user for SYSTEM Password
read -s -p "Enter password for SYSTEM Database User: " system_password

# Set SYSTEM User Credentials
SYSTEM_USERNAME=system
system_connection_string="${SYSTEM_USERNAME}/${system_password}"

# Removing the system_password content, not needed anymore
unset system_password

# Attempt to access the database in order to test the connection string
sqlplus -S -L "${system_connection_string}" << EOF > /dev/null 2>&1
        EXIT;
EOF

# Check exit status of connection attempt.
if [ $? -ne 0 ]; then
        sleep 1
        echo ""
        echo "SYSTEM Password is incorrect : Terminating The Program"
        return 1 2>/dev/null || exit 1
else
        sleep 1
        echo ""
        echo "Login as SYSTEM was sucessful."
fi

printf "\n"

while IFS= read -r username;
do
                username=$(echo "$username" | xargs)

                SQL_FILE=${SCRIPT_DIR}/users.sql
                # Empty the old sql file. - Should change this to check if the file already exists so do not have to rebuild every loop.
                > $SQL_FILE

                # Build the sqlfile
                echo "set linesize 100" > $SQL_FILE
                echo "set pagesize 2" >> $SQL_FILE
                echo "set verify off" >> $SQL_FILE
                echo "set heading off" >> $SQL_FILE
                echo "define user = '${username}'" >> $SQL_FILE
                echo "select username from dba_users where username = '&user' and username not in ('APPS','APPS_NE','APPLSYS','APPLSYSPUB','ODM','ODM_MTR','AD_MONITOR','EBS_SYSTEM','EM_MONITOR','MGDSYS','SCOTT','SSOSDK','C##USER');" >> $SQL_FILE
                echo "exit;" >> $SQL_FILE

                RESULT=$(sqlplus -s "${apps_connection_string}" @${SQL_FILE} 2>/dev/null)

                # Clean up the result (remove whitespace and newlines)
                RESULT=$(echo "$RESULT" | tr -d '[:space:]')

                # Inform on STDOUT what user is being handled
                echo ""
                echo "===================================="
                echo "Now handling user ${username}"
                echo "===================================="

                if [ "${RESULT}" == "${username}" ]; then

                        NEWPWD=${username}
                        echo "USERNAME IS ${username} AND NEW PASSWORD WILL BE ${NEWPWD}"

                        # Setting connection string in order to test login.
                        product_connection_string=${username}/${NEWPWD}

                        # Changing the password
                        echo ""
                        echo "Now changing the password for user ${username}"
                        FNDCPASS ${apps_connection_string} 0 Y ${system_connection_string} ORACLE ${username} ${NEWPWD} > /dev/null 2>&1

                        echo ""
                        echo "Attempting to access the database as user ${username} with the default product password."
                        sqlplus -S -L "${product_connection_string}" << EOF > /dev/null 2>&1
                                EXIT;
EOF

                        # Check exit status of connection attempt.
                        if [ $? -ne 0 ]; then
                                echo ""
                                echo "Login as ${username} with New Password was Unsucessful."
                                return 1 2>/dev/null || exit 1
                        else
                                echo ""
                                echo "Login as ${username} with New Password was Sucessful."
                                sleep 1
                        fi
                        unset NEWPWD
                        unset product_connection_string
                        unset username
                else

                        echo "User ${username} doesn't exist, no action needed"
                        unset username
                fi

sleep 1
done < "$USERNAME_FILE"

# Unsetting variables containing passwords
unset system_connection_string
unset apps_connection_string

echo ""
echo "Script is finished"

