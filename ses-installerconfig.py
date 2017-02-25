from subprocess import call
#call(["ls", "-l"])
import os.path
#os.path.isfile
#os.path.exists

#create = f.open("filename.txt", "w+")
#for i in range(10):
#     f.write("This is line %d\r\n" % (i+1))
#read = f.open("filename.txt", "r")
#append=f.open("filename.txt", "a+")
#operations f.write
#be sure to close it f.close()
#is file open? if f.mode=='r':
#contents=f.read() read into variable named contents
#contents=f.readlines() read a line at a time
# get the IP from eth0.  Eventually needs to offer a list of interfaces, but this is good for round 1
import socket
import fcntl
import struct

def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', ifname[:15])
    )[20:24])

get_ip_address('eth0') 

myip=get_ip_address('eth0')
#does /srv/install exist?
if not os.path.exists('/srv/install'):
    os.makedirs('/srv/install')


makex86 = raw_input('Do you wish to deploy X86_64 nodes from this server? (y or n)')
if makex86 == "y" or makex86 == "yes":
    if not os.path.exists('/srv/install/x86'):
        os.makedirs('/srv/install/x86/sles12/sp2/cd1')
    if not os.path.exists('/srv/www/htdocs/SLE-12-SP2-Server-DVD-x86_64-GM-DVD1.iso'):
        print('The ISO image for x86_64 needs to be located here:/srv/www/htdocs/SLE-12-SP2-Server-DVD-x86_64-GM-DVD1.iso')
	quit()
    else:
        call(["mount", "-o loop /srv/www/htdocs/SLE-12-SP2-Server-DVD-x86_64-GM-DVD1.iso /srv/install/x86/sles12/sp2/cd1"])
        
      

#are ISOs present?  If not, mkdir and mount them
runsmt = raw_input('Do you need to run SMT Configuration? (y or n)')
if runsmt == "y" or runsmt == "yes":
    #launch smt wizard
    call(["yast2", "smt-wizard"])

#collect info needed to deploy dhcpd and others
dodns=raw_input('Do we need to deploy a DNS server for this deployment? (y or n)')
if dodns == "n":
    dns1ip=raw_input('Enter DNS Server IP')
#else:
    #zypper in named
    #systemctl enable named
    #write dns files

domainname=raw_input('Enter the domain name for this deployment:')
defaultgw=raw_input('Enter the default gateway:')
amIntp=raw_input('Use this server as NTP server')
if amIntp=="y":
    ntpserver = myip
else:
    ntpserver=raw_input('Enter the NTP server address')

subnetaddress=raw_input('Enter the subnet address. eg 192.168.124.0:')
netmask=raw_input('Enter the netmask eg 255.255.255.0:')
rangestart=raw_input('Enter the first address in the DHCP range:')
rangestop=raw_input('Enter the last address in the DHCP range:')

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
f.write('  if option arch = 00:07 or option arch = 00:09 {\r\n')
f.write('   filename "/EFI/x86/bootx64.efi";\r\n')
f.write('    } else if option arch = 00:0b {\r\n')
f.write('   filename "/EFI/armv8/bootaa64.efi";\r\n')
f.write('    } else {\r\n')
f.write('   filename "/bios/x86/pxelinux.0";\r\n')
f.write('    }\r\n')
f.write('}\r\n')
f.close