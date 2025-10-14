#!/bin/bash

trap 'my_exit; exit' SIGINT SIGQUIT SIGTERM

scannedhosts="/var/tmp/scannedhosts"
hoststats="/var/tmp/hostinfo"
dontscan=0
scansubnet="192.168.42.0/24"

my_exit()
{
        echo " You hit Ctrl-C/Ctrl-\, aborting now."
        # cleanup commands here if any
        /bin/rm -f $scannedhosts
}

usage()
{
        echo ""
        echo " Script runs on Linux, scans a subnet, looks for hosts which are alive, extracts hardware info."
        echo ""
        echo " -f <filename>    - reads a file of hosts, ssh into systems, outputs hardware specs, instead of running a nmap scan and then doing the same."
        echo ""
}

while getopts "f:s:h" options; do
	case "${options}" in
       		f) scannedhosts=$OPTARG ; dontscan=1
		   ;;
	        h) usage
	           exit 0
                   ;;
	esac
done
shift $((OPTIND-1))

# Scan a default /24 subnet by default unless told not to
if [[ $dontscan -eq 0 ]]; then
	echo "Scanning subnet $scansubnet now..."
	nmap $scansubnet | grep 'Nmap scan report' | sed 's/Nmap scan report for //' > $scannedhosts
fi

# A dropped packet == potential data loss == potential lost revenue, so want to highlight it for later investigation.
# lsb_release == Installed on Debian|Ubuntu

for host in `cat $scannedhosts`; do
		if [[ $(ping -q -w 3 -c 3 $host) == @(* 0% packet loss*) ]]; then
			echo $host is alive
				echo "" >> $hoststats
				echo "Hostname is : $host" >> $hoststats
				ssh -o ConnectTimeout=10 $host "hostname ; cat /etc/redhat-release ; lsb_release -a ; dmidecode | egrep '(Manufacturer: |Product Name: )' ; lscpu ; uname -r ; parted -l | egrep '^Model: |^Disk ' ; free -m ; lshw -c network ; ip -s link" >> $hoststats
					if [[ $? -ne 0 ]]; then
						echo " SSH Error with $host - please investigate."
					fi
		else
			echo $host is down or has packet loss, please investigate.
		fi
done

/bin/rm -f $scannedhosts
