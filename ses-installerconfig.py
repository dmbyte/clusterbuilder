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


#does /srv/install exist?
if not os.path.exists('/srv/install'):
    os.makedirs('/srv/install')


makex86 = raw_input('Do you wish to deploy X86_64 nodes from this server? (y or n)')
if makex86 == "y" or makex86 == "yes":
    if not os.path.exists('/srv/install/x86'):
        os.makedirs('/srv/install/x86/sles12/sp2/cd1')
    if not os.path.exists('/srv/www/htdocs/SLE-12-SP2-Server-DVD-x86_64-GM-DVD1.iso'):
        print('The ISO image for x86_64 needs to be located here:/srv/www/htdocs/SLE-12-SP2-Server-DVD-x86_64-GM-DVD1.iso')
    else:
        call(["mount", "-o loop /srv/www/htdocs/SLE-12-SP2-Server-DVD-x86_64-GM-DVD1.iso /srv/install/x86/sles12/sp2/cd1")
        
      

#are ISOs present?  If not, mkdir and mount them
runsmt = raw_input('Do you need to run SMT Configuration? (y or n)')
if runsmt == "y" or runsmt == "yes":
    #launch smt wizard
    call(["yast2", "smt-wizard"])

#collect info needed to deploy dhcpd and others
dodns=raw_input('Do we need to deploy a DNS server for this deployment? (y or n)')
if dodns == "n":
    dns1ip=raw_input('Enter DNS Server IP')
else:
    #zypper in named
    #systemctl enable named
    #write dns files

domainname=raw_input('Enter the domain name for this deployment:')
defaultgw=raw_input('Enter the default gateway:')
amIntp=raw_input('Use this server as NTP server')
if amIntp=="y":
    import netifaces as ni
    ni.ifaddresses('eth0')
    ntpserver = ni.ifaddresses('eth0')[2][0]['addr']
else:
    ntpserver=raw_input('Enter the NTP server address')



