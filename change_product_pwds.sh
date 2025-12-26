#!/bin/bash
#|
#+===============================================================================================================================================
#|
#| File Name:
#| change_product_pwds.sh
#|
#| Description:
#| Changes all the product passwords (AR,AP,GL and so on) in a freshly installed eBS from the default passwords to a system generated one.
#| Can only be used to change product passwords, not SYSTEM or USER. Migth be an addon later on. The password length will be 12 characters
#|
#| Requirements:
#| eBS environment has to be set.
#|
#| Usage:
#| change_product_pwds
#|
#| Change History:
#|
#| 2025-10-02   0.1     Fredrik Lindkvist               Creation
#| 2025-12-23   0.2     Fredrik Lindkvist               Prompt for apps/system passwords instead of giving them as inparameters
#| 2025-12-26   0.3		Fredrik Lindkvist				Adding some housekeeping.
#+===============================================================================================================================================
#set -x

PROGRAM_VERSION=0.3

SCRIPT_DIR="$( pwd )"                           # Where should the script be located = $SCRIPT_DIR
DATE=$(date +"%Y-%m-%d_%H:%M:%S")               # Sysdate Variable
LOG_DIR=${SCRIPT_DIR}/log                       # Log directory
LOG_FILE="change_pwds_${DATE}.log"              # Log file Name
SQL_FILE=${SCRIPT_DIR}/users.sql                # SQL file definition
PRODUCT_NAMES_FILE=${SCRIPT_DIR}/products.txt   # List of all eBS Products
INFO_FILE=${SCRIPT_DIR}/information.log         # Logfile storing new passwords temporarly

# Need to cleanup variables from previous faulty exections
if [ "${SETNEWPWD}" == "YES"  ]; then
    unset SETNEWPWD
fi

if [ -z "$APPL_TOP" ]; then
    echo "eBS environment has not been sourced, please source the environment and run the program again : Terminating Program"
    return 1 2>/dev/null || exit 1
fi

# Display information to the user
echo "========================================="
echo "  Script Information"
echo "========================================="
echo ""
echo "Execution of this program will set 12 character long generated password for all eBS product users."
echo "A logfile named information.log displaying the new password will be created by the program."
echo "This logfile should preferebly be deleted after the passwords has been handled according to desired procedure."
echo ""
echo "Press ENTER to continue with execution..."
echo "========================================="

# Wait for user to press Enter
read -r

# Prompt user for APPS Password
read -s -p "Enter password for APPS User: " apps_password

# Set APPS User Credentials
APPS_USER=apps
apps_connection_string=${APPS_USER}/${apps_password}

# Removing the apps_password content, not needed anymore
unset apps_password

# Attempt to access the database as apps in order to test the apps_connection_string
sqlplus -S -L "${apps_connection_string}" << EOF > /dev/null 2>&1
        EXIT;
EOF

# Check exit status of connection attempt.
if [ $? -ne 0 ]; then
        sleep 1
        echo "Login as APPS was Unsuccessful : Terminating Program"
        return 1 2>/dev/null || exit 1
else
        sleep 1
        echo ""
        echo "Login as APPS was Successful : Proceeding"
fi

printf "\n"

# Prompt user for SYSTEM Password
read -s -p "Enter password for SYSTEM Database User: " system_password

# Set SYSTEM User Credentials
SYSTEM_USERNAME=system
system_connection_string="${SYSTEM_USERNAME}/${system_password}"

# Removing the system_password content, not needed anymore
unset system_password

# Attempt to access the database as system in order to test the system_connection_string
sqlplus -S -L "${system_connection_string}" << EOF > /dev/null 2>&1
        EXIT;
EOF

# Check exit status of connection attempt.
if [ $? -ne 0 ]; then
        sleep 1
        echo "Login as SYSTEM was Unsuccessful : Terminating Program"
        return 1 2>/dev/null || exit 1
else
        sleep 1
        echo ""
        echo "Login as SYSTEM was Successful : Proceeding"
fi

printf "\n"


while IFS= read -r username;
do
        username=$(echo "$username" | xargs)

        # Empty the old sql file.
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

        if [ "${RESULT}" == "${username}" ]; then

                # Attempt to access the database as ${username} using default password.
                echo ""

                # Setting inital product_connection string to have default eBS product password so we can test if the password has never been changed.
                product_connection_string=${username}/${username}

                echo "Attempting to access the database as ${username} using the intital default password."
                sqlplus -S -L "${product_connection_string}" << EOF > /dev/null 2>&1
                        EXIT;
EOF

                # Check exit status of connection attempt.
                if [ $? -ne 0 ]; then
                        echo ""
                        echo "Login as ${username} with default password was Unsuccessful. The password has already been changed, No further actions needed."
                        unset username
                        sleep 1
                else
                        echo ""
                        echo "Login as ${username} with default password was Successful. The password need to be changed : proceeding."
                        SETNEWPWD="YES"
                        sleep 1
                fi

        else
                echo ""
                echo "The user ${username} doesn't exist. No further actions needed"
                unset username
                sleep 1
        fi

        # If Password flag (SETNEWPWD) equals YES we should go ahead and change the password.
        if [ "${SETNEWPWD}" == "YES" ]; then

                # Call the password generator
                NEWPWD=$(${SCRIPT_DIR}/pwdgen ${username})
                echo ""
                echo "Now changing the password for ${username} "
                FNDCPASS ${apps_connection_string} 0 Y ${system_connection_string} ORACLE ${username} ${NEWPWD} > /dev/null 2>&1

                # Setting the product_connection_string to username and the new password
                product_connection_string=${username}/${NEWPWD}

                # Attempting to access the database as ${username} using the new password in order to confirm change of password was successful.
                sqlplus -S -L "${product_connection_string}" << EOF > /dev/null 2>&1
                        EXIT;
EOF
                unset product_connection_string

                # Check exit status of connection attempt.
                if [ $? -ne 0 ]; then

                        echo ""
                        echo "Login as ${username} with new password was Unsuccessful. The change of password failed : Terminating Program. Try to manage this user manually."
                        unset username
                        unset NEWPWD
                        unset RESULT
                        unset SETNEWPWD
                        sleep 1
                        return 1 2>/dev/null || exit 1


                else

                        echo ""
                        echo "Login as ${username} with new password was Successful."
                        # Storing the new credintials in a logfile that hopefully is keept on the server only for the amount of time it takes to manage the passwords according to company policy.
                        # Warning about this is printed when starting the program.
                        # Reminder: The passwords for an account can be regenerated by calling pwdgen standalone . pwdgen USERNAME as long as its on the same host with same TWO_TASK-
                        echo "Credentials for ${username} --> ${username} / ${NEWPWD}" >> ${INFO_FILE}
                        unset username
                        unset NEWPWD
                        unset RESULT
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
answer=$(echo "${answer}" | tr '[:lower:]' '[:upper:]')

if [ "${answer}" == "Y" ]; then
    echo "Deleting FNDCPASS log files..."

    # Delete .log files
    rm -f ${SCRIPT_DIR}/L*.log

    echo "Log Files deleted Successfully."
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
unset INFO_FILE

echo ""
echo "Script is finished"
