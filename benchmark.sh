#! /bin/bash
osdlist=`ceph osd tree|grep host|awk -F"host" '{print $2}'|xargs`
output="rados_benchmark.txt"
cleantime=600
osdcount=`ceph osd tree|grep host|awk -F"host" '{print $2}'|wc -l`
benchtime=300

#create bench2 and bench3 pools
format="%5s     %10s     %10s     %10s     %10s\n"
printf "$format" "Test    " "Pool" "Thread" "Bandwidth" "Latency"2>&1>>output
for pool in "bench" "bench2"
    do
        for thread in 1 2 3 4 6 9 15 25
            do
                printf "$format" "Write   " "$pool" "$thread" `rados -p $pool bench $benchtime write -t $thread |grep 'Bandwidth (MB/sec)\|Average Latency'|cut -f2 -d":"|xargs`2>&1>>output
                rados -p $pool bench $cleantime write -t $osdcount --no-cleanup 2>&1>/dev/null
                for osdname in $osdlist
                    do
                        ssh ceph@$osdname "echo \"echo 3>/proc/sys/vm/drop_caches\"|sudo sh" 1>&2>/dev/null
                    done
                printf "$format" "Rnd Read" "$pool" "$thread" `rados -p $pool bench $benchtime rand -t $thread --no-cleanup |grep 'Bandwidth\|Average'|cut -f2 -d":"|xargs`2>&1>>output
                rados -p $pool bench $cleantime write -t $osdcount --no-cleanup 2>&1 >/dev/null
                for osdname in $osdlist
                    do
                        ssh ceph@$osdname "echo \"echo 3>/proc/sys/vm/drop_caches\"|sudo sh" 1>&2>/dev/null
                    done
                printf "$format" "Seq Read" "$pool" "$thread" `rados -p $pool bench $benchtime seq -t $thread --no-cleanup|grep 'Bandwidth\|Average'|cut -f2 -d":"|xargs`2>&1>>output
        done
    done
