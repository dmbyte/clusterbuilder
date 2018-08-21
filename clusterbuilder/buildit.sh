#!/bin/bash
if [ $# -eq 0 ]
  then
	zeroit=dozero
  else
	zeroit=nozero
fi
#check if cluster.lst file is present
if [ ! -f cluster.lst ];then
        echo "!! You must create the clusters.lst file for this to work."
        echo "   The file should contain a list of all the cluster nodes with"
        echo "   one per line. This includes salt/admin, monitor, gateways, etc"

        exit
fi

if [ ! -f osdnodes.lst ];then
        echo "!! You must create the osdnodes.lst file for this to work."
        echo "   The file should contain a list of all the osd nodes with one"
        echo "   per line."
        exit

#check name resolution for all nodes
for m in `cat cluster.lst`
do
    if ! host $m &>/dev/null;then
        echo "!! Host $m does not resolve to an IP.  Please fix and re-run"
        exit
    fi
done

echo "** First we'll ensure that we have uninhibited access by use ssh keys"
#Check if public key is present
if [ ! -f ~/.ssh/id_rsa.pub ];then
        echo "** Need to generate rsa keypair for this host"
        ssh-keygen -N "" -f ~/.ssh/id_rsa
fi

#copy public key to loadgens

for m in `cat cluster.lst`
do
    echo "** Now copying public key to $m."
    echo "   You'll be prompted for the root password on that host."
    ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root@$m &>/dev/null
done

for m in `cat cluster.lst`
do 
    ssh root@$m 'exit'
    if [ $? -ne 0 ]
    then
        echo "SSH to $m seems not to be working.  Please correct and re-run"
        echo "the script."
        exit
    fi
done



export DEV_ENV=true
echo "*** Installing and starting salt on admin node ***"
zypper in -y salt-master
myname=`hostname`
echo master:$myname >/etc/salt/minion
systemctl enable salt-master.service
systemctl start salt-master.service
zypper in -y salt-minion
systemctl enable salt-minion.service
systemctl start salt-minion.service
echo "*** Installing and starting salt on cluster nodes ***"
for n in `cat cluster.lst`;
do
	ssh root@$n "zypper in -y salt-minion;echo master:$myname >/etc/salt/minion;systemctl enable salt-minion.service;systemctl start salt-minion.service"
done
echo "*** Letting things settle for 30 seconds ***"
sleep 30s
salt-key --accept-all
if [ zeroit != 'nozero' ];then
	for i in `cat osdnodes.lst`;
	do
       		scp /root/wipedrives.sh.src root@$i:/root/wipedrives.sh
	done
	echo "*** Wiping non-OS drives - 5 seconds to abort ***"
	sleep 5s
	salt '*' cmd.run 'if [ -e "/root/wipedrives.sh" ];then sh /root/wipedrives.sh;fi'
	salt '*' cmd.run 'if [ -e "/root/wipedrives.sh" ];then rm -f /root/wipedrives.sh;fi'
fi
echo "*** Letting things settle for 30 seconds ***"
sleep 30s
zypper in -y deepsea
echo "*** Letting things settle for 15 seconds ***"
sleep 15s
salt '*' grains.append deepsea default
echo "*** Letting things settle for 15 seconds before stage 0 ***"
sleep 15s
deepsea stage run ceph.stage.0
echo "*** Letting things settle for 15 seconds before stage 1 ***"
sleep 15s
deepsea stage run ceph.stage.1
rm -rf /srv/pillar/ceph/proposals/profile-default
echo "Time to build your propasal"
# run lsblk -o SIZE,TYPE,ROTA,TRAN |grep disk|uniq for each node, 
#echo This is a list of the drives on each node
#for i in `cat osdnodes.lst`
#do 
#    lsblk -o SIZE,TYPE,ROTA,TRAN|grep disk|sort|uniq -c;part=`cat /etc/mtab |cut -f1 -d" "|grep dev|uniq|grep "/"|xargs|cut -f1 -d" "`;part=${part#/dev/};disk=$(readlink /sys/class/block/$part);disk=${disk%/*};disk=${disk##*/};osdrive=$disk;echo "osdrive="`lsblk -o SIZE,TYPE,ROTA,TRAN,kname|grep $osdrive|grep disk`
#done
salt-run proposal.populate name=default ratio=6 target='4*' format=bluestore wal-size=2g db-size=60g db=400-500 wal=400-500 data=3000-8000
cp -rp /root/policy.cfg /srv/pillar/ceph/proposals/
echo "*** Letting things settle for 15 seconds before stage 2 ***"
sleep 15s
deepsea stage run ceph.stage.2
echo "*** Letting things settle for 15 seconds before stage 3 ***"
sleep 15s
deepsea stage run ceph.stage.3
echo "*** Letting things settle for 15 seconds before stage 4 ***"
sleep 15s
deepsea stage run ceph.stage.4
