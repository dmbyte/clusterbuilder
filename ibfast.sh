#!/bin/bash
LOCAL_CPUS=`cat /sys/class/net/ib0/device/local_cpus`
echo $LOCAL_CPUS > /sys/class/net/ib0/queues/rx-0/rps_cpus