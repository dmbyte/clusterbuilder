#! /bin/bash
osdlist=`ceph osd tree|grep host|awk -F"host" '{print $2}'|xargs`
output="osd_info.txt"
echo -e "\n$(hostname)\n" > $output

for cmd in \
	"ceph status" \
	"ceph mds stat" \
	"ceph quorum_status" \
	"ceph df"  \
	"rados df"
    do
	echo ***$cmd***>>$output
        $cmd >>$output
    done

for osdname in $osdlist
    do
	for cmd2 in "ssh ceph@"$osdname" lsblk" "ssh ceph@"$osdname" cat /proc/scsi/scsi" "ceph-deploy disk list "$osdname":sda" "ssh ceph@"$osdname" ip -d link" "ssh ceph@"$osdname" ip -d addr" "ssh ceph@"$osdname" sudo lspci" "ssh ceph@"$osdname" cat /proc/cpuinfo"
        do
        	echo ***$cmd2*** >>$output
		$cmd2 &>>$output
        	# ssh ceph@"$osdname" "$cmd" >> $output
    	done
done
