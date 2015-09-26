#! /bin/bash
osdlist=" osd1 osd2 osd3"
output="${0}_$(hostname)_out"
echo -e "\n$(hostname)\n" > $output


for cmd in \
"ceph status" \
"ceph mds stat" \
"ceph quorum_status" \
"ceph df" \
"ceph-deploy disk list $(hostname)" \
"lsblk" \
"rados df" 
  do
echo -e "\nrunning : $cmd\n" >> $output
$cmd 2>&1 >> $output
  done
format="%5s     %10s     %10s     %10s     %10s\n"
        printf "$format" "Test    " "Pool" "Thread" "Bandwidth" "Latency"
for pool in "bench" "bench2"
do
for thread in 1 2 3 4 6 9 15 25
  do
        printf "$format" "Write   " "$pool" "$thread" `rados -p $pool bench 100 write -t $thread |grep 'Bandwidth (MB/sec)\|Average Latency'|cut -f2 -d":"|xargs`
rados -p $pool bench 300 write -t 3 --no-cleanup 2>&1>/dev/null
for osdname in $osdlist
do 
ssh ceph@$osdname "echo \"echo 3>/proc/sys/vm/drop_caches\"|sudo sh" 1>&2>/dev/null
done
printf "$format" "Rnd Read" "$pool" "$thread" `rados -p $pool bench 100 rand -t $thread --no-cleanup |grep 'Bandwidth\|Average'|cut -f2 -d":"|xargs`
rados -p $pool bench 300 write -t 3 --no-cleanup 2>&1 >/dev/null
for osdname in $osdlist
do 
ssh ceph@$osdname "echo \"echo 3>/proc/sys/vm/drop_caches\"|sudo sh" 1>&2>/dev/null
done
printf "$format" "Seq Read" "$pool" "$thread" `rados -p $pool bench 100 seq -t $thread --no-cleanup|grep 'Bandwidth\|Average'|cut -f2 -d":"|xargs`
  done
done
