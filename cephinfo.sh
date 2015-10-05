#! /bin/bash
osdlist=`ceph osd tree|grep host|awk -F"host" '{print $2}'|xargs`
output="osd_info.txt"
echo -e "\n$(hostname)\n" > $output

for osdname in $osdlist
    do 
        for cmd in \
        "ceph status" \
"ceph mds stat" \
"ceph quorum_status" \
"ceph df" \
"ceph-deploy disk list $(hostname)" \
"lsblk" \
"rados df" 
    do
        echo -e "\n$osdname $cmd:" >> $output
        ssh ceph@$osdname $cmd 2>&1 >> $output
    done
done
