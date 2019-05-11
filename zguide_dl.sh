#!/bin/bash

#      Copyright (C) 2017-2019 Jan-Luca Neumann
#      https://github.com/sunsettrack4/zattoo_tvh/
#
#  This Program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3, or (at your option)
#  any later version.
#
#  This Program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with zattoo_tvh. If not, see <http://www.gnu.org/licenses/>.

# ######################
# DOWNLOAD EPG DETAILS #
# ######################

cd ~/ztvh/work

rm ~/ztvh/epg/datafile* 2> /dev/null
rm ~/ztvh/epg/filecheck* 2> /dev/null

session=$(<~/ztvh/user/session)
powerid=$(<powerid)
provider=$(sed "2,5d;s/provider=//g" ~/ztvh/user/userfile)

if date '+%H%M' | grep -q "235[0-9]"
then
	echo "" && echo "Waiting until EPG services are available..."
	sleep 600s
fi

echo "" && echo "Checking EPG manifest files..."


# ################
# DOWNLOAD DAY 1 #
# ################

if grep -q -E "epgdata [1-9]-|epgdata 1[0-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_1
	until tr ' ' '\n' < ~/ztvh/epg/datafile_1  | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)

		date -d '1 day' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)

		date -d '1 day' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_1 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_1 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_1 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_1 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_1 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_1 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_1 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_1 2> /dev/null
		fi
		rm date*
	
		if tr ' ' '\n' < ~/ztvh/epg/datafile_1 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 1 - $(date '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_1 >> ~/ztvh/epg/datafile
		echo "DAY 1 - $(date '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 1 - $(date '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_1 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date +%Y%m%d)_manifest_new) <(sort -u ~/ztvh/epg/$(date +%Y%m%d)_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_01\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date +%Y%m%d)_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date +%Y%m%d)_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_01\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_1
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date +%Y%m%d) finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_1
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date +%Y%m%d) finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date +%Y%m%d) finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_1
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_1
			echo "$(date +%Y%m%d) finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 1 - $(date '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_1 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_1 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_01\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_1
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date +%Y%m%d) finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# ################
# DOWNLOAD DAY 2 #
# ################

if grep -q -E "epgdata [2-9]-|epgdata 1[0-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '1 day' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_2
	until tr ' ' '\n' < ~/ztvh/epg/datafile_2 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '1 day' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '1 day' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '1 day' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '2 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '2 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_2 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_2 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_2 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_2 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_2 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_2 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_2 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_2 2> /dev/null
		fi
		rm date*
	
		if tr ' ' '\n' < ~/ztvh/epg/datafile_2 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 2 - $(date -d '1 day' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_2 >> ~/ztvh/epg/datafile
		echo "DAY 2 - $(date -d '1 day' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '1 day' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 2 - $(date -d '1 day' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '1 day' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '1 day' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_2 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '1 day' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '1 day' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '1 day' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '1 day' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_02\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '1 day' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '1 day' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_02\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_2
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '1 day' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_2
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '1 day' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '1 day' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_2
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_2
			echo "$(date -d '1 day' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 2 - $(date -d '1 day' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_2 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '1 day' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '1 day' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_2 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_02\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_2
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '1 day' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# ################
# DOWNLOAD DAY 3 #
# ################

if grep -q -E "epgdata [3-9]-|epgdata 1[0-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '2 days' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_3
	until tr ' ' '\n' < ~/ztvh/epg/datafile_3 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '2 days' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '2 days' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '2 days' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '3 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '3 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_3 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_3 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_3 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_3 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_3 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_3 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_3 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_3 2> /dev/null
		fi
		rm date*
		
		if tr ' ' '\n' < ~/ztvh/epg/datafile_3 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 3 - $(date -d '2 days' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_3 >> ~/ztvh/epg/datafile
		echo "DAY 3 - $(date -d '2 days' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '2 days' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 3 - $(date -d '2 days' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '2 days' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '2 days' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_3 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '2 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '2 days' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '2 days' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '2 days' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_03\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '2 days' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '2 days' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_03\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_3
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '2 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_3
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '2 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '2 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_3
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_3
			echo "$(date -d '2 days' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 3 - $(date -d '2 days' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_3 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '2 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '2 days' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_3 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_03\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_3
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '2 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# ################
# DOWNLOAD DAY 4 #
# ################

if grep -q -E "epgdata [4-9]-|epgdata 1[0-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '3 days' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_4
	until tr ' ' '\n' < ~/ztvh/epg/datafile_4 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '3 days' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '3 days' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '3 days' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '4 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '4 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_4 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_4 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_4 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_4 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_4 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_4 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_4 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_4 2> /dev/null
		fi
		rm date*
		
		if tr ' ' '\n' < ~/ztvh/epg/datafile_4 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 4 - $(date -d '3 days' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_4 >> ~/ztvh/epg/datafile
		echo "DAY 4 - $(date -d '3 days' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '3 days' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 4 - $(date -d '3 days' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '3 days' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '3 days' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_4 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '3 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '3 days' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '3 days' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '3 days' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_04\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '3 days' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '3 days' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_04\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_4
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '3 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_4
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '3 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '3 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_4
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_4
			echo "$(date -d '3 days' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 4 - $(date -d '3 days' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_4 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '3 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '3 days' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_4 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_04\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_4
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '3 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# ################
# DOWNLOAD DAY 5 #
# ################

if grep -q -E "epgdata [5-9]-|epgdata 1[0-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '4 days' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_5
	until tr ' ' '\n' < ~/ztvh/epg/datafile_5 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '4 days' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '4 days' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '4 days' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '5 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '5 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_5 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_5 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_5 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_5 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_5 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_5 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_5 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_5 2> /dev/null
		fi
		rm date*
		
		if tr ' ' '\n' < ~/ztvh/epg/datafile_5 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 5 - $(date -d '4 days' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_5 >> ~/ztvh/epg/datafile
		echo "DAY 5 - $(date -d '4 days' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '4 days' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 5 - $(date -d '4 days' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '4 days' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '4 days' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_5 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '4 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '4 days' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '4 days' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '4 days' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_05\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '4 days' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '4 days' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_05\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_5
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '4 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_5
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '4 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '4 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_5
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_5
			echo "$(date -d '4 days' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 5 - $(date -d '4 days' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_5 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '4 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '4 days' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_5 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_05\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_5
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '4 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# ################
# DOWNLOAD DAY 6 #
# ################

if grep -q -E "epgdata [6-9]-|epgdata 1[0-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '5 days' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_6
	until tr ' ' '\n' < ~/ztvh/epg/datafile_6 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '5 days' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '5 days' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '5 days' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '6 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '6 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_6 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_6 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_6 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_6 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_6 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_6 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_6 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_6 2> /dev/null
		fi
		rm date*
		
		if tr ' ' '\n' < ~/ztvh/epg/datafile_6 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 6 - $(date -d '5 days' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_6 >> ~/ztvh/epg/datafile
		echo "DAY 6 - $(date -d '5 days' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '5 days' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 6 - $(date -d '5 days' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '5 days' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '5 days' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_6 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '5 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '5 days' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '5 days' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '5 days' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_06\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '5 days' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '5 days' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_06\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_6
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '5 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_6
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '5 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '5 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_6
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_6
			echo "$(date -d '5 days' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 6 - $(date -d '5 days' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_6 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '5 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '5 days' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_6 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_06\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_6
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '5 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# ################
# DOWNLOAD DAY 7 #
# ################

if grep -q -E "epgdata [7-9]-|epgdata 1[0-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '6 days' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_7
	until tr ' ' '\n' < ~/ztvh/epg/datafile_7 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '6 days' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '6 days' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '6 days' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '7 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '7 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_7 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_7 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_7 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_7 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_7 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_7 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_7 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_7 2> /dev/null
		fi
		rm date*
		
		if tr ' ' '\n' < ~/ztvh/epg/datafile_7 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 7 - $(date -d '6 days' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_7 >> ~/ztvh/epg/datafile
		echo "DAY 7 - $(date -d '6 days' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '6 days' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 7 - $(date -d '6 days' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '6 days' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '6 days' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_7 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '6 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '6 days' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '6 days' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '6 days' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_07\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '6 days' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '6 days' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_07\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_7
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '6 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_7
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '6 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '6 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_7
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_7
			echo "$(date -d '6 days' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 7 - $(date -d '6 days' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_7 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '6 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '6 days' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_7 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_07\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_7
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '6 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# ################
# DOWNLOAD DAY 8 #
# ################

if grep -q -E "epgdata [8-9]-|epgdata 1[0-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '7 days' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_8
	until tr ' ' '\n' < ~/ztvh/epg/datafile_8 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '7 days' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '7 days' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '7 days' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '8 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '8 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_8 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_8 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_8 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_8 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_8 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_8 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_8 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_8 2> /dev/null
		fi
		rm date*
		
		if tr ' ' '\n' < ~/ztvh/epg/datafile_8 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 8 - $(date -d '7 days' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_8 >> ~/ztvh/epg/datafile
		echo "DAY 8 - $(date -d '7 days' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '7 days' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 8 - $(date -d '7 days' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '7 days' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '7 days' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_8 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '7 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '7 days' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '7 days' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '7 days' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_08\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '7 days' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '7 days' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_08\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_8
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '7 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_8
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '7 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '7 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_8
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_8
			echo "$(date -d '7 days' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 8 - $(date -d '7 days' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_8 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '7 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '7 days' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_8 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_08\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_8
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '7 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# ################
# DOWNLOAD DAY 9 #
# ################

if grep -q -E "epgdata 9-|epgdata 1[0-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '8 days' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_9
	until tr ' ' '\n' < ~/ztvh/epg/datafile_9 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '8 days' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '8 days' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '8 days' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '9 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '9 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_9 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_9 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_9 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_9 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_9 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_9 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_9 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_9 2> /dev/null
		fi
		rm date*
		
		if tr ' ' '\n' < ~/ztvh/epg/datafile_9 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 9 - $(date -d '8 days' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_9 >> ~/ztvh/epg/datafile
		echo "DAY 9 - $(date -d '8 days' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '8 days' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 9 - $(date -d '8 days' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '8 days' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '8 days' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_9 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '8 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '8 days' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '8 days' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '8 days' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_09\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '8 days' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '8 days' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_09\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_9
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '8 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_9
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '8 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '8 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_9
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_9
			echo "$(date -d '8 days' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 9 - $(date -d '8 days' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_9 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '8 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '8 days' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_9 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_09\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_9
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '8 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# #################
# DOWNLOAD DAY 10 #
# #################

if grep -q "epgdata 1[0-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '9 days' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_10
	until tr ' ' '\n' < ~/ztvh/epg/datafile_10 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '9 days' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '9 days' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '9 days' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '10 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '10 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_10 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_10 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_10 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_10 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_10 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_10 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_10 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_10 2> /dev/null
		fi
		rm date*
		
		if tr ' ' '\n' < ~/ztvh/epg/datafile_10 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 10 - $(date -d '9 days' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_10 >> ~/ztvh/epg/datafile
		echo "DAY 10 - $(date -d '9 days' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '9 days' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 10 - $(date -d '9 days' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '9 days' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '9 days' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_10 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '9 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '9 days' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '9 days' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '9 days' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_10\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '9 days' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '9 days' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_10\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_10
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '9 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_10
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '9 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '9 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_10
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_10
			echo "$(date -d '9 days' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 10 - $(date -d '9 days' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_10 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '9 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '9 days' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_10 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_10\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_10
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '9 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# #################
# DOWNLOAD DAY 11 #
# #################

if grep -q "epgdata 1[1-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '10 days' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_11
	until tr ' ' '\n' < ~/ztvh/epg/datafile_11 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '10 days' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '10 days' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '10 days' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '11 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '11 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_11 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_11 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_11 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_11 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_11 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_11 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_11 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_11 2> /dev/null
		fi
		rm date*
		
		if tr ' ' '\n' < ~/ztvh/epg/datafile_11 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 11 - $(date -d '10 days' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_11 >> ~/ztvh/epg/datafile
		echo "DAY 11 - $(date -d '10 days' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '10 days' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 11 - $(date -d '10 days' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '10 days' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '10 days' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_11 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '10 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '10 days' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '10 days' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '10 days' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_11\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '10 days' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '10 days' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_11\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_11
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '10 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_11
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '10 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '10 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_11
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_11
			echo "$(date -d '10 days' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 11 - $(date -d '10 days' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_11 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '10 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '10 days' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_11 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_11\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_11
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '10 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# #################
# DOWNLOAD DAY 12 #
# #################

if grep -q "epgdata 1[2-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '11 days' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_12
	until tr ' ' '\n' < ~/ztvh/epg/datafile_12 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '11 days' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '11 days' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '11 days' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '12 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '12 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_12 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_12 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_12 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_12 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_12 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_12 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_12 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_12 2> /dev/null
		fi
		rm date*
		
		if tr ' ' '\n' < ~/ztvh/epg/datafile_12 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 12 - $(date -d '11 days' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_12 >> ~/ztvh/epg/datafile
		echo "DAY 12 - $(date -d '11 days' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '11 days' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 12 - $(date -d '11 days' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '11 days' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '11 days' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_12 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '11 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '11 days' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '11 days' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '11 days' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_12\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '11 days' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '11 days' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_12\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_12
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '11 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_12
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '11 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '11 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_12
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_12
			echo "$(date -d '11 days' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 12 - $(date -d '11 days' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_12 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '11 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '11 days' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_12 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_12\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_12
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '11 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# #################
# DOWNLOAD DAY 13 #
# #################

if grep -q "epgdata 1[3-4]-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '12 days' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_13
	until tr ' ' '\n' < ~/ztvh/epg/datafile_13 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '12 days' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '12 days' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '12 days' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '13 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '13 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_13 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_13 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_13 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_13 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_13 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_13 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_13 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_13 2> /dev/null
		fi
		rm date*
		
		if tr ' ' '\n' < ~/ztvh/epg/datafile_13 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 13 - $(date -d '12 days' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_13 >> ~/ztvh/epg/datafile
		echo "DAY 13 - $(date -d '12 days' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '12 days' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 13 - $(date -d '12 days' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '12 days' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '12 days' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_13 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '12 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '12 days' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '12 days' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '12 days' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_13\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '12 days' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '12 days' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_13\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_13
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '12 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_13
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '12 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '12 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_13
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_13
			echo "$(date -d '12 days' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 13 - $(date -d '12 days' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_13 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '12 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '12 days' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_13 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_13\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_13
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '12 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi


# #################
# DOWNLOAD DAY 14 #
# #################

if grep -q "epgdata 14-" ~/ztvh/user/options 2> /dev/null
then
	mkdir ~/ztvh/epg/$(date -d '13 days' '+%Y%m%d') 2> /dev/null
	touch ~/ztvh/epg/datafile_14
	until tr ' ' '\n' < ~/ztvh/epg/datafile_14 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
	do
		date -d '13 days' '+%Y-%m-%d 06:00:00' > date0
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date0
		date0=$(bash date0)

		date -d '13 days' '+%Y-%m-%d 12:00:00' > date1
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date1
		date1=$(bash date1)
		
		date -d '13 days' '+%Y-%m-%d 18:00:00' > date2
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date2
		date2=$(bash date2)
		
		date -d '14 days' '+%Y-%m-%d 00:00:00' > date3
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date3
		date3=$(bash date3)
		
		date -d '14 days' '+%Y-%m-%d 06:00:00' > date4
		sed -i 's/.*/#\!\/bin\/bash\ndate -d "&" +%s/g' date4
		date4=$(bash date4)
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_14 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_14 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_14 2> /dev/null
			curl -k -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_14 2> /dev/null
		else
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date1&start=$date0" > ~/ztvh/epg/datafile_14 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date2&start=$date1" >> ~/ztvh/epg/datafile_14 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date3&start=$date2" >> ~/ztvh/epg/datafile_14 2> /dev/null
			curl -X GET --cookie "$session" "https://$provider/zapi/v2/cached/program/power_guide/$powerid?end=$date4&start=$date3" >> ~/ztvh/epg/datafile_14 2> /dev/null
		fi
		rm date*
		
		if tr ' ' '\n' < ~/ztvh/epg/datafile_14 | sed 's/"success":true/\n&/g' | grep '"success":true' | wc -l | grep -q 4 2> /dev/null
		then :
		else
			echo ""
			echo "- ERROR: FAILED TO LOAD EPG MAIN FILE! -"
			echo "DAY 14 - $(date -d '13 days' '+%Y%m%d'): Failed to check EPG manifest file!"
			echo "Retry in 10 secs..." && echo ""
			sleep 10s
		fi
	done
	
	if grep -q "epgmode=simple" ~/ztvh/user/options
	then
		cat ~/ztvh/epg/datafile_14 >> ~/ztvh/epg/datafile
		echo "DAY 14 - $(date -d '13 days' '+%Y%m%d'): EPG manifest file saved!"
		touch ~/ztvh/epg/stats
	elif [ -e ~/ztvh/epg/$(date -d '13 days' '+%Y%m%d')_manifest_new ]
	then
		echo ""
		echo "DAY 14 - $(date -d '13 days' '+%Y%m%d'): EPG manifest file updated!"
		mv ~/ztvh/epg/$(date -d '13 days' '+%Y%m%d')_manifest_new ~/ztvh/epg/$(date -d '13 days' '+%Y%m%d')_manifest_old 2> /dev/null
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_14 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '13 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '13 days' '+%Y%m%d')_manifest_new
		
		# Create file checker to download changed/new broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '13 days' '+%Y%m%d')_manifest_new) <(sort -u ~/ztvh/epg/$(date -d '13 days' '+%Y%m%d')_manifest_old 2> /dev/null) > workfile
		sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile && cp workfile workfile2
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_14\/& 2> \/dev\/null/g' workfile
		if grep -q "curl" workfile
		then 
			mv workfile ~/ztvh/epg/filecheck
		fi
	
		# Add commands to file checker to remove deleted broadcasts
		comm -2 -3 <(sort -u ~/ztvh/epg/$(date -d '13 days' '+%Y%m%d')_manifest_old 2> /dev/null) <(sort -u ~/ztvh/epg/$(date -d '13 days' '+%Y%m%d')_manifest_new) > workfile
		if [ -s workfile2 ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			cp workfile2 workfile3
			cat workfile2 >> workfile3
			cat workfile >> workfile3
			sort workfile3 | uniq -u > workfile
			rm workfile2 workfile3
		fi
		if [ -s workfile ]
		then
			sed -i 's/\(.*"id":\)\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\(,.*\)/\2/g' workfile
			sed -i 's/.*/rm epg\/\$date_14\/&/g' workfile
			if [ -s ~/ztvh/epg/filecheck ]
			then
				cat workfile >> ~/ztvh/epg/filecheck
				mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_14
				echo "- NEW CLOUD FILES TO BE ADDED -"
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '13 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			else
				mv workfile ~/ztvh/epg/datafile_14
				echo "- SYNCED FILES TO BE DELETED -"
				touch ~/ztvh/epg/stats
				sed -i "s/$(date -d '13 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			fi
		elif [ -s ~/ztvh/epg/filecheck ]
		then
			echo "- NEW CLOUD FILES TO BE ADDED -"
			touch ~/ztvh/epg/stats
			sed -i "s/$(date -d '13 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
			mv ~/ztvh/epg/filecheck ~/ztvh/epg/datafile_14
		else
			echo "- NO CHANGES FOUND -"
			rm ~/ztvh/epg/datafile_14
			echo "$(date -d '13 days' '+%Y%m%d') finished" >> ~/ztvh/epg/status
		fi
	else
		echo ""
		echo "DAY 14 - $(date -d '13 days' '+%Y%m%d'): EPG manifest file created!"
		sed 's/{"i_url":/\n&/g' ~/ztvh/epg/datafile_14 | sed '1d' | sed 's/}\],"cid".*//g' > ~/ztvh/epg/$(date -d '13 days' '+%Y%m%d')_manifest_new
		sed -i 's/},//g' ~/ztvh/epg/$(date -d '13 days' '+%Y%m%d')_manifest_new
		sed 's/"id":/\n&/g' ~/ztvh/epg/datafile_14 > workfile
		sed -i '/"id":/!d' workfile
		sed -i 's/,.*//g' workfile
		sed -i 's/"id"://g' workfile
		sed -i 's/}.*//g' workfile
		sed -i 's/.*/curl -X GET --cookie "\$session" "https:\/\/\$provider\/zapi\/v2\/cached\/program\/power_details\/$powerid?program_ids=&" | grep ": true, " > epg\/\$date_14\/& 2> \/dev\/null/g' workfile
		mv workfile ~/ztvh/epg/datafile_14
		echo "- COMPLETE DATABASE TO BE SYNCED -"
		touch ~/ztvh/epg/stats
		touch ~/ztvh/epg/update
		sed -i "s/$(date -d '13 days' '+%Y%m%d') finished//g" ~/ztvh/epg/status 2> /dev/null
	fi
fi

rm ~/ztvh/epg/filecheck 2> /dev/null

echo "" && echo "- EPG MANIFEST FILES SAVED SUCCESSFULLY! -" && echo ""


# ##########################
# COLLECT / SPLIT COMMANDS #
# ##########################

if ! grep -q "epgmode=simple" ~/ztvh/user/options
then
	if [ -e ~/ztvh/epg/stats ]
	then
		echo "Setup data collection..." && echo ""
	
		rm ~/ztvh/epg/scriptfile_* 2> /dev/null
		cat ~/ztvh/epg/datafile_* > ~/ztvh/epg/scriptbase
		sed -i 's/nullcurl/null\ncurl/g' ~/ztvh/epg/scriptbase
		sed -i 's/nullrm/null\nrm/g' ~/ztvh/epg/scriptbase
		sort -u ~/ztvh/epg/scriptbase -o ~/ztvh/epg/scriptbase
		rm ~/ztvh/epg/datafile_* ~/ztvh/work/datefile 2> /dev/null
		
		echo "$(date '+%Y%m%d')" > ~/ztvh/work/datefile
		echo "$(date -d '1 day' '+%Y%m%d')" >> ~/ztvh/work/datefile
		echo "$(date -d '2 days' '+%Y%m%d')" >> ~/ztvh/work/datefile
		echo "$(date -d '3 days' '+%Y%m%d')" >> ~/ztvh/work/datefile
		echo "$(date -d '4 days' '+%Y%m%d')" >> ~/ztvh/work/datefile
		echo "$(date -d '5 days' '+%Y%m%d')" >> ~/ztvh/work/datefile
		echo "$(date -d '6 days' '+%Y%m%d')" >> ~/ztvh/work/datefile
		echo "$(date -d '7 days' '+%Y%m%d')" >> ~/ztvh/work/datefile
		echo "$(date -d '8 days' '+%Y%m%d')" >> ~/ztvh/work/datefile
		echo "$(date -d '9 days' '+%Y%m%d')" >> ~/ztvh/work/datefile
		echo "$(date -d '10 days' '+%Y%m%d')" >> ~/ztvh/work/datefile
		echo "$(date -d '11 days' '+%Y%m%d')" >> ~/ztvh/work/datefile
		echo "$(date -d '12 days' '+%Y%m%d')" >> ~/ztvh/work/datefile
		echo "$(date -d '13 days' '+%Y%m%d')" >> ~/ztvh/work/datefile
		
		sed -i '1i#\!\/bin\/bash \
		cd ~\/ztvh \
		session=\$(<~\/ztvh\/user\/session) \
		powerid=\$(<work\/powerid) \
		provider=\$(sed "2,5d;s\/provider=\/\/g" ~\/ztvh\/user\/userfile) \
		date_01=\$(sed -n "1p" work\/datefile) \
		date_02=\$(sed -n "2p" work\/datefile) \
		date_03=\$(sed -n "3p" work\/datefile) \
		date_04=\$(sed -n "4p" work\/datefile) \
		date_05=\$(sed -n "5p" work\/datefile) \
		date_06=\$(sed -n "6p" work\/datefile) \
		date_07=\$(sed -n "7p" work\/datefile) \
		date_08=\$(sed -n "8p" work\/datefile) \
		date_09=\$(sed -n "9p" work\/datefile) \
		date_10=\$(sed -n "10p" work\/datefile) \
		date_11=\$(sed -n "11p" work\/datefile) \
		date_12=\$(sed -n "12p" work\/datefile) \
		date_13=\$(sed -n "13p" work\/datefile) \
		date_14=\$(sed -n "14p" work\/datefile)' ~/ztvh/epg/scriptbase
		sed -i 's/			//g' ~/ztvh/epg/scriptbase
		
		if grep -q "insecure=true" ~/ztvh/user/userfile
		then
			sed -i "s/curl/& -k/g" ~/ztvh/user/scriptbase
		fi
	
		mv ~/ztvh/epg/scriptbase ~/ztvh/epg/scriptfile_00
	fi
fi
