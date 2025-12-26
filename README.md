# Manage-eBS-Product-User-Passwords

The repository contains of 
pwdgen                         # Shellscript to generate passwords for different accounts, can be from 12 to 64 characters containing capital letters and digits 0-9
products.txt                   # Contains all the product users in eBS R12
change_product_pwds.sh         # Shellscript used to change the password for all eBS product accounts, calling pwdgen to create passwords.
set_default_product_pwds.sh    # Shell script resetting the password for all eBS product accounts to default if needed.

To run the script for eBS create a directory and place the files in the repo in the newly created directory. Source the eBS environment.
1. run change_product_pwds.sh to set new passwords for all ebs Products users.
2. run set_default_product_pwds.sh to set all the passwords back to default.

The script pwdgen can also be used standalone. $TWO_TASK needs to be set for the script to work. It can then be used just go as a simple password generator.
