#!/bin/bash
#ensure dialog is installed
if [ ! -f /usr/bin/dialog ];then
	zypper in -y dialog	
fi
#Global Variables
BACKTITLE="David's SUSE Enterprise Storage Installer"
MYHOME=~
DIALOGTMP=/tmp/buildit.sh.$$
editfile(){
	FILENAME=$1	
	dialog --title "Edit" --backtitle "$BACKTITLE" --editbox $FILENAME 40 90 2> "${DIALOGTMP}"
	cp ${DIALOGTMP} $FILENAME 
	rm $DIALOGTMP

}
msgbox(){
	MESSAGE=$1
	dialog --backtitle "$BACKTITLE" --msgbox "$MESSAGE" 0 0 
}
inputbox(){
	MESSAGE=$1
	dialog --backtitle "$BACKTITLE" --inputbox "$MESSAGE" 0 0 2>"${DIALOGTMP}"
	response=$?
	inputboxreturn=$(<$DIALOGTMP)
	rm $DIALOGTMP
	
}
passwdbox(){
	MESSAGE=$1
	dialog --backtitle "$BACKTITLE" --clear --insecure --passwordbox "$MESSAGE" 0 0 2>"${DIALOGTMP}"
	response=$?
	passwdboxreturn=$(<$DIALOGTMP)
	rm $DIALOGTMP
	
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
msgbox "Press return to edit the cluster.lst file"
#vi cluster.lst
editfile cluster.lst

if [ ! -f osdnodes.lst ];then
        echo >osdnodes.lst "# This file should contain the list of all osdnodes in the cluster.  The admin node should not be included"
	echo >>osdnodes.lst"# Additionally, every node in this list should be in the cluster.lst file"
 	
fi
msgbox "Press return to edit the osdnodes.lst file"
editfile osdnodes.lst
#vi osdnodes.lst

#check name resolution for all nodes
for m in `cat cluster.lst`
do
    if ! host $m &>/dev/null;then
        msgbox "!! Host $m does not resolve to an IP.  Please fix and re-run"
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

passwdbox "Enter root Password (assuming all nodes have the same root password) " 
mypass=$passwdboxreturn
for m in `cat cluster.lst`
do
    #echo "** Now copying public key to $m."
    #echo "   You'll be prompted for the root password on that host."
#    expect <<EOF
#    spawn ssh-copy-id -o StrictHostKeyChecking=no -i $MYHOME/.ssh/id_rsa.pub root@$m 
#    expect "assword:" {
#	send "$mypass\n"
#    }
#    eof 
#
#EOF
ssh -q -o PreferredAuthentications=publickey root@$m /bin/true
if [ $? -eq 255 ];then 
          /usr/bin/expect -c "set timeout 50; spawn ssh-copy-id -f -i $MYHOME/.ssh/id_rsa.pub root@$m;

          expect {
                  \"assword: \" {
                  send \"$mypass\n\"
                  expect {
                      \"again.\"     { exit 1 }
                      \"expecting.\" { }
                      timeout      { exit 1 }
                  }
              }
              \"(yes/no)? \" {
                  send \"yes\n\"
                  expect {
                      \"assword: \" {
                          send \"$mypass\n\"
                          expect {
                              \"again.\"     { exit 1 }
                              \"expecting.\" { }
                              timeout      { exit 1 }
                          }
                      }
                  }
              }
          }"
	  ssh root@$m "uniq $MYHOME/.ssh/authorized_keys >$MYHOME/.ssh/authorized_keys.clean;cat $MYHOME/.ssh/authorized_keys.clean>$MYHOME/.ssh/authorized_keys;rm $MYHOME/.ssh/authorized_keys.clean"
  fi
  done

for m in `cat cluster.lst`
do 
    ssh -q -o PreferredAuthentications=publickey root@$m /bin/true
	if [ $? -ne 0 ]
    then
        msgbox "passwordless SSH to $m seems not to be working.  Please correct and re-run the script."
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
       		scp $PWD/wipedrives.sh.src root@$i:/root/wipedrives.sh
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

cp -rp $PWD/policy.cfg /srv/pillar/ceph/proposals/
editfile /srv/pillar/ceph/proposals/policy.cfg
#cp -rp /root/performancecluster/* /srv/salt/ceph/configuration/files/ceph.conf.d/
msgbox "Make any changes you need to the network config"
editfile /srv/pillar/ceph/proposals/config/stack/default/ceph/cluster.yml

echo "*** Letting things settle for 15 seconds before stage 2 ***"
sleep 15s
deepsea stage run ceph.stage.2
echo "time to fix the policy, drive group, etc"
echo -e "count\t\tmodel\t\t\t\t\tsize\trotational";salt -I roles:storage cmd.run "lsblk -o model,size,rota"|grep -v ":"|grep -v "ROTA"|sort|uniq -c
#vi /srv/salt/ceph/configuration/files/drive_groups.yml
while [[ $drivegrouphappy != [YyNn] ]];
	do
		echo "*** Your drivegroup configuration currently yield the following:"
		salt-run disks.report
		read -r -p "Is this what you wish to have happen? [Y/n] " drivegrouphappy
		if [[ $drivegrouphappy != [Yy] ]]; then
msgbox "press enter to edit the drive_groups.yml.  reference on editing the file:https://documentation.suse.com/ses/6/single-html/ses-deployment/#ds-drive-groups" 
			editfile /srv/salt/ceph/configuration/files/drive_groups.yml
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
