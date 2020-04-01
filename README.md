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


To use these scripts, create 3 files
 
 - osdnodes.lst
    --  A list of the resolvable names of all OSD nodes

 - cluster.lst
    -- A list of all the nodes in the cluster (Monitors, gateways, admin, OSDs, etc)
    
 - /$PWD/policy.cfg
    -- the policy.cfg file you wish to use for deployments
    
Optionally, you may also create a drive_groups.yml

After creating the three files, simply run the buildit.sh script.


extract the perfcluster.tgz file and move the performancecluster directory to /root e.g. mv performancecluster /root/
 * not necessary, optional and currently disabled in script

extract the correct dmb_kern_tune.*.tgz file and move the dmb_kern_tune directory /srv/salt/
modify to match your needs
  apply by using this command: salt '*' state.apply
