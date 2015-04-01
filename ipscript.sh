#!/bin/bash
#
#The files for this script are put with the script so its not recommended to put this into a directory
#with a ton of misc files. Depending on your system your access log files may not be called access_log*.xz
#if thats the case the regex will most likely not work and would have to be adjusted accordingly.
#
#The script was used and made on: 
#Linux version 3.11.10-21-desktop (SUSE Linux)
#

INPUT=/tmp/menu.sh.$$
OUTPUT=/tmp/output.sh.$$
ACCPATH=/home
 
trap "rm $OUTPUT; rm $INPUT; exit" SIGHUP SIGINT SIGTERM
 
#to be called in other functions just for a little more visual appeal
function display_output(){
	local h=${1-10}			# box height default 10
	local w=${2-41} 		# box width default 41
	local t=${3-Output} 	# box title 
	dialog --backtitle "IP Address Converstion and Database Management" --title "${t}" --clear --msgbox "$(<$OUTPUT)" ${h} ${w}
}

#Takes the access log removes duplicates and pulls just the IP addresses
#Gets rid of 10. IP addresses and ::1 IP addresses that are sometimes in this log
function strip_access(){
	xz -d -c $ACCPATH/access_log-*.xz | awk '{print $1}'| grep -v '^10.' | sort -u | grep -v '::1' | uniq > geoip.raw

    display_output 6 60 "The Access Log has been stripped."
}

#Uses curl to run the geoip.tmp from strip_access through freeogeoip to
#pull lat/long and other information from the IP address for processing
function csv_ipAddresses(){
	echo "This could take a little while..."
	while read line
	do
    	name=$line
    	location=$(curl -s http://freegeoip.net/csv/$name)
    	echo $location >> latlongip.csv
    	echo -n .
	done < geoip.raw

	display_output 6 60 "Converted IP Addresses to CSV"
}

#Creates a database thats structured for this program
function create_database(){
	sqlite3 ipvisitors.sqlite < mkip-tables.sql3

    display_output 6 60 "Database has been created."
}

#Makes the file csv file easy to import into sqlite and fills the database
function stuff_database(){
	cat latlongip.csv | tr ',' '|' > latlongip.for_sqlite
	echo ".import latlongip.for_sqlite Visitors" | sqlite3 ipvisitors.sqlite

    display_output 6 60 "Database has been filled."
}

function to_xml(){
	echo "<markers>" > data.xml
	for g in $(echo 'select IP from Visitors;' | sqlite3 ipvisitors.sqlite)
	do
		for x in $(echo "select LATITUDE from Visitors WHERE IP = '${g}';" | sqlite3 ipvisitors.sqlite)
		do
		echo -n '''<marker lat="'$x'" ''' >> data.xml
			for y in $(echo "select LONGITUDE from Visitors WHERE IP = '${g}';" | sqlite3 ipvisitors.sqlite)
			do
			echo '''lng="'$y'"/>''' >> data.xml
			echo -n .
			break
			done
		done
	done
	
	echo "</markers>" >> data.xml
	display_output 6 60 "Convered to XML."
}

while true
do
 
### display main menu ###
dialog --clear  --help-button --backtitle "IP Address Converstion and Database Management" \
--title "[ M A I N - M E N U ]" \
--menu "Choose the TASK" 15 50 6 \
Strip_AccessLog "Strips the access log" \
IP_Convert "Uses GEOIP to convert IPs" \
Create_Database "Creates Database" \
Fill_Database "Enters data from IPs into sql" \
XML_Convert "Puts lat/long into XML file" \
Exit "Exit to the shell" 2>"${INPUT}"
 
menuitem=$(<"${INPUT}")
 
case $menuitem in
	Strip_AccessLog) strip_access;;
	IP_Convert) csv_ipAddresses;;
	Create_Database) create_database;;
	Fill_Database) stuff_database;;
	XML_Convert) to_xml;;
	Exit) echo "Cya space cowboy!"; break;;
esac
 
done

[ -f $OUTPUT ] && rm $OUTPUT
[ -f $INPUT ] && rm $INPUT
