#!/bin/bash
#TODO
# - Make script able to extract node types from running ceph config OR use nodes.lst file
if [ "$#" = "3" ]; then
	echo $1
	echo $2
	case $2 in 
		OSD)
			hostlist=`grep "type=osd" ~ceph/nodes.lst|cut -f1 -d":"|xargs`
			;;
		MON)
			hostlist=`grep "type=mon" ~ceph/nodes.lst|cut -f1 -d":"|xargs`
			;;
		ALL)
			hostlist=`grep "type=" ~ceph/nodes.lst|cust -f1 -d":"|xargs`
			;;
	esac
	for node in $hostlist
	do
		if [ "$1" =  "on" ]; then
			echo $node 
			ssh ceph@$node $3
		elif [ "$1" = "to" ]; then
			echo $node
			command=${3/NODE/$node}
			echo $command
		fi
		
	done

else
	echo "Usage: donodes [on|to] [OSD|MON|ALL] command"
	echo "on = run on the node"
	echo "to = do it to the node, eg scp /etc/ntp.conf root@NODE:/etc/ntp.conf"
	echo "  NODE is automatically replaced with the appropriate node names as"
	echo "  specified in the second argument."
        echo ""
        echo "This excepts a file ~ceph/nodes.lst formatted as below"
        echo "osd1:192.168.124.101:type=osd:type=mon"
        echo "osd2:192.168.124.102:type=osd"


fi
