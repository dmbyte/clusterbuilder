#!/bin/bash

for i in 4kr 4kw 8kr 8kw 64kr 64kw 1mr 1mw
do
mylen=${#i}
let "mylen2=$mylen - 1"
rw=${i:$mylen2:1}
bs=${i:0:$mylen2}
echo [global] >$i.fio
echo ioengine=aio >>$i.fio
echo filename=/dev/sdb >>$i.fio
echo numjobs=1 >>$i.fio
echo runtime=1200 >>$i.fio
echo group_reporting=1 >>$i.fio
echo per_job_logs=0 >>$i.fio
echo rw=$rw
echo bs=$bs
echo iodepth=16>>$i.fio
echo [$i]>>$i.fio
if [ $rw = "r" ]
then
	echo rw=randread>>$i.fio
else
	echo rw=randwrite>>$i.fio 
fi
echo bs=$bs>>$i.fio
echo direct=1>>$i.fio
echo sync=1>>$i.fio
# Set max acceptable latency to 500msec
#echo latency_target=15000000>>$i.fio
# profile over a 5s window
#echo latency_window=5000000>>$i.fio
# 99.9% of IOs must be below the target
#echo latency_percentile=99.9 >>$i.fio

echo write_bw_log=$i>>$i.fio
echo write_iops_log=$i>>$i.fio
echo write_lat_log=$i>>$i.fio
done
