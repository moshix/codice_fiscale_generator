# Codice Fiscale Generator for Italian Tax Authority, in bash

This program fetches comuni online, but uses countries.json for the Belfiore codes. 

This script is made to run correctly on Macos, Linux, FreeBSd.

# Requirement commands
| Command  | Purpose                                                             |
| -------- | ------------------------------------------------------------------- |
| `bash`   | To execute the script (uses Bash syntax like arrays and functions). |
| `curl`   | To download JSON files for comuni and countries.                    |
| `jq`     | To parse and extract data from the downloaded JSON files.           |
| `tr`     | To transform input strings (case conversion, deletion).             |
| `cut`    | To split strings, used in `get_date_code`.                          |
| `read`   | Built-in Bash command for user input.                               |
| `printf` | For formatted output in the date code.                              |


# How to run
chmod +x CF_generator.bash
./CF_generator.bash
  
Then answer all the questions asked by the script. In the end it will output a correct codice fiscale. 
  
  
# License
GPLv3. copyright 2025 moshix  
all rights reserved.   

Moshix  
July 2025  
Milan
