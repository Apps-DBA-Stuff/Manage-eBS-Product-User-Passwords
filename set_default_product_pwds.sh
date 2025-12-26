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
#| 2025-12-26   0.2     Fredrik Lindkvist                         Adding housekeeping
#+======================================================================================================================================
#set -x

PROGRAM_VERSION=0.2

SCRIPT_DIR="$( pwd )"                           # Location of the script
DATE=$(date +"%Y-%m-%d_%H:%M:%S")               # Sysdate Variable
LOG_DIR=${SCRIPT_DIR}/log                       # Log directory
LOG_FILE="change_pwds_${DATE}.log"              # Log file Name
SQL_FILE=${SCRIPT_DIR}/users.sql                # SQL File definition
PRODUCT_NAMES_FILE=${SCRIPT_DIR}/products.txt   # List of all eBS Products

# Need to cleanup variables from previous faulty exections
if [ "${SETNEWPWD}" == "YES"  ]; then
    unset SETNEWPWD
fi

if [ -z "$APPL_TOP" ]; then
        echo "eBS environment has not been sourced, please source the environment and run the program again : Terminating Program"
        return 1 2>/dev/null || exit 1
fi

echo ""

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
        echo "Login as APPS was Unsucessful, Terminating Program"
        return 1 2>/dev/null || exit 1
else
        sleep 1
        echo ""
        echo "Login as APPS was Sucessful, Proceeding"
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
        echo "Login as SYSTEM was Unsucessfull, Terminating Program"
        return 1 2>/dev/null || exit 1
else
        sleep 1
        echo ""
        echo "Login as SYSTEM was Sucessful : Proceeding"
fi

printf "\n"

while IFS= read -r username;
do
        username=$(echo "$username" | xargs)

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
        echo "============================="
        echo "Now handling user ${username}"
        echo "============================="

        # We will set the default password for all users regardless of current password status.
        if [ "${RESULT}" == "${username}" ]; then

                NEWPWD=${username}
                echo ""
                echo "Username is ${username} and new password will be ${NEWPWD}"
                SETNEWPWD="YES"

        else

                echo ""
                echo "User ${username} doesn't exist, no action needed"
                unset username
                sleep 1

        fi

        # If Password flag (SETNEWPWD) equals YES we should go ahead and change to default password.
        if [ "${SETNEWPWD}" == "YES" ]; then

                echo ""
                echo "Now changing the password for ${username}."
                FNDCPASS ${apps_connection_string} 0 Y ${system_connection_string} ORACLE ${username} ${NEWPWD} > /dev/null 2>&1

                # Setting product_connection_string in order to test login
                product_connection_string=${username}/${NEWPWD}

                # Attempt to access the database as ${username} using default password.
                echo ""
                echo "Attempting to access the database as ${username} using the intital default password."
                sqlplus -S -L "${product_connection_string}" << EOF > /dev/null 2>&1
                        EXIT;
EOF

                unset product connection_string

                # Check exit status of connection attempt.
                if [ $? -ne 0 ]; then

                        echo ""
                        echo "Login as ${username} with default password was Unsuccessful. The change of password failed : Terminating Program"
                        unset username
                        unset NEWPWD
                        return 1 2>/dev/null || exit 1

                else

                        echo ""
                        echo "Login as ${username} with default password was Successful"
                        unset SETNEWPWD
                        sleep 1

                fi

        fi
sleep 1
done < "${PRODUCT_NAMES_FILE}"

echo ""
echo "===================================="
echo "Performing Housekeeping             "
echo "===================================="

# Prompt user with Y as default
read -p "Execution of FNDCPASS created log files. Delete Log Files? (Y/N) [Y]: " answer

# Set default to Y if user just presses Enter
answer=${answer:-Y}

# Convert to uppercase for comparison
answer=$(echo "$answer" | tr '[:lower:]' '[:upper:]')

if [ "$answer" = "Y" ]; then
    echo "Deleting FNDCPASS log files..."

    # Delete .log files
    rm -f ${SCRIPT_DIR}/L*.log

    echo "Log Files deleted successfully."
else
    echo "Log Files not deleted."
fi


# Unsetting variables containing passwords
unset apps_connection_string
unset system_connection_string

# Housekeeping.
# Many if the below has already been unset but lets just do it again though im to lazy :) to search every row once again. Doesnt hurt to have the unset twice.
# Just dont fancy to leave trash variables behind.
unset NEWPWD
unset product_connection_string
unset username
unset SETNEWPWD
unset answer
unset DATE
unset LOG_DIR
unset LOG_FILE
unset SQL_FILE
unset PRODUCT_NAMES_FILE

echo ""
echo "Script is finished"
