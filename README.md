## Ansible modules for CDH

This repository contains Ansible modules that cover the pre-requisites required
to install Cloudera CDH 5.x using Cloudera Manager.

## Pre-requisites

The following needs to already exist before running these scripts.
* An AWS EC2 instance running Active Directory 2008R2 with the Unix identity
management role & the Certificate Authority role installed.
* The Root CA certificate extracted from AD and copied to the machine running
Ansible.
* All EC2 instances running CentOS 6 are up and running and tagged correctly
for Ansible to find them.
* In AD forward and reverse DNS entries have been created for all hosts
* In AD keytabs have been generated for each Linux host and have been copied
to the machine running Ansible
* An Organisational Unit (OU) called Unix has been set up in AD
* A group called `ldapproxygrp` has been created in AD under the Unix OU
* A user called `ldapproxy` has been created in AD as a member of the `ldapproxygrp`

## Setup

The initial setup requires getting the external certificates created on Active
Directory copied into the ansible code base. These mostly are used by the `sssd`
role so they are copied there.

1. First we need to set the current IP address of the AD server as the DNS
server:
```bash
sed -i '' 's/^ad_ip:.*/ad_ip: 10.100.128.53/' ansible/inventory/group_vars/cdh
```
2. Next we need to copy the Active Directory Root CA certificate to the same
role:
```bash
cp ~/Documents/certs/AD-CA.cer ansible/roles/sssd/files/AD-CA.cer
```
3. We also need to copy all the Kerberos keytabs created on Active Directory
into the same location:
```bash
cp ~/Documents/certs/*.keytab ansible/roles/sssd/files
```
4. Before anything else we need to make sure we can contact all the Linux
hosts via `ansible`:
```bash
ansible all -m ping
```
To do this you need to make sure the latest AWS keypair PEM used to launch the AWS
EC instances is copied into the `pems` directory:
```bash
Steves-MacBook-Pro:ansible_hadoop_ad sjj$ ls -l pems/TelkomselFMS.pem
-r--------  1 sjj  staff  1671 16 Nov 21:22 pems/TelkomselFMS.pem
Steves-MacBook-Pro:ansible_hadoop_ad sjj$
```

## Running ansible

The ansible modules are currently broken down into phases so we can check things
worked between each phase. These should really all be run in a single `site.yml`
playbook at some point.

#### Phase 1
The first phase configures most of the CDH pre-requisites
```bash
ansible-playbook ansible/phase1.yml
```
This phase does the following to all machines:
* Disables SELinux
* Disables the IPtables firewall
* Remove some problematic ipv6 modules from the kernel
* Set `vm.swappiness` as recommended by Cloudera
* Disable Transparent Huge Pages
* Set the `limits.conf` as recomended by Cloudera
* Set the hostname in `/etc/hosts` and the network configuration
* Disable ipv6
* Configure ntp
* Install DNS client tools for `dig`
* Configure the current CDH `yum` repositories
* Install the Oracle JDK with JCE extensions
* Install the PostgreSQL client
* Install and configure DNS
This phase also does the following to just the Cloudera Manager host:
* Install the PostgreSQL server
At the end we need to re-run the DNS client for some reason I can't yet figure
out.
```bash
ansible-playbook ansible/fix_dns.yml
```
After this it's best to check DNS forward and reverse lookups match the client
IP and hostname:
```bash
ansible all -m shell -a 'grep $HOSTNAME /etc/hosts;dig $HOSTNAME +short; dig -x `dig $HOSTNAME +short` +short'
```

#### Phase 2
The second phase is responsible for configuring the Linux hosts to integrate
single sign on (SSO) with Active Directory using `sssd`.
```bash
ansible-playbook ansible/phase2.yml
```
This phase configures everything required to get account information from AD
on the Linux side. To test this afterwards you can run this and make sure
a defined account on Active Directory exists:
```bash
ansible all -m shell -a 'getent passwd ldapproxy'
```

#### Phase 3
The third phase installs the Cloudera manager software and does some pre-configuration.
```bash
ansible-playbook ansible/phase3.yml
```
This module does the following for the Cloudera manager server:
* Install the cloudera manager using `yum`
* Run a PostgreSQL script to pre-create all the Cloudera Manager databases,
namely `scm`, `amon`, `rman`, `sentry`, `nav` & `navms`
This module does the following on the Cloudera manager agents:
* Install the cloudera manager agent software using `yum`
* Configure the client with the location of the CM server

#### Phase 4
This module starts the Cloudera Manager server and then all the agents.
```bash
ansible-playbook ansible/phase4.yml
```

#### Phase 5
The last module sets up the external PostgreSQL databases needed for Hive,
Sqoop2 and Oozie. This will determine which hosts to do this on based on
which hosts are configured as being in the ansible `hive`, `sqoop` or `oozie`
group in `ansible/inventory/hosts`. This snippet shows how this is done:
```
[hive:children]
tag_Name_cdhmaster03

[oozie:children]
tag_Name_cdhmaster01

[sqoop:children]
tag_Name_cdhmaster01
```
To run this:
```bash
ansible-playbook ansible/phase5.yml
```
This will install the PostgreSQL server package on these hosts and configure
the required database for the product. When CDH is installed the master for
each service should be located on the machine configured here.

## CDH Install

At this point you should be able to connect to the CM URL and log in with the `admin`
user to start configuring the cluster:

http://cdhmgr01.cdh.hadoop:7180

## Scripts

There are a few other scripts in this repositry that are useful for managing this AWS setup.

* `scripts/fix_hosts.sh`: This script is used to modify the `/etc/hosts` file on the machine running ansible to add the latest external IP address for all correctly tagged EC2 instances. You need to give your `sudo` password on a Mac:
```bash
Steves-MacBook-Pro:scripts sjj$ ./fix_hosts.sh
i-5b32579c cdhmgr01 54.191.183.21
Password:
i-653257a2 cdhmaster03 54.191.52.154
i-5a32579d cdhworker01 54.191.158.54
i-5932579e cdhworker02 54.187.207.142
i-5832579f cdhworker03 54.191.184.240
i-673257a0 cdhmaster01 54.191.51.191
i-663257a1 cdhmaster02 54.191.231.156
Steves-MacBook-Pro:scripts sjj$
```
* `scripts/start_hosts.sh`: This script can be used to start all the EC2 instances
that are correcty tagged as part of the cluster. It's best to not tag the AD instance
for now and just use this to start the Linux hosts. Due to the way AWS configures
DNS settings on startup of EC2 instances you need to run the following ansible playbook
after the hosts boot to point their DNS back to the AD server:
```bash
ansible-playbook ansible/fix_dns.yml
```
* `scripts/stop_hosts.sh`: The reverse of the start script.
