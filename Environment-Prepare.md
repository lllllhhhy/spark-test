

### Environment Prepare

#### Java 8

```bash
# Note that the VM enviroment is:
[root@vm-localhost ~]# cat /etc/os-release
NAME=Fedora
VERSION="33 (Server Edition)"
ID=fedora
VERSION_ID=33
VERSION_CODENAME=""
PLATFORM_ID="platform:f33"
PRETTY_NAME="Fedora 33 (Server Edition)"
ANSI_COLOR="0;38;2;60;110;180"
LOGO=fedora-logo-icon
CPE_NAME="cpe:/o:fedoraproject:fedora:33"
HOME_URL="https://fedoraproject.org/"
DOCUMENTATION_URL="https://docs.fedoraproject.org/en-US/fedora/f33/system-administrators-guide/"
SUPPORT_URL="https://fedoraproject.org/wiki/Communicating_and_getting_help"
BUG_REPORT_URL="https://bugzilla.redhat.com/"
REDHAT_BUGZILLA_PRODUCT="Fedora"
REDHAT_BUGZILLA_PRODUCT_VERSION=33
REDHAT_SUPPORT_PRODUCT="Fedora"
REDHAT_SUPPORT_PRODUCT_VERSION=33
PRIVACY_POLICY_URL="https://fedoraproject.org/wiki/Legal:PrivacyPolicy"
VARIANT="Server Edition"
VARIANT_ID=server
-----------------------------------------------------------------------------------------
# we use java 8 here
[root@vm-localhost ~]# java -version
openjdk version "11.0.13" 2021-10-19
OpenJDK Runtime Environment 18.9 (build 11.0.13+8)
OpenJDK 64-Bit Server VM 18.9 (build 11.0.13+8, mixed mode, sharing)
# as we can see，the java version is 11
# we are prefer to use java 8. In my test, Java 8 is all good. Java 11 maybe work(I have     not tried.)
# so here remove it and install java 8.

1. First check the JDK and uninstall it if it is not java 8

[root@vm-localhost ~]# rpm -qa | grep java

javapackages-filesystem-5.3.0-13.fc33.noarch
tzdata-java-2021e-1.fc33.noarch
java-11-openjdk-headless-11.0.13.0.8-2.fc33.x86_64
java-11-openjdk-11.0.13.0.8-2.fc33.x86_64

# unintall them.
[root@vm-localhost ~]# rpm -e --allmatches --nodeps java-11-openjdk-headless-11.0.13.0.8-2.fc33.x86_64
[root@vm-localhost ~]# rpm -e --allmatches --nodeps java-11-openjdk-11.0.13.0.8-2.fc33.x86_64

2. search it and install the right version

[root@vm-localhost ~]# yum search jdk
# it will display something like that:
 - java-1.8.0-openjdk-devel.x86_64 : OpenJDK 8 Development Environment # JDK
 - java-11-openjdk-devel.x86_64 : OpenJDK 11 Development Environment # JDK
 - java-latest-openjdk-devel.x86_64 : OpenJDK 17 Development Environment #JDK
# install the java 8
[root@vm-localhost ~]# yum install java-1.8.0-openjdk-devel.x86_64
# check it using java -version:
[root@vm-localhost jvm]# java -version
openjdk version "1.8.0_312" # done !
OpenJDK Runtime Environment (build 1.8.0_312-b07)
OpenJDK 64-Bit Server VM (build 25.312-b07, mixed mode)


3. because hadoop need the configuration JAVA_HOME,so configure it
# find where java is installed using java -verbose
# the last two lines will tell you answer.
[root@vm-localhost jvm]# java -verbose 
# last two lines is something like this:
[Loaded java.lang.Shutdown from /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.312.b07-2.fc33.x86_64/jre/lib/rt.jar]
[Loaded java.lang.Shutdown$Lock from /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.312.b07-2.fc33.x86_64/jre/lib/rt.jar]
-----------------------------------------------------------------------------------------
# as we can see above, we come to the directory  ---> /usr/lib/jvm
[root@vm-localhost jvm]# pwd
/usr/lib/jvm
[root@vm-localhost jvm]# ll
total 0
lrwxrwxrwx. 1 root root  26 Jan 10 13:46 java -> /etc/alternatives/java_sdk
lrwxrwxrwx. 1 root root  32 Jan 10 13:46 java-1.8.0 -> /etc/alternatives/java_sdk_1.8.0
lrwxrwxrwx. 1 root root  40 Jan 10 13:46 java-1.8.0-openjdk -> /etc/alternatives/java_sdk_1.8.0_openjdk
drwxr-xr-x. 7 root root 135 Jan 10 13:46 java-1.8.0-openjdk-1.8.0.312.b07-2.fc33.x86_64
lrwxrwxrwx. 1 root root  34 Jan 10 13:46 java-openjdk -> /etc/alternatives/java_sdk_openjdk
lrwxrwxrwx. 1 root root  21 Jan 10 13:46 jre -> /etc/alternatives/jre
lrwxrwxrwx. 1 root root  27 Jan 10 13:46 jre-1.8.0 -> /etc/alternatives/jre_1.8.0
lrwxrwxrwx. 1 root root  35 Jan 10 13:46 jre-1.8.0-openjdk -> /etc/alternatives/jre_1.8.0_openjdk
lrwxrwxrwx. 1 root root  50 Nov  9 03:06 jre-1.8.0-openjdk-1.8.0.312.b07-2.fc33.x86_64 -> java-1.8.0-openjdk-1.8.0.312.b07-2.fc33.x86_64/jre
lrwxrwxrwx. 1 root root  29 Jan 10 13:46 jre-openjdk -> /etc/alternatives/jre_openjdk

# most importantly, java-1.8.0-openjdk will entually soft-link to 
# java-1.8.0-openjdk-1.8.0.312.b07-2.fc33.x86_64(the true directory where java is installed)

# so we can just use java-1.8.0-openjdk to point to the true directory.
-----------------------------------------------------------------------------------------
# configure it:
[root@vm-localhost scala-2.12.15]# vim /root/.bashrc
# add the following into the file:
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
export JRE_HOME=$JAVA_HOME/jre
export CLASSPATH=.:$JAVA_HOME/lib:$JRE_HOME/lib
export PATH=$PATH:$JAVA_HOME/bin

# to take effect immediately, run below:
[root@vm-localhost scala-2.12.15]# source /root/.bashrc
```

#### scala 

```bash
# install the Scala 2.12.15
# the base directory here is /root/software
# the hadoop will be installed in subfolder of the base directory
1. visit the website below looking for version 2.12.15 and download it
	https://www.scala-lang.org/download/all.html
	
2. get the download url and download in your VM
[root@vm-localhost software]# wget https://downloads.lightbend.com/scala/2.12.15/scala-2.12.15.tgz

3. unpack the scala-2.12.15.tgz
[root@vm-localhost software]# tar -zxvf scala-2.12.15.tgz

4. Configure environment variables SCALA_HOME 
[root@vm-localhost scala-2.12.15]# vim /root/.bashrc
# add the following into the file:
export SCALA_HOME=/root/software/scala-2.12.15
export PATH=$SCALA_HOME/bin:$PATH

5. check if install successfully
[root@vm-localhost scala-2.12.15]# source /root/.bashrc
[root@vm-localhost scala-2.12.15]# scala -version
- Scala code runner version 2.12.15 -- Copyright 2002-2021, LAMP/EPFL and Lightbend, Inc.

```

#### hadoop 

```bash
# install Hadoop 3.2.3
# the base directory here is /root/software
# the hadoop will be installed in subfolder of the base directory
1. visit the website below looking for your specific Hadoop download URL:
  https://hadoop.apache.org/releases.html
  
2. download it
[root@vm-localhost software]# wget https://dlcdn.apache.org/hadoop/common/hadoop-3.2.3/hadoop-3.2.3.tar.gz

3. unpack the hadoop-3.2.3.tar.gz
[root@vm-localhost software]# tar -zxvf hadoop-3.2.3.tar.gz

4. Configure environment variables HADOOP_HOME

[root@vm-localhost scala-2.12.15]# vim /root/.bashrc
# add the following into the file:
export HADOOP_HOME=/root/software/hadoop-3.2.3
export PATH=$HADOOP_HOME/bin:$PATH

5. check if install successfully

[root@vm-localhost jvm]# hadoop version

Hadoop 3.2.3
Source code repository Unknown -r 7a3bc90b05f257c8ace2f76d74264906f0f7a932
Compiled by hexiaoqiao on 2021-01-03T09:26Z
Compiled with protoc 2.5.0
From source with checksum 5a8f564f46624254b27f6a33126ff4
This command was run using /root/software/hadoop-3.2.3/share/hadoop/common/hadoop-common-3.2.3.jar

# done 

```

#### spark

```bash
# install spark 3.0.3
# the base directory here is /root/software
# the hadoop will be installed in subfolder of the base directory

1. visit the website below looking for your specific spark download URL:
  https://spark.apache.org/downloads.html
  
2. download it
[root@vm-localhost software]# wget https://dlcdn.apache.org/spark/spark-3.0.3/spark-3.0.3-bin-hadoop3.2.tgz

3. unpack the spark-3.0.3-bin-hadoop3.2.tgz
[root@vm-localhost software]# tar -zxvf spark-3.0.3-bin-hadoop3.2.tgz

4. Configure environment variables SPARK_HOME

[root@vm-localhost scala-2.12.15]# vim /root/.bashrc
# add the following into the file:
export SPARK_HOME=/root/software/spark-3.0.3-bin-hadoop3.2
export PATH=$SPARK_HOME/bin:$PATH

5. check if install successfully

[root@vm-localhost jvm]# spark-shell
# something like below means success !
Spark session available as 'spark'.
Welcome to
      ____              __
     / __/__  ___ _____/ /__
    _\ \/ _ \/ _ `/ __/  '_/
   /___/ .__/\_,_/_/ /_/\_\   version 3.0.3
      /_/
         
Using Scala version 2.12.10 (OpenJDK 64-Bit Server VM, Java 1.8.0_312)
Type in expressions to have them evaluated.
Type :help for more information.

# install done 
-----------------------------------------------------------------------------------------
6. set spark configuration
# set spark configuration --> /root/software/spark-3.0.3-bin-hadoop3.2/conf/
vim spark-defaults.conf # create the named file, add lines below into it
spark.default.parallelism 30
spark.sql.shuffle.partition 30

# set spark configuration --> /root/software/spark-3.0.3-bin-hadoop3.2/conf/
vim spark-env.sh # create the named file, add lines below into it
 # you can find it in java install part
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
 # where hadoop conf locates
export HADOOP_CONF_DIR=/root/software/hadoop-3.2.3/etc/hadoop




```

#### figure out something about the VM

```bash
[root@vm-localhost spark-disk-test]# cat /proc/cpuinfo| grep "physical id"| sort| uniq| wc -l
- CPU cores 4

[root@vm-localhost spark-disk-test]# lsblk

NAME                   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                      8:0    0   20G  0 disk 
├─sda1                   8:1    0    1G  0 part /boot
└─sda2                   8:2    0   19G  0 part 
  └─fedora_fedora-root 253:0    0   15G  0 lvm  /
sr0                     11:0    1 1024M  0 rom  
zram0                  251:0    0    4G  0 disk [SWAP]
vda                    252:0    0 12.5T  0 disk  # we use this disk

- vda disk free 12.5T
-------------------------------  Disk /dev/vda  Mount  ---------------------------------
# format the disk first
sudo mkfs -t xfs -K -f /dev/vda

# Create a directory(here we name it to hdfs-fast) waiting to be mounted.
sudo mkdir /hdfs-fast
sudo chmod 777 /hdfs-fast

# mount the dir to the specific disk 
mount /dev/vda /hdfs-fast

# check the UUID of /dev/vda
blkid 
/dev/sda1: UUID="f84c0923-418d-456b-b96e-376df243749c" BLOCK_SIZE="512" TYPE="xfs" PARTUUID="23985d9d-01"
/dev/sda2: UUID="6iZoZx-em10-ewL1-nDew-Bs3u-fa6G-kZZXlE" TYPE="LVM2_member" PARTUUID="23985d9d-02"
/dev/mapper/fedora_fedora-root: UUID="5bc924cd-0bb1-4c01-81a4-f09f28b46901" BLOCK_SIZE="512" TYPE="xfs"
/dev/zram0: UUID="301ede80-2a12-486d-9b0a-6b80e0cb560f" TYPE="swap"
/dev/vda: UUID="d0e81a20-c6df-4812-af0e-8c845d738cff" BLOCK_SIZE="4096" TYPE="xfs"

# save something into the fstab in order to take effects even though reboot.
vim /etc/fstab
# add the following:
UUID=d0e81a20-c6df-4812-af0e-8c845d738cff /boot       xfs     defaults        0 0

# check whether added line is OK
sudo mount -a
-----------------------------------------------------------------------------------------

[root@vm-localhost ~]# free
              total        used        free      shared  buff/cache   available
Mem:       52441944      326792    48109060         908     4006092    51550196
Swap:       4194300           0     4194300

- memory available: 51550196/1024/104= 4.9GB

-----------------------------------------------------------------------------------------
```

### quick start

```bash
In a nutshell the recources are listed below:
# few CPU core and 4.9GB memory. It is hard to test the best performance of the disk
 - disk 12.5T
 - memory 4.9 GB
 - core 4

So in Spark-Test-Disk-Guide.md 
We can change something in Benchmark_Parameters.sh according to our VM:
# in ./Benchmark_Parameters.sh  -- contains all the parameters that you can change.

SPARK_DRIVER_MEMORY=1g
SPARK_EXECUTOR_MEMORY=2g
# maybe (1.0-2.0)*your CPU Cores.
SPARK_EXECUTOR_CORES=8 
# local[num] --> the num means the  number of CPU core used in local mode.
# it is better is keep it similar to `SPARK_EXECUTOR_CORES`
SPARK_MASTER_URL="local[8]"

# Then everything is ready Now !
# Enjoy it !
# more information about how to run the spark-program will be seen in Spark-Test-Disk-     Guide.md 
# fast-start is below: 

- * * suppposed you have run this: cd /root/spark-disk-test * *

-----------------------------------------------------------------------------------------
our spark program is at `/root/spark-disk-test`

[root@vm-localhost spark-disk-test]# pwd
  /root/spark-disk-test
[root@vm-localhost spark-disk-test]# ls
   - Benchmark_Parameters.sh # load some running parameter.
   - HS-finalVersion.jar     # commad entrance to test the disk.
   - HS-fullVersion.sh       # the jar file where the compiled .class files are packed.
   - VERSION.txt             # test-kit version
   
 1. you can run it with following command at directory `/root/spark-disk-test`
    - ./HS-fullVersion.sh -w -g 1 # write with hadoop API.
    - ./HS-fullVersion.sh -r -g 1 # read with hadoop API.
    - ./HS-fullVersion.sh -s -g 1 # write and read with Hadoop API.
    - ./HS-fullVersion.sh -c -g 1 # checkpoint data to disk.
    - ./HS-fullVersion.sh -p -g 1 # persist(DISK_ONLY) data to disk.
    
 2. when the spark program is running. you can use some commands 
    to Monitor disk read /write performance
    - blktrace -d /dev/vda -o - | blkparse  -i - # disk
    - strace   # monitor system call
    - iostat -xmd /dev/vda 1 # disk IO
    
```









