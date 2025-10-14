#!/bin/bash

# Obtains a list of all Satellite clients and looks at patches [RHSA, RHBA, RHEA] which have been sync'ed by Satellite
# into their respective channels but not applied to the clients.

# The same result is accomplished by using this 1-liner below with xargs
# spacecmd -u ${user} -p ${pass} system_list | tail -n +1 | xargs --verbose -I {} spacecmd -u ${user} -p ${pass} 

# Requires spacecmd which is not supported by RedHat or installed by default.
# https://fedorahosted.org/spacewalk/wiki/spacecmd

user="myfirmadmin"
pass="sssshhhhh"
tmpfile="/var/tmp/$$.patch"

spacecmd -u ${user} -p ${pass} system_list | tail -n +1 > $tmpfile
 while read server ; do
   echo $server
   spacecmd -u ${user} -p ${pass} system_listerrata $server 2>/dev/null
   echo ""
   echo ""
   echo ""
   echo "========================================================================================="
 done < $tmpfile

rm $tmpfile
