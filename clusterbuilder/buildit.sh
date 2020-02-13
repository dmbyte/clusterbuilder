#!/bin/bash
editfile(){
	FILENAME=$1	
	BACKTITLE="David's SUSE Enterprise Storage Installer"
	INPUT=/tmp/t.sh.$$
	dialog --title "Edit" --backtitle "$BACKTITLE" --editbox $FILENAME 40 90 2> "${INPUT}"
	cp ${INPUT} $FILENAME 
	rm /tmp/t.sh.$$
}

if [ $# -eq 0 ]
  then
	zeroit=dozero
  else
	zeroit=nozero
fi
if [ ! -f /usr/bin/dialog];then
	zypper in -y dialog
fi
echo "*** Doing some pre-flight checks ***"
#check if there is crap in iptables
if [ `iptables -nL|wc -l` -gt 8 ];then
	echo "Warning!  There is stuff in iptables. This may break deepsea!"
	iptables -nl
	echo "You can abort now and fix it and then re-run the buildit script"
	read -r -p "Abort now or press enter to continue " mycrap
fi

#check if cluster.lst file is present
if [ ! -f cluster.lst ];then
        echo >cluster.lst "#This file should contain the list of all nodes in the cluster"
        echo >>cluster.lst ""
        echo >>cluster.lst "#This node (the admin node) should be the last in the list"
	echo $HOSTNAME >>cluster.lst
	
fi
read -r -p "Press return to edit the cluster.lst file"
#vi cluster.lst
editfile cluster.lst

if [ ! -f osdnodes.lst ];then
        echo >osdnodes.lst "# This file should contain the list of all osdnodes in the cluster.  The admin node should not be included"
	echo >>osdnodes.lst"# Additionally, every node in this list should be in the cluster.lst file"
 	
fi
read -r -p "Press return to edit the osdnodes.lst file"
editfile osdnodes.lst
#vi osdnodes.lst

#check name resolution for all nodes
for m in `cat cluster.lst`
do
    if ! host $m &>/dev/null;then
        echo "!! Host $m does not resolve to an IP.  Please fix and re-run"
        exit
    fi
done

echo "** Ensure that we have uninhibited access by use ssh keys"
#Check if public key is present
if [ ! -f ~/.ssh/id_rsa.pub ];then
        echo "** Need to generate rsa keypair for this host"
        ssh-keygen -N "" -f ~/.ssh/id_rsa
fi

#copy public key to loadgens

#read -r -p "Enter root Password (assuming all nodes have the same root password) " mypass
for m in `cat cluster.lst`
do
    echo "** Now copying public key to $m."
    echo "   You'll be prompted for the root password on that host."
    spawn ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root@$m &>/dev/null
#    expect "*assword:" { send "$mypass\n";}
    
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
echo master: $myname >/etc/salt/minion
systemctl enable salt-master.service
systemctl start salt-master.service
zypper in -y salt-minion
systemctl enable salt-minion.service
systemctl start salt-minion.service
echo "*** Installing and starting salt on cluster nodes ***"
for n in `cat cluster.lst`;
do
	ssh root@$n "hostname;zypper in -y salt-minion;echo master: $myname >/etc/salt/minion;systemctl enable salt-minion.service;systemctl start salt-minion.service"
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
	sleep 2s
	echo "*** Removing wipedrives.sh from nodes ***"
	salt '*' cmd.run 'if [ -e "/root/wipedrives.sh" ];then rm -f /root/wipedrives.sh;fi'
fi
echo "*** Letting things settle for 30 seconds ***"
sleep 30s
zypper in -y deepsea
echo "*** Letting things settle for 15 seconds ***"
sleep 15s
salt '*' grains.append deepsea default
salt '*' cmd.run 'SUSEConnect -p ses/6/x86_64'
echo "*** Letting things settle for 15 seconds before stage 0 ***"
sleep 15s
salt '*' grains.append deepsea default
deepsea stage run ceph.stage.0
echo "*** Letting things settle for 15 seconds before stage 1 ***"
sleep 15s
deepsea stage run ceph.stage.1
rm -rf /srv/pillar/ceph/proposals/profile-default

cp -rp /root/policy.cfg /srv/pillar/ceph/proposals/
vi /srv/pillar/ceph/proposals/policy.cfg
#cp -rp /root/performancecluster/* /srv/salt/ceph/configuration/files/ceph.conf.d/
read -r -p "Make any changes you need to the network config" responsein
vi /srv/pillar/ceph/proposals/config/stack/default/ceph/cluster.yml

echo "*** Letting things settle for 15 seconds before stage 2 ***"
sleep 15s
deepsea stage run ceph.stage.2
echo "time to fix the policy, drive group, etc"
echo -e "count\t\tmodel\t\t\t\t\tsize\trotational";salt -I roles:storage cmd.run "lsblk -o model,size,rota"|grep -v ":"|grep -v "ROTA"|sort|uniq -c
read -r -p "press enter to edit the drive_groups.yml.  reference on editing the file:https://documentation.suse.com/ses/6/single-html/ses-deployment/#ds-drive-groups" responsein
#vi /srv/salt/ceph/configuration/files/drive_groups.yml
while [[ $drivegrouphappy != [YyNn] ]];
	do
		echo "*** Your drivegroup configuration currently yield the following:"
		salt-run disks.report
		read -r -p "Is this what you wish to have happen? [Y/n] " drivegrouphappy
		if [[ $drivegrouphappy != [Yy] ]]; then
			vi /srv/salt/ceph/configuration/files/drive_groups.yml
			drivegrouphappy=''
		fi
	done

echo "*** Letting things settle for 15 seconds before stage 3 ***"
sleep 15s
echo "*** Disabling subvolume check and running stage 3 ***"
echo "subvolume_init: disabled">/srv/pillar/ceph/stack/global.yml
salt '*' saltutil.refresh_pillar
deepsea stage run ceph.stage.3
echo "*** Letting things settle for 15 seconds before stage 4 ***"
sleep 15s
deepsea stage run ceph.stage.4
sleep 10s
echo "Dashboard Credentials to be used on the manager nodes"
salt-call grains.get dashboard_creds
