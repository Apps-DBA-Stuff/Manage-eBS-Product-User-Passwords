## Manage eBS Product User Password

## Summary:
When Oracle E-Business Suite is installed, all product schema passwords default to matching their usernames (e.g., GL/GL, AR/AR). This poses a security risk, especially in production environments, and should be changed immediately after installation.
Oracle provides two tools for password management: the legacy FNDCPASS command and the newer AFPASSWD command. Both can perform mass password updates, but they set the same password for all product users, which may violate security policies and is not recommended for production use. While AFPASSWD can run from either the middle tier or database tier, it has only been tested from the middle tier.
Manually changing passwords for each product schema individually is time-consuming and tedious. To address this challenge, these scripts automate the mass password update process while generating unique, secure 12-character passwords for each product user. This approach combines the efficiency of automation with proper security practices by ensuring every schema has a different password.

## Overview

Written for Linux (only tested on OEL8)

The toolkit includes the below files scripts:

1. pwdgen                         # Shellscript to generate passwords for different accounts, can be from 12 to 64 characters containing capital letters and digits 0-9
2. products.txt                   # Contains all the product users in eBS R12
3. change_product_pwds.sh         # Shellscript used to change the password for all eBS product accounts, calling pwdgen to create passwords.
4. set_default_product_pwds.sh    # Shell script resetting the password for all eBS product accounts to default if needed.


To  create a directory and place the files in the repo in the newly created directory. Source the eBS environment.
1. run change_product_pwds.sh to set new passwords for all ebs Products users.
2. run set_default_product_pwds.sh to set all the passwords back to defa ult.

The script pwdgen can also be used standalone. $TWO_TASK needs to be set for the script to work. It can then be used just go as a simple password generator.
## Installation

- Create a directory for the scripts in the location of choice.
- Place the files in the created directory.
- Make the scripts executable:

chmod +x pwdgen
chmod +x change_product_pwds.sh
chmod +x set_default_product_pwds.sh


## Usage

### Generate Random Passwords

-- While designed for EBS, the pwdgen script can be used standalone to generate random passwords between 12 and 64 characters for any installation (default 12 characters). For standalone use, simply set the $TWO_TASK environment variable to any value before running.

./pwdgen [LENGTH : 12 DEFAULT] USERNAME


### Change All Product Passwords to Random Values

./change_product_pwds.sh

This script will:
- Use `pwdgen` to generate random passwords
- Apply them to all Oracle EBS product schemas (GL, AR, AP, PO, INV, etc.)
- Producing a logfile with information.

### Reset All Product Passwords to Defaults
-- See to that tbe eBS Environment has been sourced before using.
./set_default_product_pwds.sh

This script will: 
- Restore the original default passwords for all product schemas.

## Security Notes

- Always store generated passwords securely
- Consider your organization's password policies before using these scripts
- Test in a non-production environment first

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome!

## Disclaimer

These scripts are provided as-is. All material is offered for free and in good faith but not guaranteed to be correct, up to date or suitable for any particular situation or purpose. 
Always test in a development environment before using in production. Ensure you have proper backups and follow your organization's change management procedures.
No liability is accepted in respect of the material and informatoin or its use.

These scripts were created on Linux 8 and have only been tested on that version. Compatibility with other Linux distributions or versions is not guaranteed.
