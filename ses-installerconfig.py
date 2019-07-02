
from subprocess import call
#call(["ls", "-l"])
import os.path
#os.path.isfile
#os.path.exists

# get the IP from eth0.  Eventually needs to offer a list of interfaces, but this is good for round 1
import socket
import fcntl
import struct
import shutil
import array
import sys

def up_interfaces():
    is_64bits = sys.maxsize > 2**32
    struct_size = 40 if is_64bits else 32
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    max_possible = 8 # initial value
    while True:
        bytes = max_possible * struct_size
        names = array.array('B', '\0' * bytes)
        outbytes = struct.unpack('iL', fcntl.ioctl(
            s.fileno(),
            0x8912,  # SIOCGIFCONF
            struct.pack('iL', bytes, names.buffer_info()[0])
        ))[0]
        if outbytes == bytes:
            max_possible *= 2
        else:
            break
    namestr = names.tostring()
    return [(namestr[i:i+16].split('\0', 1)[0])
            for i in range(0, outbytes, struct_size)]

def makepath(path):
    if not os.path.exists(path):
        os.makedirs(path)
    
def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', ifname[:15])
    )[20:24])

def fstabupdate(mntsrc,mntpath):
    import mmap
    fstab = open('/etc/fstab')
    s = mmap.mmap(fstab.fileno(), 0, access=mmap.ACCESS_READ)
    if not s.find('mntpath') != -1:
        fstab.close()
        fstab=open('/etc/fstab','a')
        fstab.write(mntsrc+" "+mntpath+" iso9660 loop 0 0\n")

os.system('clear')
#get all the interfaces on the system 
iflist=up_interfaces()

for x in iflist:
	print(x+': '+get_ip_address(x))

#find which ip/interface to use for deployment servers
whichint=''
while whichint not in iflist:
    whichint=raw_input('Which interface is on the deployment network for dhcp/pxe/etc?')
myip=get_ip_address(whichint)

#does /srv/install exist?
makepath('/srv/install')
    

makex86=''
while makex86 not in ['y','n']:
    makex86 = raw_input('Do you wish to deploy x86_64 nodes from this server? (y or n)')
if makex86 == "y":
    
    makepath('/srv/install/x86/sles15/sp1/cd1')
    if not os.path.exists('/srv/www/htdocs/SLE-15-SP1-Installer-DVD-x86_64-GM-DVD1'):
        print('The ISO image for X86_64 needs to be located here:/srv/www/htdocs/SSLE-15-SP1-Installer-DVD-x86_64-GM-DVD1.iso')
	quit()
    else:
        call(["mount", "-o", "loop", "/srv/www/htdocs/SLE-15-SP1-Installer-DVD-x86_64-GM-DVD1.iso", "/srv/install/x86/sles15/sp1/cd1"])
        fstabupdate('/srv/www/htdocs/SSLE-15-SP1-Installer-DVD-x86_64-GM-DVD1.iso','/srv/install/x86/sles15/sp1/cd1')
        

makearm = raw_input('Do you wish to deploy ARMv8 nodes from this server? (y or n)')
if makearm == "y":
    makepath('/srv/install/armv8/sles15/sp1/cd1')
    if not os.path.exists('/srv/www/htdocs/SLE-15-SP1-Installer-DVD-aarch-GM-DVD1.iso'):
        print('The ISO image for ARMv8 needs to be located here:/srv/www/htdocs/SLE-15-SP1-Installer-DVD-x86_64-GM-DVD1.iso')
	quit()
    else:
        call(["mount", "-o", "loop", "/srv/www/htdocs/SLE-15-SP1-Installer-DVD-aarch-GM-DVD1.iso", "/srv/install/armv8/sles15/sp1/cd1"])
        fstabupdate('/srv/www/htdocs/SLE-15-SP1-Installer-DVD-aarch-GM-DVD1.iso','/srv/install/armv8/sles15/sp1/cd1')
        
      

runsmt = raw_input('Do you need to run SMT Configuration? (y or n)')
if runsmt == "y" or runsmt == "yes":
    #launch smt wizard
    call(["yast2", "smt-wizard"])
    smtip=myip
else:
    smtip=raw_input('Enter SMT/RMT server IP: ')

#collect info needed to deploy dhcpd and others
dodns=raw_input('Do we need to deploy a DNS server for this deployment? (y or n)')
if dodns == "n":
    dns1ip=raw_input('Enter DNS Server IP: ')
#else:
    #zypper in named
    #systemctl enable named
    #write dns files



amIntp=raw_input('Use this server as NTP server? (y or n)')
if amIntp=="y":
    ntpserver = myip
else:
    ntpserver=raw_input('Enter the NTP server address: ')
print('DHCP Server Info')    
domainname=raw_input('Enter the domain name for this deployment: ')
subnetaddress=raw_input('Enter the subnet address. eg 192.168.124.0: ')
netmask=raw_input('Enter the netmask eg 255.255.255.0: ')
defaultgw=raw_input('Enter the default gateway: ')
rangestart=raw_input('Enter the first address in the DHCP range: ')
rangestop=raw_input('Enter the last address in the DHCP range: ')

osdprefix=raw_input('Enter the prefix to use for OSD node hostnames: ')
monprefix=raw_input('Enter the prefix to use for Monitor node hostnames: ')
igwprefix=raw_input('Enter the prefix to use for ISCSI Gateway node hostnames: ')
rgwprefix=raw_input('Enter the prefix to use for RADOS Gateway node hostnames: ')
mdsprefix=raw_input('Enter the prefix to use for Metadata Server node hostnames: ')

#Write the dhcpd.conf
call(["zypper","in","-y","dhcp-server"])
call(["systemctl","enable","dhcpd"])
f=open("/etc/dhcpd.conf", "wb")
f.write('option domain-name "%s";\n'%domainname)
f.write('option domain-name-servers %s;\n'%dns1ip)
f.write('option routers %s;\n'%defaultgw)
f.write('option ntp-servers %s;\n'%ntpserver)
f.write('option arch code 93 = unsigned integer 16; # RFC4578\n')
f.write('default-lease-time 3600;\n')
f.write('ddns-update-style none;\n')
f.write('subnet %s netmask %s {\n'%(subnetaddress, netmask))
f.write('  range %s %s;\n'%(rangestart, rangestop))
f.write('  next-server %s;\n'%myip)
f.write('  default-lease-time 3600;\n')
f.write('  max-lease-time 3600;\n')
if makex86=="y" and makearm=="y":
    f.write('   if option arch = 00:0b {\n')
    f.write('   filename "/EFI/armv8/bootaa64.efi";\n')
    f.write('  } else if option arch = 00:07 or option arch = 00:09 {\n')
if makex86=="n" and makearm=="y":
    f.write('   if option arch = 00:0b {\n')
    f.write('   filename "/EFI/armv8/bootaa64.efi";\n')
if makex86=='y' and makearm=="n":
    f.write('  if option arch = 00:07 or option arch = 00:09 {\n')
if makex86=="y":    
    f.write('   filename "/EFI/x86/bootx64.efi";\n')
    f.write('    } else {\n')
    f.write('   filename "/bios/x86/pxelinux.0";\n')
f.write('    }\n')
f.write('}\n')
f.close
call(["yast2","dhcp-server"])
call(["systemctl","start","dhcpd"])
#make sure tftp is setup
#should figure out if it is already present and enabled, maybe check /etc/xinetd.d/tftpd
runtftp = raw_input('Do you need to run TFTP Configuration? (y or n)')
if runtftp == "y":
    #launch smt wizard
    call(["yast2", "tftp-server"])

# setup and activate NFS server exports
runnfs = raw_input('We need NFS for the install source, run the configuration now? (y or n) ')
if runnfs == 'y':
    call(["yast2", "nfs-server"])
    exports=open("/etc/exports","wb")
    exports.write('/srv/install  *(ro,root_squash,sync,no_subtree_check,crossmnt)\n')
    exports.close
    call(["systemctl", "restart", "nfs-server.service"])
    call(["exportfs","-a"])

#write pxe message & grub.cfg files
makepath('/srv/tftpboot')
if makex86=="y":
    makepath('/srv/tftpboot/bios/x86')
    makepath('/srv/tftpboot/EFI/x86/boot')
    biosfiles=['linux', 'initrd', 'message']
    biosfilesrc='/srv/install/x86/sles15/sp1/cd1/boot/x86_64/loader/'
    for bfile in biosfiles:
        shutil.copy( biosfilesrc + bfile, '/srv/tftpboot/bios/x86/'+bfile)
        if makearm=='y' and bfile != 'message':
            shutil.copy(biosfilesrc+bfile, '/srv/tftpboot/EFI/x86/boot'+bfile)
    makepath('/srv/tftpboot/bios/x86/pxelinux.cfg')
    makepath('/usr/share/syslinux')
    
    shutil.copy('/usr/share/syslinux/pxelinux.0', '/srv/tftpboot/bios/x86/pxelinux.0')

    #write the default file for bios pxe clients
    pxedef=open('/srv/tftpboot/bios/x86/pxelinux.cfg/default','wb')
    pxedef.write('default harddisk\n')
    pxedef.write('# hard disk\n')
    pxedef.write('label harddisk\n')
    pxedef.write('  localboot -2')
    pxedef.write('# install\n')
    pxedef.write('label install\n')
    pxedef.write('  kernel linux\n')
    pxedef.write('  append initrd=initrd showopts install=nfs://'+myip+'/srv/install/x86/sles12/sp3/cd1\n')

    pxedef.write('display message\n')
    pxedef.write('implicit 0\n')
    pxedef.write('prompt 1\n')
    pxedef.write('timeout 600\n')
    pxedef.close()
    
    #write the message file
    pxemsg=open('/srv/tftpboot/bios/x86/message','wb')
    pxemsg.write('                             Welcome to the Installer Environment! \n')
    pxemsg.write(' \n')
    pxemsg.write('To start the installation enter install and press <return>.\n')
    pxemsg.write(' \n')
    pxemsg.write('Available boot options:\n')
    pxemsg.write('  harddisk   - Boot from Hard Disk (this is default)\n')
    pxemsg.write('  install     - Installation\n')
    pxemsg.write(' \n')
    pxemsg.write('Have a lot of fun...\n')
    pxemsg.close()

    #do the efi files
    efix86files=['bootx64.efi', 'grub.efi', 'MokManager.efi']
    efix86filesrc='/srv/install/x86/sles15/sp1/cd1/EFI/BOOT/'
    for efix86file in efix86files:
        shutil.copy( efix86filesrc + efix86file, '/srv/tftpboot/EFI/x86/'+efix86file)

    grubfile=open('/srv/tftpboot/EFI/x86/grub.cfg','ab')
    grubfile.write('set timeout=5\n')
    grubfile.write('menuentry \'Install SLES15 SP1 for x86_64\' {\n')
    grubfile.write(' linuxefi /EFI/x86/boot/linux install=nfs://'+myip+'/srv/install/x86/sles15/sp1/cd1\n')
    grubfile.write(' initrdefi /EFI/x86/boot/initrd\n')
    grubfile.write('}\n')
    grubfile.close()

if makearm=="y":
    makepath('/srv/tftpboot/EFI/armv8/boot')
    shutil.copy( '/srv/install/armv8/sles15/sp1/cd1/EFI/BOOT/bootaa64.efi', '/srv/tftpboot/EFI/armv8/bootaa64.efi')
    armv8files=['linux', 'initrd']
    armv8filesrc='/srv/install/armv8/sles15/sp1/cd1/boot/aarch64/'
    for armv8file in armv8files:
        shutil.copy( armv8filesrc + armv8file, '//srv/tftpboot/EFI/armv8/boot/'+armv8file)

    grubfile=open('/srv/tftpboot/EFI/armv8/grub.cfg','ab')
    grubfile.write('menuentry \'Install SLES15 SP1 for Overdrive\' {\n')
    grubfile.write(' linux /EFI/armv8/boot/linux network=1 usessh=1 sshpassword="suse" install=nfs://'+myip+'/srv/install/armv8/sles15/sp1/cd1 console=ttyAMA0,115200n8\n')
    grubfile.write(' initrd /EFI/armv8/boot/initrd\n')
    grubfile.write('}\n')
    grubfile.close()
#write/modify autoyast files
#   VLANs of phyiscally separate nets
#        if VLAN, get VLAN IDs
#   get what type of bond (802.3ad or mode-6)

#   create bond with VLAN sub-interfaces
#boot nodes
