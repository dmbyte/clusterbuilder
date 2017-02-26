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

def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', ifname[:15])
    )[20:24])


#get all the interfaces on the system 
iflist=os.listdir('/sys/class/net/')

for x in iflist:
	print(x+': '+get_ip_address(x))

#find which ip/interface to use for deployment servers
whichint=''
while whichint not in iflist:
    whichint=raw_input('Which interface is on the deployment network for dhcp/pxe/etc?')
myip=get_ip_address(whichint)

#does /srv/install exist?
if not os.path.exists('/srv/install'):
    os.makedirs('/srv/install')

makex86=''
while makex86 not in ['y','n']:
    makex86 = raw_input('Do you wish to deploy x86_64 nodes from this server? (y or n)')
if makex86 == "y":
    if not os.path.exists('/srv/install/x86'):
        os.makedirs('/srv/install/x86/sles12/sp2/cd1')
    if not os.path.exists('/srv/www/htdocs/SLE-12-SP2-Server-DVD-x86_64-GM-DVD1.iso'):
        print('The ISO image for X86_64 needs to be located here:/srv/www/htdocs/SLE-12-SP2-Server-DVD-x86_64-GM-DVD1.iso')
	quit()
    else:
        call(["mount", "-o", "loop", "/srv/www/htdocs/SLE-12-SP2-Server-DVD-x86_64-GM-DVD1.iso", "/srv/install/x86/sles12/sp2/cd1"])
        # NEED TO ADD TO EXPORTS FILE IF NOT ALREADY THERE ***

makearm = raw_input('Do you wish to deploy ARMv8 nodes from this server? (y or n)')
if makearm == "y":
    if not os.path.exists('/srv/install/armv8'):
        os.makedirs('/srv/install/armv8/sles12/sp2/cd1')
    if not os.path.exists('/srv/www/htdocs/SLE-12-SP2-Server-DVD-aarch64-GM-DVD1.iso'):
        print('The ISO image for ARMv8 needs to be located here:/srv/www/htdocs/SLE-12-SP2-Server-DVD-aarch64-GM-DVD1.iso')
	quit()
    else:
        call(["mount", "-o", "loop", "/srv/www/htdocs/SLE-12-SP2-Server-DVD-aarch64-GM-DVD1.iso", "/srv/install/armv8/sles12/sp2/cd1"])
        # NEED TO ADD TO EXPORTS FILE IF NOT ALREADY THERE ***
        
      

runsmt = raw_input('Do you need to run SMT Configuration? (y or n)')
if runsmt == "y" or runsmt == "yes":
    #launch smt wizard
    call(["yast2", "smt-wizard"])
    smtip=myip
else:
    smtip=raw_input('Enter SMT server IP: ')

#collect info needed to deploy dhcpd and others
dodns=raw_input('Do we need to deploy a DNS server for this deployment? (y or n)')
if dodns == "n":
    dns1ip=raw_input('Enter DNS Server IP: ')
#else:
    #zypper in named
    #systemctl enable named
    #write dns files

domainname=raw_input('Enter the domain name for this deployment: ')
defaultgw=raw_input('Enter the default gateway: ')
amIntp=raw_input('Use this server as NTP server? (y or n)')
if amIntp=="y":
    ntpserver = myip
else:
    ntpserver=raw_input('Enter the NTP server address: ')

subnetaddress=raw_input('Enter the subnet address. eg 192.168.124.0: ')
netmask=raw_input('Enter the netmask eg 255.255.255.0: ')
rangestart=raw_input('Enter the first address in the DHCP range: ')
rangestop=raw_input('Enter the last address in the DHCP range: ')

#Write the dhcpd.conf
f=open("/etc/dhcpd.conf", "w")
f.write('option domain-name %s;\r\n'%domainname)
f.write('option domain-name-servers %s;\r\n'%dns1ip)
f.write('option routers %s;\r\n'%defaultgw)
f.write('option ntp-servers %s;\r\n'%ntpserver)
f.write('option arch code 93 = unsigned integer 16; # RFC4578\r\n')
f.write('default-lease-time 3600;\r\n')
f.write('ddns-update-style none;\r\n')
f.write('subnet %s netmask %s {\r\n'%(subnetaddress, netmask))
f.write('  range %s %s;\r\n'%(rangestart, rangestop))
f.write('  next-server %s;\r\n'%myip)
f.write('  default-lease-time 3600;\r\n')
f.write('  max-lease-time 3600;\r\n')
if makex86=="y" and makearm=="y":
    f.write('   if option arch = 00:0b {\r\n')
    f.write('   filename "/EFI/armv8/bootaa64.efi";\r\n')
    f.write('  } else if option arch = 00:07 or option arch = 00:09 {\r\n')
if makex86=="n" and makearm=="y":
    f.write('   if option arch = 00:0b {\r\n')
    f.write('   filename "/EFI/armv8/bootaa64.efi";\r\n')
if makex86=='y' and makearm=="n":
    f.write('  if option arch = 00:07 or option arch = 00:09 {\r\n')
if makex86=="y":    
    f.write('   filename "/EFI/x86/bootx64.efi";\r\n')
    f.write('    } else {\r\n')
    f.write('   filename "/bios/x86/pxelinux.0";\r\n')
f.write('    }\r\n')
f.write('}\r\n')
f.close

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
    exports=open("/etc/exports","w")
    exports.write('/srv/install  *(ro,root_squash,sync,no_subtree_check)')
    exports.close
    call(["systemctl", "restart", "nfs-server.service"])

#write pxe message & grub.cfg files
os.makedirs('/srv/tftpboot')
if makex86=="y":
    os.makedirs('/srv/tftpboot/bios/x86')
    os.makedirs('/srv/tftpboot/EFI/x86/boot')
    biosfiles=['linux', 'initrd', 'message']
    biosfilesrc='/srv/install/x86/sles12/sp2/cd1/boot/x86_64/loader/'
    for bfile in biosfiles:
        shutil.copy( biosfilesrc + bfile, '/srv/tftpboot/bios/x86/'+bfile)
        if makearm=='y' and bfile != 'message':
            shutil.copy(biosfilesrc+bfile, '/srv/tftpboot/EFI/x86/boot'+bfile)
    os.makedirs('/srv/tftpboot/bios/x86/pxelinux.cfg')
    
    shutil.copy('/usr/share/syslinux/pxelinux.0', '/srv/tftpboot/bios/x86/pxelinux.0')

    #write the default file for bios pxe clients
    pxedef=open('/srv/tftpboot/bios/x86/pxelinux.cfg/default','w')
    pxedef.write('default harddisk')
    pxedef.write('# hard disk')
    pxedef.write('label harddisk')
    pxedef.write('  localboot -2')
    pxedef.write('# install')
    pxedef.write('label install')
    pxedef.write('  kernel linux')
    pxedef.write('  append initrd=initrd showopts install=nfs://'+myip+'/srv/install/x86/sles12/sp2/cd1')

    pxedef.write('display message')
    pxedef.write('implicit 0')
    pxedef.write('prompt 1')
    pxedef.write('timeout 600')
    pxedef.close()
    
    #write the message file
    pxemsg=open('/srv/tftpboot/bios/x86/message','w')
    pxemsg.write('                             Welcome to the Installer Environment! ')
    pxemsg.write(' ')
    pxemsg.write('To start the installation enter install and press <return>.')
    pxemsg.write(' ')
    pxemsg.write('Available boot options:')
    pxemsg.write('  harddisk   - Boot from Hard Disk (this is default)')
    pxemsg.write('  install     - Installation')
    pxemsg.write(' ')
    pxemsg.write('Have a lot of fun...')
    pxemsg.close()

    #do the efi files
    efix86files=['bootx64.efi', 'grub.efi', 'MokManager.efi']
    efix86filesrc='/srv/install/x86/sles12/sp2/cd1/EFI/BOOT/'
    for efix86file in efix86files:
        shutil.copy( efix86filesrc + efix86file, '/srv/tftpboot/EFI/x86/'+efix86file)

    grubfile=open('/srv/tftpboot/EFI/grub.cfg','a')
    grubfile.write('set timeout=5')
    grubfile.write('menuentry \'Install SLES12 SP2 for x86_64\' {')
    grubfile.write(' linuxefi /EFI/x86/boot/linux install=nfs://'+myip+'/srv/install/x86/sles12/sp2/cd1')
    grubfile.write(' initrdefi /EFI/x86/boot/initrd')
    grubfile.write('}')
    grubfile.close()

if makearm=="y":
    os.makedirs('/srv/tftpboot/EFI/armv8/boot')
    shutil.copy( '/srv/install/armv8/sles12/sp2/cd1/EFI/BOOT/bootaa64.efi', '/srv/tftpboot/EFI/armv8/bootaa64.efi')
    armv8files=['linux', 'initrd']
    armv8filesrc='/srv/install/armv8/sles12/sp2/cd1/boot/aarch64/'
    for armv8file in armv8files:
        shutil.copy( armv8filesrc + armv8file, '//srv/tftpboot/EFI/armv8/boot/'+armv8file)

    grubfile=open('/srv/tftpboot/EFI/grub.cfg','a')
    grubfile.write('menuentry \'Install SLES12 SP2 for SoftIron OverDrive\' {')
    grubfile.write(' linux /EFI/armv8/boot/linux network=1 usessh=1 sshpassword="suse" install=nfs://'+myip+'/srv/install/armv8/sles12/sp2/cd1 console=ttyAMA0,115200n8')
    grubfile.write(' initrd /EFI/armv8/boot/initrd')
    grubfile.write('}')
    grubfile.close()
#write/modify autoyast files