
#input: [prototype] [list of other nodes]

#TODO: Write a check to verify all nodes are similar

#list the mounted devices
proto_mounted_cmd='cat /etc/mtab |cut -f1 -d" "|grep dev|uniq|grep "/"|cut -f3 -d"/"|xargs'
proto_mounted_out=`ssh ceph@$1 $proto_mounted_cmd`
#echo $proto_mounted_out
count_mount=`echo $proto_mounted_out|wc -w`
#echo $count_mount
array=( $@ )
len=${#array[@]}
echo Number of hosts to check: $len
testlist=${array[@]:1:$len}
echo Test List: $testlist


mounted_same=true
for i in $testlist
do
        command1='sudo cat /etc/mtab |cut -f1 -d" "|grep dev|uniq|grep "/"|cut -f3 -d"/"|xargs'
        myout=`ssh ceph@$i $command1`
        mycount_mount=`echo $myout|wc -w`
        if [ "$count_mount" -ne "$mycount_mount" ]
        then
                mounted_same=false
        else
                echo protonode:       $1
                echo protoimounts:    $proto_mounted_out
                echo testnode:        $i
                echo testnodemounts:  $myout
                if [ "$proto_mounted_out" == "$myout" ]
                then
                        echo SAME
                else
                        echo $i is Different
                        exit
                fi
        fi
done

# if mounted device from above shows up as kname, then add pkname to ignore list
proto_blkdevs=`lsblk -iPo PKNAME,KNAME -e 11|xargs`
#if proto_blkdev in proto_mounted_out then ignore=$ignore." ".proto_blkdev

# if in /proc/mdstat, add disk to the ignore list
#proto_md=`cat /proc/mdstat`

#if not in ignore list, list all drives output by this lsblk command (rotational 0 = SSD, 1 = spinning) and ask for what to do
#lsblk -dio PKNAME,KNAME,TYPE,SIZE,MODEL,rota

#options on what to do: [i]gnore, [j]ournal, [o]sd

#after all data collected, divide journals by osds.  Advise user is 1:6 ratio is exceeded and ask for continue/abort.

#If continue or ratio-ok, then perform osd create
#ceph-deploy osd create NODE:data:journal 