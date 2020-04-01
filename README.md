# General
These scripts are *DESTRUCTIVE* and make some rather large assumptions.

I use these scripts to rapidly build and NUKE my lab environment for 
SUSE Enterprise Storage.

They are developed against version 5 currently

# ASSUMPTIONS:
1.  The biggest and most dangerous assumption is that the OS is installed on a 
    single drive and all others are fair game to be wiped out.
2.  DNS resolution is functioning properly
3.  These scripts will be run from the admin node, named salt
4.  You have created and distributed an ssh key for root to all nodes

# USAGE
Proper use is to copy the two .sh and one .sh.src file to the /root/ directory 
on the admin node AFTER the OS is installed.

To use these scripts, create 3 files
 
 - osdnodes.lst
    --  A list of the resolvable names of all OSD nodes

 - cluster.lst
    -- A list of all the nodes in the cluster (Monitors, gateways, admin, OSDs, etc)
    
 - /root/policy.cfg
    -- the policy.cfg file you wish to use for deployments
    
 You also need to edit the buildit script to fix the profile generation for DeepSea

After creating the three files, simply run the buildit.sh script.

put the policy.cfg in /root

extract the perfcluster.tgz file and move the performancecluster directory to /root e.g. mv performancecluster /root/

extract the correct dmb_kern_tune.*.tgz file and move the dmb_kern_tune directory /srv/salt/
  apply by using this command: salt '*' state.apply
