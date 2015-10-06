#!/bin/bash
pdev=$1
parts=$2
psize=$3
if [ "$#" -ne 3 ]; then
        echo "Usage: journalpart.sh <dev> <# of partitions> <partition size in GB>"
        echo "eg: ./journalpart.sh /dev/sdb 5 15"
        exit
fi
if [ ! -e "$1" ]; then
        echo "device does not exist.  Expecting /dev/sdX format"
        exit
fi
#write a clean lable
#eventually need to make smart enough to choose GPT vs msdos
parted -a optimal -s $pdev mklabel msdos
for (( p=1; p<=parts ; p ++ ))
        do
                if [ $p -lt 4 ]; then
                        pend=$(($psize * $p + 1))
                        pstart=$(($pend-$psize))
                        parted -a optimal -s $pdev unit compact mkpart primary xfs "$pstart"g "$pend"g
                        mkfs.xfs -f -n size=64k "$pdev""$p"
                elif [ $p -eq 4 -a  $parts -lt 5 ]; then
                        pend=$(($psize * $p + 1))
                        pstart=$(($pend-$psize))
                        parted -a optimal -s $pdev unit compact mkpart primary xfs "$pstart"g "$pend"g
                        mkfs.xfs -f -n size=64k "$pdev""$p"
                elif [ $p -eq 4 -a  $parts -gt 4 ];then
                        pend=$(($psize * $p + 1))
                        pstart=$(($pend-$psize))
                        pextendedend=$((($parts-3)*$psize+$pstart))
                        parted -a optimal -s $pdev unit compact mkpart extended "$pstart"g "$pextendedend"g
                        parted -a optimal -s $pdev unit compact mkpart logical xfs "$pstart"g "$pend"g
                        mkfs.xfs -f -n size=64k "$pdev""$(($p + 1))"
                elif [ $p -gt 4 ]; then
                        pend=$(($psize * $p + 1))
                        pstart=$(($pend-$psize))
                        parted -a optimal -s $pdev unit compact mkpart logical xfs "$pstart"g "$pend"g
                        mkfs.xfs -f -n size=64k "$pdev""$(($p + 1))"
                fi
        done
