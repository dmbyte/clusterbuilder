#assumes textfile called osdnodes.lst with one osd hostname per line is in current directory
#one command line variable is required, that is the profile name e.g. profile-default
profilename=$1 
for i in `cat osdnodes.lst`
       do
              echo $i
              for d in `cat /srv/pillar/ceph/proposals/$profilename/stack/default/ceph/minions/$i*.yml|grep "db: "|sort|uniq|cut -f2 -d":"`
                     do 
                           ssh $i "ls -l $d"
                     done
              echo "********************************************************"
       done
