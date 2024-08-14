#!/bin/sh

source /root/H8LogMonitor/configuration.sh
SRVSTATUS="$LOGMNTR/service.status";
INTSTATUS="$LOGMNTR/instance.status";
SYS_UCRH="$(date -u +%H%d%m%Y)";
CFLOWLOGPATH="/$(date -u +%Y/%m/%d)";
CLOWFILEEXT="_$(date -u +%H).csv";
UTCCHR=$(date -u +%H%d%m%Y);
SYSLOGPATH="/$(date  +%Y/%m/%d)";
SYSLOGFILEEXT="_$(date  +%H).csv";
ISTCRH=$(date +%H%d%m%Y);#
# Configurable threshold (in MB)
size_limit_mb=1

mkdir -p /var/log/h8cflow

checkHostList(){
    if [ -e "$LOGMNTR"/"$3""$2"/"$2"host.list ];
    then
        echo "$colser Path Num: $2 Host list exsist";
        sed -i '/^[[:space:]]*$/d' "$LOGMNTR"/"$3""$2"/"$2"host.list

    else
        echo "$colser Path Num: $2 Host list does not exsist creating list";
        mkdir -p "$LOGMNTR"/"$3""$2";
        touch "$LOGMNTR"/"$3""$2"/"$2"host.list;
        echo "$colser Path Num: $2 Host list Created successfully";
    fi
}


checkStopList(){
    if [ -e "$LOGMNTR"/"$3""$2"/"$2"stop.list ];
    then
        echo "$colser Path Num: $2 stop list exsist";
        sed -i '/^[[:space:]]*$/d' "$LOGMNTR"/"$3""$2"/"$2"stop.list

    else
        echo "$colser Path Num: $2 stop list does not exsist creating file";
        mkdir -p "$LOGMNTR"/"$3""$2";
        touch "$LOGMNTR"/"$3""$2"/"$2"stop.list;
        echo "$colser Path Num: $2 Host list Created successfully";
    fi
}



checkHostIP(){
    if [ $1 = IPFIX ] || [ $1 = NETFLOW  ];
    then
        hostips=$(ls $2/$CFLOWLOGPATH/ |cut -d "_" -f 1 | sort --unique)
    fi
    if [ $1 = SYSLOG ];
    then
        hostips=$(ls $2/$SYSLOGPATH/ |cut -d "_" -f 1 | sort --unique)
    fi
    HOSTLIST="$LOGMNTR/$1$3/$3host.list";
	IFS=$'\n'
    for hostip in $hostips                          #Reading HotIPs from list
    do
        grep -w "$hostip" $HOSTLIST  >> /dev/null;       #Comparing HostIPs with available list

        if [ $? -eq 0 ];
        then
            echo "IP already Exsist";
        else
            echo "adding $hostip" ;
            echo "$hostip" >> $HOSTLIST;                  #updating unavailable host IPS
        fi
    done 
};

#
# Hoststop List CRUD
#

checkIP(){
    echo "Checking IP in $4 $3/$3 stop.list"
    if  grep -q -w "$4" "$LOGMNTR"/"$1""$3"/"$3"stop.list;      #Comparing HostIPs with available list
    then
        echo "IP found returing 0"
        return 0;
    else
        echo "IP not found returing 1"
        return 1;
    fi
};

removeIP(){
    checkIP $1 $2 $3 $4;
    if [[ $? -eq 0 ]];
    then
        if [ $1 = IPFIX ] || [ $1 = NETFLOW  ];
        then
        echo "Log Started for $4 in $4$CLOWFILEEXT at $UTCCHR"
        echo "Log Started for $4 in $4$CLOWFILEEXT at $UTCCHR" >> /var/log/h8cflow/naslog.alerts
        fi
        if [ $1 = SYSLOG ];
        then
        echo "Log Started for $4 in $4$SYSLOGFILEEXT at $ISTCRH"
        echo "Log Started for $4 in $4$SYSLOGFILEEXT at $ISTCRH" >> /var/log/h8cflow/naslog.alerts
        fi
        local removeipline=$(grep -n -w $4 "$LOGMNTR"/"$1""$3"/"$3"stop.list | cut -d ":" -f 1)
        sed -i -e "$removeipline"d "$LOGMNTR"/"$1""$3"/"$3"stop.list;
        sed -i '/^[[:space:]]*$/d' "$LOGMNTR"/"$1""$3"/"$3"stop.list;
    else
        echo "Remove IP No Action require"
    fi
};

addIP(){
    checkIP $1 $2 $3 $4;
    if [[ $? -eq 0 ]];
    then
        echo "IP $4 already Added in stop list No Action Require"
    else
        echo "IP Not Found Adding New IP"
        if [ $1 = IPFIX ] || [ $1 = NETFLOW  ];
        then
            echo "Log Stopped for $4 in $4$CLOWFILEEXT at $UTCCHR"
            echo "Log Stopped for $4 in $4$CLOWFILEEXT at $UTCCHR" >> /var/log/h8cflow/naslog.alerts
            echo "$4" >> "$LOGMNTR"/"$1""$3"/"$3"stop.list
        fi
        if [ $1 = SYSLOG ];
        then
            echo "Log Stopped for $4 in $4$SYSLOGFILEEXT at $ISTCRH"
            echo "Log Stopped for $4 in $4$SYSLOGFILEEXT at $ISTCRH" >> /var/log/h8cflow/naslog.alerts
            echo "$4" >> "$LOGMNTR"/"$1""$3"/"$3"stop.list
        fi
    fi
};


checkCurrentHourFile(){
    echo "Checking current hour file for $1 $2 $3 $4"
    echo "Reading Hostlist $3/$3host.list"
    HOSTLIST="$LOGMNTR/"$1""$3"/$3host.list";
    while read -r host
    do
        if [ ! -z "$host" -a "$host" != " " ]; then

        if [ $1 = IPFIX ] || [ $1 = NETFLOW  ];
        then
            echo "Checking current hour file for host $host in $2/$CFLOWLOGPATH/"
			if [ -e "$2/$CFLOWLOGPATH/$host$CLOWFILEEXT" ] && [ "$(stat -c%s "$2/$CFLOWLOGPATH/$host$CLOWFILEEXT")" -gt 10240 ];
            then
                echo "Current hour file availabe for $host in  $2/$CFLOWLOGPATH/$host$CLOWFILEEXT checking file active";
                checkFileActive "$1" "$2" "$3" "$host";
            else
                UTC_MIN=$(date -u +%M);
                if [ "$UTC_MIN" -le 05 ]
                then
                    echo "$: Waiting for new file to be generated at start of new hour for 300 seconds";
                    sleep 300;
                    if [ -e "$2/$CFLOWLOGPATH/$host$CLOWFILEEXT" ] && [ "$(stat -c%s "$2/$CFLOWLOGPATH/$host$CLOWFILEEXT")" -gt 10240 ];
                    then
                        LG_FSIZE=$(stat --printf="%s" $2/$CFLOWLOGPATH/$host$CLOWFILEEXT)
						LOGFSF=$LOGMNTR/$1$3/$host/"$(date -u +%H%d%m%Y)"_$host.log;
						if [ ! -f "$LOGFSF" ]; then
							mkdir -p $LOGMNTR/$1$3/$4;
							touch  $LOGFSF;
						fi
                        echo "Log found calling removeip function"
                        echo "$UTCCHR|$host|$LG_FSIZE|/$2$CFLOWLOGPATH/$host$CLOWFILEEXT" > $LOGFSF
                        removeIP "$1" "$2" "$3" "$host";
                    else
                        echo "Log not found calling add ip function";
                        addIP "$1" "$2" "$3" "$host";
                    fi
                else
                    echo "Current hour file not availabe for $host in  $2/$CFLOWLOGPATH/$host$CLOWFILEEXT";
                    echo "Logfiles is not generated for $host on $UTCCHR (UTC)";
                    addIP "$1" "$2" "$3" "$host";
                fi
            fi
        fi
        if [ $1 = SYSLOG ];
        then
            if [ -e "$2/$SYSLOGPATH/$host$SYSLOGFILEEXT" ] && [ "$(stat -c%s "$2/$SYSLOGPATH/$host$SYSLOGFILEEXT")" -gt 10240 ];
            then
                echo "Current hour file availabe for $host in  $2/$SYSLOGPATH/$host$SYSLOGFILEEXT";
                checkFileActive "$1" "$2" "$3" "$host";
            else
                IST_MIN=$(date +%M);
                if [ $IST_MIN -le 05 ];
                then
                    echo "$: Waiting for new file to be generated at start of new hour for 300 seconds";
                    sleep 300;
						if [ -e "$2/$SYSLOGPATH/$host$SYSLOGFILEEXT" ] && [ "$(stat -c%s "$2/$SYSLOGPATH/$host$SYSLOGFILEEXT")" -gt 10240 ];
                        then
                            SYSLG_FSIZE=$(stat --printf="%s" $2/$SYSLOGPATH/$host$SYSLOGFILEEXT)
							SYSLOGFSF=$LOGMNTR/$1$3/$host/"$(date  +%H%d%m%Y)"_$host.log
							if [ ! -f "$SYSLOGFSF" ]; then
								mkdir -p $LOGMNTR/$1$3/$4;
								touch  $SYSLOGFSF;
							fi
                            echo "Logs found calling removeip function";
                            echo "$ISTCRH|$host|$SYSLG_FSIZE|$2/$SYSLOGPATH/$host$SYSLOGFILEEXT" > $SYSLOGFSF;
                            removeIP "$1" "$2" "$3" "$host";
                        else
                            echo "Log not found calling add ip function";
                            addIP "$1" "$2" "$3" "$host";                            
                        fi
                else
                    echo "Current hour file not availabe for $host in  $2/$SYSLOGPATH/$host$SYSLOGFILEEXT"
                    echo "Logfiles is not generated for $host on $ISTCRH (IST)";
                    addIP "$1" "$2" "$3" "$host";

                fi
            fi
        fi
        else
            echo "Log Stopped"
        fi
    done < $HOSTLIST
}

checkFileActive(){
        if [ $1 = IPFIX ] || [ $1 = NETFLOW  ];
        then
                LG_FSIZE=$(stat --printf="%s" $2/$CFLOWLOGPATH/$4$CLOWFILEEXT)
                LOGFSF=$LOGMNTR/$1$3/$4/"$(date -u +%H%d%m%Y)"_$4.log;
                if [ -e $LOGFSF ];
                then
                    LG_OSIZE=$(cat $LOGFSF | cut -d "|" -f 3)
                    if [ $LG_FSIZE -gt $LG_OSIZE  ]
                    then
                        echo "Log found calling removeip function"
                        echo "$UTCCHR|$4|$LG_FSIZE|/$2$CFLOWLOGPATH/$4$CLOWFILEEXT" > $LOGFSF
                        removeIP "$1" "$2" "$3" "$4";
                    else
                        echo "Log not found calling add ip function";
                        addIP "$1" "$2" "$3" "$4";
                    fi
                else
                    echo "$LOGFSF file/directory not generated creating new file/directory";
                    mkdir -p $LOGMNTR/$1$3/$4;
                    touch  $LOGFSF;
                    echo "$UTCCHR|$4|$LG_FSIZE|$2$CFLOWLOGPATH/$4$CLOWFILEEXT" > $LOGFSF;
                    echo "Log found calling removeip function"
                    removeIP "$1" "$2" "$3" "$4";
                fi
          fi
            if [ $1 = SYSLOG ];
            then
                    SYSLG_FSIZE=$(stat --printf="%s" $2/$SYSLOGPATH/$4$SYSLOGFILEEXT)
                    SYSLOGFSF=$LOGMNTR/$1$3/$4/"$(date  +%H%d%m%Y)"_$4.log
                    if [ -e $SYSLOGFSF ];
                    then
                        SYSLG_OSIZE=$(cat $SYSLOGFSF | cut -d "|" -f 3)
                        if [ $SYSLG_FSIZE -gt $SYSLG_OSIZE  ]
                        then
                            echo "Logs found calling removeip function";
                            echo "$ISTCRH|$4|$SYSLG_FSIZE|$2/$SYSLOGPATH/$4$SYSLOGFILEEXT" > $SYSLOGFSF;
                            removeIP "$1" "$2" "$3" "$4";
                        else
                            echo "Log not found calling addip function";
                            addIP "$1" "$2" "$3" "$4";
                        fi
                    else
                        echo "$SYSLOGFSF file/directory not generated Creating new file/directory"
                        mkdir -p $LOGMNTR/$1$3/$4
                        touch  $SYSLOGFSF
                        echo "$ISTCRH|$4|$SYSLG_FSIZE|$2/$SYSLOGPATH/$4$SYSLOGFILEEXT" > $SYSLOGFSF
                        echo "$SYSLOGFSF file created successfully";
                        removeIP "$1" "$2" "$3" "$4";
                    fi
            fi
}




current_time=$(date +%s)
checkTotalFilesize(){
total_size=0
	if [ $1 = IPFIX ] || [ $1 = NETFLOW  ];
	then
		files_to_check=$(find "$2/$CFLOWLOGPATH/" -type f -mmin -10) 
		IFS=$'\n'
		for file_path in $files_to_check; do
		# Get the file size in bytes
		file_size=$(stat -c %s "$file_path")
    
		# Add the file size to the total size
		total_size=$((total_size + file_size))
		done
		# Convert total size from bytes to MB
		total_size_mb=$(echo "scale=2; $total_size / 1024 / 1024" | bc)

		# Check if total size is within the size limit
		echo $total_size
		cflowlastline=$(grep -w "$3" /var/log/h8cflow/cflowservice.alerts | tail -n 1)
		if (( $(echo "$total_size_mb <= $size_limit_mb" | bc -l) )); then
			echo "Total size of files updated in the last 10 minutes is ${total_size_mb} MB."
			if ! [[ "$cflowlastline" =~ "Stopped"  ]]; then
				echo "$3 Log Generation Stopped Logstash at $ISTCRH IST" >> /var/log/h8cflow/cflowservice.alerts
			fi
		else
			if ! [[ "$cflowlastline" =~ "Stopped"  ]]; then
				echo "File size check now action require"
			else			
				echo "Total size of files updated in the last 10 minutes is ${total_size_mb} MB."
				echo "$3 Log Generation Started Logstash at $ISTCRH IST" >> /var/log/h8cflow/cflowservice.alerts
			fi
		fi
	fi
	if [ $1 = SYSLOG ];
	then
		files_to_check=$(find "$2/$SYSLOGPATH/" -type f -mmin -10) 
		IFS=$'\n'
		for file_path in $files_to_check; do		
		# Get the file size in bytes
		file_size=$(stat -c %s "$file_path")
    
		# Add the file size to the total size
		total_size=$((total_size + file_size))
		done
		echo "outsie of loop $total_size"

		# Convert total size from bytes to MB
		total_size_mb=$(echo "scale=2; $total_size / 1024 / 1024" | bc)
		
		# Check if total size is within the size limit
		echo $total_size
		sysloglastline=$(grep -w "$3" /var/log/h8cflow/syslogservice.alerts | tail -n 1)
		if (( $(echo "$total_size_mb <= $size_limit_mb" | bc -l) )); then
			echo "Total size of files updated in the last 10 minutes is ${total_size_mb} MB."
			if ! [[ "$sysloglastline" =~ "Stopped"  ]]; then
				echo "$3 Log Generation Stopped Syslog at $ISTCRH IST" >> /var/log/h8cflow/syslogservice.alerts
			fi
		else
			if ! [[ "$sysloglastline" =~ "Stopped"  ]]; then			
				echo "File size check now action require"
			else
				echo "Total size of files updated in the last 10 minutes is ${total_size_mb} MB."
				echo "$3 Log Generation Started Syslog at $ISTCRH IST" >> /var/log/h8cflow/syslogservice.alerts
			fi
		fi
	fi
}

if [ $NETFLOW -eq 1  ];
then
colser=NETFLOW
delimiter=":";
IFS="$delimiter";
read -ra path_array <<< "$CFLOWLOGBASEPATH"
i=1;
# Iterate through the paths and check files in each path
for path in "${path_array[@]}"; do
    echo "Checking files in: $path"
    pathnum=path$i
    checkHostList "$path" $pathnum $colser;
    checkStopList "$path" $pathnum $colser;
    checkHostIP  "$colser" "$path" $pathnum;
    checkCurrentHourFile "$colser" "$path" $pathnum;
	checkTotalFilesize "$colser" "$path" $pathnum;
    i=$(( $i + 1 ));
done
fi


if [ $IPFIX -eq 1  ];
then
colser=IPFIX
delimiter=":";
IFS="$delimiter";
read -ra path_array <<< "$CFLOWLOGBASEPATH"
i=1;
# Iterate through the paths and check files in each path
for path in "${path_array[@]}"; do
    echo "Checking files in: $path"
    pathnum=path$i
    checkHostList "$path" $pathnum $colser;
    checkStopList "$path" $pathnum $colser;
    checkHostIP  "$colser" "$path" $pathnum;
    checkCurrentHourFile "$colser" "$path" $pathnum;
	checkTotalFilesize "$colser" "$path" $pathnum;
    i=$(( $i + 1 ));
done
fi




if [ $SYSLOG -eq 1  ];
then
colser=SYSLOG
delimiter=":";
IFS="$delimiter";
read -ra path_array <<< "$SYSLOGBASEPATH"
i=1;
# Iterate through the paths and check files in each path
for path in "${path_array[@]}"; do
    echo "Checking files in: $path"
    pathnum=path$i
    checkHostList "$path" $pathnum $colser;
    checkStopList "$path" $pathnum $colser;
    checkHostIP  "$colser" "$path" $pathnum;
    checkCurrentHourFile "$colser" "$path" $pathnum;
	checkTotalFilesize "$colser" "$path" $pathnum;
    i=$(( $i + 1 ));
done
fi

