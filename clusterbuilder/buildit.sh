#!/bin/bash
if [ $# -eq 0 ]
  then
	zeroit=dozero
  else
	zeroit=nozero
fi
export DEV_ENV=true
echo "*** Installing and starting salt on admin node ***"
zypper in -y salt-master
echo master:`hostname` >/etc/salt/minion
systemctl enable salt-master.service
systemctl start salt-master.service
zypper in -y salt-minion
systemctl enable salt-minion.service
systemctl start salt-minion.service
echo "*** Installing and starting salt on cluster nodes ***"
for n in `cat cluster.lst`;
do
	ssh root@$n "zypper in -y salt-minion;echo master:`hostname` >/etc/salt/minion;systemctl enable salt-minion.service;systemctl start salt-minion.service"
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
