#ceph-deploy new dl360-1 dl360-2 dl360-3
#/home/ceph/donodes.sh to ALL "sudo /sbin/SuSEfirewall2 off"
#ceph-deploy mon create-initial
a=1
for i in sda sdb sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp
sdq sdr sds sdt sdu sdv sdw sdx
do
echo $a
if [ $a -le 6 ]
         then
         k="sdy"
elif [ $a -le 12 ]
         then
         k="sdz"
elif [ $a -le 18 ]
         then
         k="sdaa"
elif [ $a -le 24 ]
         then
         k="sdab"

fi
a=$((a+1))
                 /home/ceph/donodes.sh to OSD "ceph-deploy osd create
NODE:$i:$k"

done
