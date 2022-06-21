# **Spark-Test-Disk  Guide**

### Test Kit

```bash
here is all the files included to test the disk.

- Benchmark_Parameters.sh # load some running parameter.
- HS-fullVersion.sh # commad entrance to test the disk.
- HS-finalVersion.jar # the jar file where the compiled .class files are packed.
- VERSION.txt # test-kit version

these files will be attached with this Spark-test-disk-guide.md
```



### Prepare Running Environment

```shell
1. before you can test spark programs. Be sure you have prepared the environment below:
 - java 8
 - Scala 2.12.15 or scala 2.12.x
 - Hadoop 3.2.2
 - spark 3.0.3
-----------------------------------------------------------------------------------------
2. you are advised to mount your disk to the base direcory before testing. it is advised to mount a high-speed disk to a directory as base-directory exclussively. And the disk is only used for spark programs to write/read(Avoiding the impact of other unrelative programs on such disk)

# in my test. The directory is mount on /dev/sda3

root@smfast:/hdfs-fast# df /hdfs-fast
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/sda3      232766464 39028732 193238004  17% /

# the hdfs-fast is the base-directory,the sub-directory is listed below:
# **ATTENTION: the base-directory is only needed to created manually while the sub-direcory will generated automatically. **

root@smfast:/hdfs-fast# ll

# checkpoint data is stored here
drwxr-xr-x. 1 root root  144 Jan  9 14:20 checkpointdir/ 
# write/read data to/from disk with hadoop API
drwxr-xr-x. 1 root root 2942 Jan  9 14:28 input/ 
# first read the data from the input directory then sort them in momory, Lastly write the sorted data to such output directory`output`. This part is used to test the write and read performance together.
drwxr-xr-x. 1 root root 2942 Jan  9 14:33 output/
# the `persistdir` is used to persist data in disk Temporarily. The data will be removed when all the tasks are done while in checkpoint mode the data will not removed.
drwxr-xr-x. 1 root root    0 Jan  9 14:24 persistdir/

it is showed below in a more clear way:
/dev/sda3 --
            |-- /hdfs-fast --
                             |-- checkpointdir
                             |-- input
                             |-- output
                             |-- persistdir

```

### Test Procedure

#### Modify Environment Parameter 

```bash
# in ./Benchmark_Parameters.sh  -- contains all the parameters that you can change.

#----------------------------------- you should change them according your linux machine.
# the base directory mentioned above. Be sure it is mounted on specific disk.
FILE_BASE=hdfs-fast
# be sure `SPARK_DRIVER_MEMORY` + `SPARK_EXECUTOR_MEMORY` < your available memory
SPARK_DRIVER_MEMORY=3g
SPARK_EXECUTOR_MEMORY=12g
# maybe (1.0-2.0)*your CPU Cores.
SPARK_EXECUTOR_CORES=40 
# local[num] --> the num means the  number of CPU core used in local mode.
# it is better is keep it similar to `SPARK_EXECUTOR_CORES`
SPARK_MASTER_URL="local[40]"

#----------------------------------- you can change them if you would like to.
CHECKPOINTDIR="checkpointdir"
PERSISTDIR="persistdir"
INPUTDIR="input"
OUTPUTDIR="output"
 # change it if you need.
YOUR_FILE_SIZE="#"
# change it if you need.
YOUR_PREFIX="#"
# when it is -1, use the `local[num]` num as partition, otherwise use the given value
YOUR_TEMPORARY_PARTITION=-1 
#----------------------------------- maybe keep them unchanged.
# keep it unchanged in local mode.
SPARK_EXECUTOR_INSTANCES=1
# DEPLOY_MODE one of 'cluster' or 'client'
SPARK_DEPLOY_MODE="client"
# the jar file containing the Main class.
HSFullVersion_JAR="HS-finalVersion.jar"


```

**In addition, because the default parallelism will be used in the spark program, we can set it when configuring the spark environment. In the local mode. If not set, it will be consistent with the number of CPU cores of all executors. In my environment, I set 120.** 

```bash
# root@smfast:/usr/local/spark-3.0.3/conf# vim spark-defaults.conf

spark.master spark://sm153:7077
spark.yarn.am.waitTime 300
spark.yarn.submit.file.replication 3
spark.default.parallelism 120 # here
spark.sql.shuffle.partition 120
```



```bash
# in HS-fullVersion.sh. 
#the below part is mentioned because you may be confused by the hsszize.
# for exmaple the hhssize=10000000 means 1GB. Why?
it is calculated followed: 
- 1. CalculatedSize=10000000/1000/1000/1000=0.01Gb

- 2. and in program it will be produced ActualSize = 100*CalculatedSize Gb = 1Gb

- 3. So you just give the parameter by ActualSize/100.

                         case $sze in
                                1) hssize="10000000"
                                   prefix="1GB"
                                     ;;
                                2) hssize="50000000"
                                   prefix="5GB"

                                3) hssize="100000000"
                                   prefix="10GB"
                                         ;;
                                4) hssize="200000000"
                                   prefix="20GB"
                                         ;;
                                5) hssize="300000000"
                                   prefix="30GB"
                                         ;;
                                6) hssize="400000000"
                                   prefix="40GB"
                                         ;;
                                7) hssize="500000000"
                                   prefix="50GB"
                                         ;;
                                8) hssize="1000000000"
                                   prefix="100GB"
                                         ;;
                                9) hssize="1500000000"
                                   prefix="150GB"
                                         ;;
                                10) hssize="200000000"
                                   prefix="200GB"
                                         ;;  
  if the above default hssize does not satisfy your need, you can use your own parameter by 
  change the below parameter in Benchmark_Parameters.sh :
  # ** Pay attention to the calculation of file size. **
  - example:
      YOUR_FILE_SIZE="80000000"
      YOUR_PREFIX="8GB"
```



#### HSGen

```shell
========================================HSGen============================================
# main class: HSGen
# function: test the disk write performance with hadoop API
# fucntion parameter:
   - file size (unit B)
   - the number of tasks to write data to disk in parallel. if -1 use the 	                  `defaultParallelism` otherwise use the given one. 
   - the directory where the data is written.

# just run the command:  -g Specifies the file size level
  ./HS-fullVersion.sh -w -g 3
  
```



#### HSRead

```bash
========================================HSRead===========================================
# main class: HSRead
# function: test the disk read performance with hadoop API
# fucntion parameter:
 - the directory from which the data is read.
 
# just run the command:  -g Specifies the file size level
  ./HS-fullVersion.sh -r -g 3
```

#### HSSort

```bash
========================================HSSort===========================================
# main class: HSSort
# function: test the disk write and read performance with hadoop API
# fucntion parameter:
 - the directory from which the data is read.
 - the directory to which the data is written.
 
# just run the command: -g Specifies the file size level
  ./HS-fullVersion.sh -s -g 3
```

#### HSCheckpoint

```bash
========================================HSCheckpoint=====================================
# main class: HSCheckpoint
# function: test the disk write when checkpoint happens.
# fucntion parameter:
   - file size (unit B)
   - the number of tasks to write checkpoint data to disk in parallel. if -1 use the 	      `defaultParallelism` otherwise use the given one. 
   - the directory where the checkpoint data is written.It will still exist when tasks         are done.
 
# just run the command: -g Specifies the file size level
  ./HS-fullVersion.sh -c -g 3
```

#### HSPersistToDisk

```bash

========================================HSPersistToDisk==================================
# main class: HSPersistToDisk
# function: test the disk write when persit(DISK_ONLY) happens.
# fucntion parameter:
   - file size (unit B)
   - the number of tasks to persit data in parallel. if -1 use the 	      	                  `defaultParallelism` otherwise use the given one. 
   - the directory where the persist data is written. It will be removed when tasks             are done.

# just run the command: -g Specifies the file size level
  ./HS-fullVersion.sh -p -g 3
```



### HS-fullVersion.sh Shell File

```bash
#!/bin/bash
#########################################################################################
#                              in ./HS-fullVersion.sh 
#########################################################################################
shopt -s expand_aliases
source ./Benchmark_Parameters.sh

VERSION=`cat ./VERSION.txt`
# Setting Color codes
green='\e[0;32m'
red='\e[0;31m'
NC='\e[0m' # No Color

sep='==================================='

usage()
{
cat << EOF
TPCx-HS version $VERSION 
usage: $0 options

This script runs the TPCx-HS (Hadoop Sort) BigData benchmark suite

OPTIONS:
   -h  Help
   -g  <TPCx-HS Scale Factor option from below>
       1   Run TPCx-HS for 1GB (For test purpose only, not a valid Scale Factor)
       2   Run TPCx-HS for 5GB
       3   Run TPCx-HS for 10GB
       4   Run TPCx-HS for 20GB
       5   Run TPCx-HS for 30GB
       6   Run TPCx-HS for 40GB
       7   Run TPCx-HS for 50GB
       8   Run TPCx-HS for 100GB
       9   Run TPCx-HS for 200GB
       10  Run TPCx-HS for 250GB

   Example: $0 -g 1

EOF
}

while getopts "hwrscpg:" OPTION; do
     case ${OPTION} in
         h) usage
             exit 1
             ;;

         w) MAINCLASS="HSGen"
             ;;
         r) MAINCLASS="HSRead"
             ;;
         s) MAINCLASS="HSSort"
             ;;
         c) MAINCLASS="HSCheckpoint"
             ;;
         p) MAINCLASS="HSPersistToDisk"
             ;;

         g)  sze=$OPTARG
 			 case $sze in
				1) hssize="10000000"
				   prefix="1GB"
				     ;;
				2) hssize="50000000"
				   prefix="5GB"
					 ;;
				3) hssize="100000000"
				   prefix="10GB"
					 ;;	
				4) hssize="200000000"
				   prefix="20GB"
					 ;;	
				5) hssize="300000000"
				   prefix="30GB"
					 ;;	
				6) hssize="400000000"
				   prefix="40GB"
					 ;;	
				7) hssize="500000000"
				   prefix="50GB"
					 ;;	
				8) hssize="1000000000"
				   prefix="100GB"
					 ;;	
				9) hssize="1500000000"
				   prefix="150GB"
					 ;;	
				10) hssize="200000000"
				   prefix="200GB"
					 ;;						 					       
				?) hssize="50000000"
				   prefix="5GB"
				   ;;
			 esac
             ;;
         ?)  echo -e "${red}Please choose a vlaid option${NC}"
             usage
             exit 2
             ;;
    esac
done

echo -e "${green}- Starting ${MAINCLASS} Run ${NC}"
echo -e "${green}-- MAINCLASS: ${MAINCLASS} ${NC}"

if [ -z "$hssize" ]; then
    echo
    echo -e "${red}Please specify the scale factor to use (-g)${NC}"
    echo
    usage
    exit 2
fi

if [ "$YOUR_FILE_SIZE" != "#" ];then
   echo  -e "${green}use your own file size : ${YOUR_FILE_SIZE} ${NC}"
   echo  -e "${green}use your own prefix    : ${YOUR_PREFIX} ${NC}"
   hssize="$YOUR_FILE_SIZE"
   prefix="${YOUR_PREFIX}"
fi

if [ "$MAINCLASS" == "HSGen" ];then
    #创建保存数据的目录
    sudo mkdir -p /"${FILE_BASE}"/"${INPUTDIR}"
    ls /"${FILE_BASE}"/"${INPUTDIR}"/*
    if [ $? != 0 ] ;then
    sudo rm -rf /"${FILE_BASE}"/"${INPUTDIR}"/*
    fi
(time spark-submit --class ${MAINCLASS} --deploy-mode ${SPARK_DEPLOY_MODE} --master ${SPARK_MASTER_URL} --conf "spark.driver.memory=${SPARK_DRIVER_MEMORY}" --conf "spark.executor.memory=${SPARK_EXECUTOR_MEMORY}"  --conf "spark.executor.cores=${SPARK_EXECUTOR_CORES}" --conf "spark.executor.instances=${SPARK_EXECUTOR_INSTANCES}" ${HSFullVersion_JAR} ${hssize} "${YOUR_TEMPORARY_PARTITION}" /"${FILE_BASE}"/"${INPUTDIR}") 2>&1 
    ls /"${FILE_BASE}"/"${INPUTDIR}"/*
    result=$?
elif [ "$MAINCLASS" == "HSRead" ];then
    ls /"${FILE_BASE}"/"${INPUTDIR}"/*
    if [ $? != 0 ] ;then
        echo "no input file please run the HSGen first"
        exit 2
    fi
    (time spark-submit --class ${MAINCLASS} --deploy-mode ${SPARK_DEPLOY_MODE} --master ${SPARK_MASTER_URL} --conf "spark.driver.memory=${SPARK_DRIVER_MEMORY}" --conf "spark.executor.memory=${SPARK_EXECUTOR_MEMORY}"  --conf "spark.executor.cores=${SPARK_EXECUTOR_CORES}" --conf "spark.executor.instances=${SPARK_EXECUTOR_INSTANCES}" ${HSFullVersion_JAR} /"${FILE_BASE}"/"${INPUTDIR}") 2>&1 
    result=0
elif [ "$MAINCLASS" == "HSSort" ];then
    ls /"${FILE_BASE}"/"${INPUTDIR}"/*
    if [ $? != 0 ] ;then
        echo -e "no input file please run the HSGen first"
        exit 2
    fi
    sudo mkdir -p /"${FILE_BASE}"/"${OUTPUTDIR}"
    ls /"${FILE_BASE}"/"${OUTPUTDIR}"/*
    if [ $? != 0 ] ;then
    sudo rm -rf /"${FILE_BASE}"/"${OUTPUTDIR}"/*
    fi
    (time spark-submit --class ${MAINCLASS} --deploy-mode ${SPARK_DEPLOY_MODE} --master ${SPARK_MASTER_URL} --conf "spark.driver.memory=${SPARK_DRIVER_MEMORY}" --conf "spark.executor.memory=${SPARK_EXECUTOR_MEMORY}"  --conf "spark.executor.cores=${SPARK_EXECUTOR_CORES}" --conf "spark.executor.instances=${SPARK_EXECUTOR_INSTANCES}" ${HSFullVersion_JAR} /"${FILE_BASE}"/"${INPUTDIR}" /"${FILE_BASE}"/"${OUTPUTDIR}" ${part}) 2>&1 
    ls  /"${FILE_BASE}"/"${OUTPUTDIR}"/*
    result=$?
elif [ "$MAINCLASS" == "HSCheckpoint" ];then
    echo -e "${green}it just generate data in memory and store it in disk by checkpoint${NC}"
    if [ ! -d /"${FILE_BASE}"/"${CHECKPOINTDIR}" ]; then
        sudo mkdir -p /"${FILE_BASE}"/"${CHECKPOINTDIR}"
    fi
    sudo rm -rf /"${FILE_BASE}"/"${CHECKPOINTDIR}"/*
    (time spark-submit --class ${MAINCLASS} --deploy-mode ${SPARK_DEPLOY_MODE} --master ${SPARK_MASTER_URL} --conf "spark.driver.memory=${SPARK_DRIVER_MEMORY}" --conf "spark.executor.memory=${SPARK_EXECUTOR_MEMORY}"  --conf "spark.executor.cores=${SPARK_EXECUTOR_CORES}" --conf "spark.executor.instances=${SPARK_EXECUTOR_INSTANCES}" ${HSFullVersion_JAR} ${hssize} "${YOUR_TEMPORARY_PARTITION}" /"${FILE_BASE}"/"${CHECKPOINTDIR}") 2>&1 
    ls /"${FILE_BASE}"/"${CHECKPOINTDIR}"/*
    result=$?
elif [ "$MAINCLASS" == "HSPersistToDisk" ];then
    echo -e  "${green}it just generate data in memory and persist it in disk. It will be deleted after the tasks are  finished${NC}"
    if [ ! -d /"${FILE_BASE}"/"${PERSISTDIR}" ]; then
        sudo mkdir -p /"${FILE_BASE}"/"${PERSISTDIR}"
    fi
    (time spark-submit --class ${MAINCLASS} --deploy-mode ${SPARK_DEPLOY_MODE} --master ${SPARK_MASTER_URL} --conf "spark.driver.memory=${SPARK_DRIVER_MEMORY}" --conf "spark.executor.memory=${SPARK_EXECUTOR_MEMORY}"  --conf "spark.executor.cores=${SPARK_EXECUTOR_CORES}" --conf "spark.executor.instances=${SPARK_EXECUTOR_INSTANCES}" ${HSFullVersion_JAR} ${hssize} "${YOUR_TEMPORARY_PARTITION}" /"${FILE_BASE}"/"${PERSISTDIR}") 2>&1 
   result=0

else 
    echo -e  "${red}no Main class matched , exit !${NC}"
    exit 2
fi
echo -e "${green}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++${NC}"

if [ "$result" -ne 0 ];then
echo -e "${red}======== ${MAINCLASS}  FAILURE ========${NC}"

else
echo -e "${green}========  "${MAINCLASS}" SUCCESS =============${NC}"
echo -e "${green} ${VERSION} ${NC}"
fi

```

### Tips

>1. The steps above can make you clear how to run the shell to start the spark programs to test the disk:
>
>```bash
>- ./HS-fullVersion.sh -w -g 1 # write with hadoop API.
>- ./HS-fullVersion.sh -r -g 1 # read with hadoop API.
>- ./HS-fullVersion.sh -s -g 1 # write and read with Hadoop API.
>- ./HS-fullVersion.sh -c -g 1 # checkpoint data to disk.
>- ./HS-fullVersion.sh -p -g 1 # persist(DISK_ONLY) data to disk.
>```
>
>2. when the spark program is running. you can use some commands to Monitor disk read / write performance
>
>   ```bash
>   - blktrace # disk
>   - strace   # monitor system call
>     - iostat -xmd /dev/sda3 1
>   ```
>
>   tips:  the tests below use ：
>
>   1.  hssize=10Gb
>   2. spark.default.parallelism=120  # spark default conf
>
>   



### Disk Monitor

```bash
# some tips recorded:

# A remap 对于栈式设备，进来的I/O将被重新映射到I/O栈中的具体设备
# X split 对于做了Raid或进行了device mapper(dm)的设备，进来的IO可能需要切割，然后发送给不同的设备
# Q queued I/O进入block layer，将要被request代码处理（即将生成IO请求）
# G get request I/O请求（request）生成，为I/O分配一个request 结构体。
# M back merge 之前已经存在的I/O request的终止block号，和该I/O的起始block号一致，就会合并。也就是向     后合并
# F front merge 之前已经存在的I/O request的起始block号，和该I/O的终止block号一致，就会合并。也就是     向前合并
# I inserted I/O请求被插入到I/O scheduler队列
# S sleep 没有可用的request结构体，也就是I/O满了，只能等待有request结构体完成释放
# P plug 当一个I/O入队一个空队列时，Linux会锁住这个队列，不处理该I/O，这样做是为了等待一会，看有没有新的     I/O进来，可以合并
# U unplug 当队列中已经有I/O request时，会放开这个队列，准备向磁盘驱动发送该I/O。
    #这个动作的触发条件是：超时（plug的时候，会设置超时时间）；或者是有一些I/O在队列中（多于1个I/O）
# D issued I/O将会被传送给磁盘驱动程序处理
# C complete I/O处理被磁盘处理完成。

#也就是说一个IO可以大致分为 A-Q-G-P(可以没有)-I-U(可以没有)-D-C，即
# 在磁盘密集型操作时可能是这样的 A-Q-G-I-D-C
```



#### Hadoop API File Write - Disk Monitor

```bash
-----------------------------------------------------------------------------------------
# monitor your mounted disk 
# here my disk is /dev/sda3
##  blktrace -d /dev/sda3 -o - | blkparse  -i -
# output is listed below:
# Because multitasking writes are involved, it's random writes 
   8,0    2      929    86.167266270   927  A WSM 5864096 + 96 <- (8,3) 2536096
  8,3    2      930    86.167266850   927  Q WSM 5864096 + 96 [btrfs-transacti]
  8,3    2      931    86.167270075   927  G WSM 5864096 + 96 [btrfs-transacti]
  8,3    2      932    86.167270279   927  U   N [btrfs-transacti] 1
  8,3    2      933    86.167270735   927  I WSM 5863776 + 288 [btrfs-transacti]
  8,3    2      934    86.167278597   927  D WSM 5863776 + 288 [btrfs-transacti]
  8,3    2      935    86.167286131   927  P   N [btrfs-transacti]
  8,0    2      936    86.167598227   927  A WSM 5864896 + 352 <- (8,3) 2536896
  8,3    2      937    86.167598440   927  Q WSM 5864896 + 352 [btrfs-transacti]
  8,3    2      938    86.167600709   927  G WSM 5864896 + 352 [btrfs-transacti]
  8,0    2      939    86.167782457   927  A WSM 5865568 + 160 <- (8,3) 2537568
  8,3    2      940    86.167782603   927  Q WSM 5865568 + 160 [btrfs-transacti]
  8,3    2      941    86.167784004   927  G WSM 5865568 + 160 [btrfs-transacti]
  8,3    2      942    86.167784193   927  U   N [btrfs-transacti] 2
  8,3    2      943    86.167784297   927  I WSM 5864096 + 96 [btrfs-transacti]
  8,3    2      944    86.167785929   927  I WSM 5864896 + 352 [btrfs-transacti]
  8,3    2      945    86.167789707   927  D WSM 5864096 + 96 [btrfs-transacti]
  8,3    2      946    86.167793902   927  D WSM 5864896 + 352 [btrfs-transacti]
  8,3    2      947    86.167797530   927  P   N [btrfs-transacti]
  8,0    2      948    86.167989424   927  A WSM 5865760 + 192 <- (8,3) 2537760
  8,3    2      949    86.167989549   927  Q WSM 5865760 + 192 [btrfs-transacti]
  8,3    2      950    86.167990644   927  G WSM 5865760 + 192 [btrfs-transacti]
  8,0    2      951    86.168080721   927  A WSM 5866048 + 96 <- (8,3) 2538048
  8,3    2      952    86.168080841   927  Q WSM 5866048 + 96 [btrfs-transacti]
  8,3    2      953    86.168083899   927 UT   N [btrfs-transacti] 2
  8,3    2      954    86.168084009   927  I WSM 5865568 + 160 [btrfs-transacti]
  8,3    2      955    86.168085025   927  I WSM 5865760 + 192 [btrfs-transacti]
  8,3    2      956    86.168095034  1219  D WSM 5865568 + 160 [kworker/2:1H]
  8,3    2      957    86.168106619  1219  D WSM 5865760 + 192 [kworker/2:1H]
  8,3    2      958    86.168662197   927  G WSM 5866048 + 96 [btrfs-transacti]
  8,3    2      959    86.168663657   927  P   N [btrfs-transacti]
  8,0    2      960    86.168828820   927  A WSM 5867424 + 128 <- (8,3) 2539424
  8,3    2      961    86.168829351   927  Q WSM 5867424 + 128 [btrfs-transacti]
  8,3    2      962    86.168835406   927 UT   N [btrfs-transacti] 1
  8,3    2      963    86.168835890   927  I WSM 5866048 + 96 [btrfs-transacti]
  8,3    2      964    86.168851026  1219  D WSM 5866048 + 96 [kworker/2:1H]
  8,3   12    17531    86.198445709     0  C WSM 7215680 + 2032 [0]
  8,3   12    17532    86.199564914     0  C WSM 7217712 + 560 [0]
  8,3   12    17533    86.200363169     0  C WSM 7218304 + 224 [0]
  8,3   12    17534    86.201711921     0  C WSM 7218688 + 576 [0]
  8,3   12    17535    86.201996182     0  C WSM 7219392 + 192 [0]
  8,3   12    17536    86.204122801     0  C WSM 7219616 + 672 [0]
  8,3   12    17537    86.204236995    71  C WSM 7220320 + 128 [0]
  8,3   12    17538    86.210741117     0  C WSM 7220480 + 2272 [0]
  8,3   12    17539    86.211123454     0  C WSM 7222784 + 96 [0]
  8,3   12    17540    86.211297121     0  C WSM 7465984 + 96 [0]
  8,3   12    17541    86.211366921     0  C WSM 7492128 + 32 [0]
  8,3   12    17542    86.211388186   927  C WSM 7492192 + 32 [0]
  8,3   12    17543    86.211736747     0  C WSM 7558880 + 128 [0]
  8,3   12    17544    86.211774420   927  Q FWS [btrfs-transacti]
  8,3   12    17545    86.211776049   927  G FWS [btrfs-transacti]
  8,3   12    17546    86.211780834    73  D  FN [kworker/12:0H]
  8,3   12    17547    86.211818467     0  C  FN 0 [0]
  8,3   12    17548    86.211819060     0  C  WS 0 [0]
  8,0   12    17549    86.211829665   927  A WFSM 3328128 + 8 <- (8,3) 128
  8,3   12    17550    86.211829836   927  Q WFSM 3328128 + 8 [btrfs-transacti]
  8,3   12    17551    86.211830245   927  G WFSM 3328128 + 8 [btrfs-transacti]
  8,3   12    17552    86.211833200    73  D WSM 3328128 + 8 [kworker/12:0H]
  8,0   12    17553    86.211838219   927  A WSM 3459072 + 8 <- (8,3) 131072
  8,3   12    17554    86.211838350   927  Q WSM 3459072 + 8 [btrfs-transacti]
  8,3   12    17555    86.211840208   927  G WSM 3459072 + 8 [btrfs-transacti]
  8,3   12    17556    86.211840629   927  I WSM 3459072 + 8 [btrfs-transacti]
  8,3   12    17557    86.211847702    73  D WSM 3459072 + 8 [kworker/12:0H]
  8,3   12    17558    86.211885349     0  C WSM 3328128 + 8 [0]
  8,3   12    17559    86.211892580    73  D  FN [kworker/12:0H]
  8,3   12    17560    86.211893795    73  R  FN 0 [0]
  8,3   12    17561    86.212025184     0  C WSM 3459072 + 8 [0]
  8,3   12    17562    86.212044602    73  D  FN [kworker/12:0H]
  8,3   12    17563    86.212177929     0  C  FN 0 [0]
  8,3   12    17564    86.212179870     0  C WSM 3328128 [0]
  8,0   45        1    87.046634642 2342076  A   W 94916328 + 29280 <- (8,3) 91588328
  8,3   45        2    87.046636677 2342076  Q   W 94916328 + 29280 [kworker/u128:1]
  8,3   45        3    87.046641793 2342076  X   W 94916328 / 94918888 [kworker/u128:1]
  8,3   45        4    87.046652451 2342076  G   W 94916328 + 2560 [kworker/u128:1]
  8,3   45        5    87.046654222 2342076  I   W 94916328 + 2560 [kworker/u128:1]
  8,3   45        6    87.046703402   238  D   W 94916328 + 2560 [kworker/45:0H]
  8,3   45        7    87.046738157 2342076  X   W 94918888 / 94921448 [kworker/u128:1]
  8,3   45        8    87.046740741 2342076  G   W 94918888 + 2560 [kworker/u128:1]
  8,3   45        9    87.046741363 2342076  I   W 94918888 + 2560 [kworker/u128:1]
  8,3   45       10    87.046761628   238  D   W 94918888 + 2560 [kworker/45:0H]
  8,3   45       11    87.046783291 2342076  X   W 94921448 / 94924008 [kworker/u128:1]
  8,3   45       12    87.046785131 2342076  G   W 94921448 + 2560 [kworker/u128:1]
  8,3   45       13    87.046785563 2342076  I   W 94921448 + 2560 [kworker/u128:1]
  8,3   45       14    87.046800733   238  D   W 94921448 + 2560 [kworker/45:0H]
  8,3   45       15    87.046817316 2342076  X   W 94924008 / 94926568 [kworker/u128:1]
  8,3   45       16    87.046819046 2342076  G   W 94924008 + 2560 [kworker/u128:1]
  8,3   45       17    87.046819377 2342076  I   W 94924008 + 2560 [kworker/u128:1]
  8,3   45       18    87.046832751   238  D   W 94924008 + 2560 [kworker/45:0H]
  8,3   45       19    87.046849156 2342076  X   W 94926568 / 94929128 [kworker/u128:1]
  8,3   45       20    87.046850837 2342076  G   W 94926568 + 2560 [kworker/u128:1]
  8,3   45       21    87.046851168 2342076  I   W 94926568 + 2560 [kworker/u128:1]
  8,3   45       22    87.046864588   238  D   W 94926568 + 2560 [kworker/45:0H]
  8,3   45       23    87.046880273 2342076  X   W 94929128 / 94931688 [kworker/u128:1]
  8,3   45       24    87.046881948 2342076  G   W 94929128 + 2560 [kworker/u128:1]
  8,3   45       25    87.046882277 2342076  I   W 94929128 + 2560 [kworker/u128:1]
  8,3   45       26    87.046895517   238  D   W 94929128 + 2560 [kworker/45:0H]
  8,3   45       27    87.046911563 2342076  X   W 94931688 / 94934248 [kworker/u128:1]
  8,3   45       28    87.046913417 2342076  G   W 94931688 + 2560 [kworker/u128:1]
  8,3   45       29    87.046913757 2342076  I   W 94931688 + 2560 [kworker/u128:1]
  8,3   45       30    87.046927446   238  D   W 94931688 + 2560 [kworker/45:0H]
  8,3   45       31    87.046943377 2342076  X   W 94934248 / 94936808 [kworker/u128:1]
  8,3   45       32    87.046945163 2342076  G   W 94934248 + 2560 [kworker/u128:1]
  8,3   45       33    87.046945493 2342076  I   W 94934248 + 2560 [kworker/u128:1]
  8,3   45       34    87.046958353   238  D   W 94934248 + 2560 [kworker/45:0H]
  8,3   45       35    87.046974388 2342076  X   W 94936808 / 94939368 [kworker/u128:1]
  8,3   45       36    87.046976813 2342076  G   W 94936808 + 2560 [kworker/u128:1]
  8,3   45       37    87.046977157 2342076  I   W 94936808 + 2560 [kworker/u128:1]
  8,3   45       38    87.046990248   238  D   W 94936808 + 2560 [kworker/45:0H]
  8,3   45       39    87.047005737 2342076  X   W 94939368 / 94941928 [kworker/u128:1]
  8,3   45       40    87.047007477 2342076  G   W 94939368 + 2560 [kworker/u128:1]
  8,3   45       41    87.047007817 2342076  I   W 94939368 + 2560 [kworker/u128:1]
  8,3   45       42    87.047020791   238  D   W 94939368 + 2560 [kworker/45:0H]
  8,3   45       43    87.047037063 2342076  X   W 94941928 / 94944488 [kworker/u128:1]
  8,3   45       44    87.047039277 2342076  G   W 94941928 + 2560 [kworker/u128:1]
  8,3   45       45    87.047039637 2342076  I   W 94941928 + 2560 [kworker/u128:1]

#########################################################################################
## blktrace -d /dev/sda3
  CPU  0:                37501 events,     1758 KiB data
  CPU  1:                10927 events,      513 KiB data
  CPU  2:                    0 events,        0 KiB data
  CPU  3:                    0 events,        0 KiB data
  CPU  4:                    0 events,        0 KiB data
  CPU  5:                    0 events,        0 KiB data
  CPU  6:                  399 events,       19 KiB data
  CPU  7:                    0 events,        0 KiB data
  CPU  8:                    0 events,        0 KiB data
  CPU  9:                  545 events,       26 KiB data
  CPU 10:                    0 events,        0 KiB data
  CPU 11:                    0 events,        0 KiB data
  CPU 12:               226759 events,    10630 KiB data
  CPU 13:                10924 events,      513 KiB data
  CPU 14:                    0 events,        0 KiB data
  CPU 15:                    0 events,        0 KiB data
  CPU 16:                    0 events,        0 KiB data
  CPU 17:                    0 events,        0 KiB data
  CPU 18:                    0 events,        0 KiB data
  CPU 19:                    0 events,        0 KiB data
  CPU 20:                    0 events,        0 KiB data
  CPU 21:                    0 events,        0 KiB data
  CPU 22:                    0 events,        0 KiB data
  CPU 23:                    0 events,        0 KiB data
  CPU 24:                    0 events,        0 KiB data
  CPU 25:                    0 events,        0 KiB data
  CPU 26:                    0 events,        0 KiB data
  CPU 27:                    0 events,        0 KiB data
  CPU 28:                    0 events,        0 KiB data
  CPU 29:                    0 events,        0 KiB data
  CPU 30:                    0 events,        0 KiB data
  CPU 31:                    0 events,        0 KiB data
  CPU 32:                    0 events,        0 KiB data
  CPU 33:                    0 events,        0 KiB data
  CPU 34:                    0 events,        0 KiB data
  CPU 35:                    0 events,        0 KiB data
  CPU 36:                    0 events,        0 KiB data
  CPU 37:                    0 events,        0 KiB data
  CPU 38:                    0 events,        0 KiB data
  CPU 39:                 1103 events,       52 KiB data
  CPU 40:                 1518 events,       72 KiB data
  CPU 41:                    0 events,        0 KiB data
  CPU 42:                    0 events,        0 KiB data
  CPU 43:                    0 events,        0 KiB data
  CPU 44:                    0 events,        0 KiB data
  CPU 45:                10975 events,      515 KiB data
  CPU 46:                10966 events,      515 KiB data
  CPU 47:                    0 events,        0 KiB data
  CPU 48:                10922 events,      513 KiB data
  CPU 49:                    0 events,        0 KiB data
  CPU 50:                    0 events,        0 KiB data
  CPU 51:                    0 events,        0 KiB data
  CPU 52:                 4090 events,      192 KiB data
  CPU 53:                10933 events,      513 KiB data
  CPU 54:                    0 events,        0 KiB data
  CPU 55:                    0 events,        0 KiB data
  CPU 56:                    0 events,        0 KiB data
  CPU 57:                    1 events,        1 KiB data
  CPU 58:                    0 events,        0 KiB data
  CPU 59:                    0 events,        0 KiB data
  CPU 60:                    0 events,        0 KiB data
  CPU 61:                    0 events,        0 KiB data
  CPU 62:                    0 events,        0 KiB data
  CPU 63:                    0 events,        0 KiB data
  Total:                337563 events (dropped 0),    15824 KiB data

----------------------------------------------------------------------------------------- 
## blkparse -i sda3 -d write.bin
CPU0 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         341,    1,265MiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:    1,225,    1,243MiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU1 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         102,  380,504KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      381,  377,780KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU6 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:           5,       44KiB
 Read Dispatches:        1,        0KiB	 Write Dispatches:       15,   11,468KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            1,       16KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             2        	 Timer unplugs:           0
CPU9 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:           7,    7,168KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:       14,    7,168KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU12 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:       1,095,    2,862MiB
 Read Dispatches:        4,        0KiB	 Write Dispatches:    2,889,    2,866MiB
 Reads Requeued:         1		 Writes Requeued:         0
 Reads Completed:        6,        0KiB	 Writes Completed:    6,450,    5,948MiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU13 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         174,  260,252KiB
 Read Dispatches:        2,        0KiB	 Write Dispatches:      340,  258,500KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:            16        	 Timer unplugs:           4
CPU39 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          16,   28,460KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:       28,   27,948KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU40 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          40,    4,276KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:       45,   10,668KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             1        	 Timer unplugs:          33
CPU45 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         194,  243,972KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      373,  245,252KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU46 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         174,  176,412KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      331,  166,600KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU48 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         199,  368,520KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      376,  368,212KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU52 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          90,      472KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      105,   15,252KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             1        	 Timer unplugs:          84
CPU53 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          68,  383,532KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      354,  380,980KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0

Total (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:       2,505,    5,981MiB
 Read Dispatches:        7,        0KiB	 Write Dispatches:    6,476,    5,980MiB
 Reads Requeued:         1		 Writes Requeued:         0
 Reads Completed:        6,        0KiB	 Writes Completed:    6,450,    5,948MiB
 Read Merges:            0,        0KiB	 Write Merges:            1,       16KiB
 IO unplugs:            20        	 Timer unplugs:         121

Throughput (R/W): 0KiB/s / 89,658KiB/s
Events (sda3): 35,159 entries
Skips: 0 forward (0 -   0.0%)


-----------------------------------------------------------------------------------------
# btt -i write.bin
==================== All Devices ====================

            ALL           MIN           AVG           MAX           N
--------------- ------------- ------------- ------------- -----------

Q2Q               0.000002235   0.026522695  15.003863511        2501
Q2A               1.237574510  21.824027681  47.722774878         467
Q2G               0.000000654   0.009451105   0.112203200        6476
G2I               0.000000114   0.000004815   0.001737578        6472
Q2M               0.000001916   0.000001916   0.000001916           1
I2D               0.000003613   0.000762261   0.234475605         430
D2C               0.000031804   0.089757177   0.204904039         434
Q2C               0.000035492   0.094561236   0.248242485         434

==================== Device Overhead ====================

       DEV |       Q2G       G2I       Q2M       I2D       D2C
---------- | --------- --------- --------- --------- ---------
 (  8,  3) | 149.1374%   0.0759%   0.0000%   0.7987%  94.9196%
---------- | --------- --------- --------- --------- ---------
   Overall | 149.1374%   0.0759%   0.0000%   0.7987%  94.9196%

==================== Device Merge Information ====================

       DEV |       #Q       #D   Ratio |   BLKmin   BLKavg   BLKmax    Total
---------- | -------- -------- ------- | -------- -------- -------- --------
 (  8,  3) |     6476     6476     1.0 |        8     1837     2560 11896840

==================== Device Q2Q Seek Information ====================

       DEV |          NSEEKS            MEAN          MEDIAN | MODE           
---------- | --------------- --------------- --------------- | ---------------
 (  8,  3) |            2502       4312314.4               0 | 0(1951)
---------- | --------------- --------------- --------------- | ---------------
   Overall |          NSEEKS            MEAN          MEDIAN | MODE           
   Average |            2502       4312314.4               0 | 0(1951)

==================== Device D2D Seek Information ====================

       DEV |          NSEEKS            MEAN          MEDIAN | MODE           
---------- | --------------- --------------- --------------- | ---------------
 (  8,  3) |            6476       1987158.4               0 | 0(5878)
---------- | --------------- --------------- --------------- | ---------------
   Overall |          NSEEKS            MEAN          MEDIAN | MODE           
   Average |            6476       1987158.4               0 | 0(5878)

==================== Plug Information ====================

       DEV |    # Plugs # Timer Us  | % Time Q Plugged
---------- | ---------- ----------  | ----------------
 (  8,  3) |         20(       121) |   0.018203999%

       DEV |    IOs/Unp   IOs/Unp(to)
---------- | ----------   ----------
 (  8,  0) |        0.0          0.0
 (  8,  3) |        2.5          1.1
---------- | ----------   ----------
   Overall |    IOs/Unp   IOs/Unp(to)
   Average |        2.5          1.1

==================== Active Requests At Q Information ====================

       DEV |  Avg Reqs @ Q
---------- | -------------
 (  8,  3) |           0.1

==================== I/O Active Period Information ====================

       DEV |     # Live      Avg. Act     Avg. !Act % Live
---------- | ---------- ------------- ------------- ------
 (  8,  0) |          0   0.000000000   0.000000000   0.00
 (  8,  3) |        117   0.157607262   0.412871641  27.80
---------- | ---------- ------------- ------------- ------
 Total Sys |        117   0.157607262   0.412871641  27.80

# Total System
#     Total System : q activity
  0.000001431   0.0
  0.000001431   0.4
  0.001325920   0.4
  0.001325920   0.0
 15.005189431   0.0
 15.005189431   0.4
 16.309961711   0.4
 16.309961711   0.0
 20.119132434   0.0
 20.119132434   0.4
 22.238091856   0.4
 22.238091856   0.0
 30.870365414   0.0
 30.870365414   0.4
 30.870365414   0.4
 30.870365414   0.0
 40.604921128   0.0
 40.604921128   0.4
 42.814391667   0.4
 42.814391667   0.0
 45.719003807   0.0
 45.719003807   0.4
 66.333262851   0.4
 66.333262851   0.0

#     Total System : c activity
  0.000271345   0.5
  0.000271345   0.9
  0.001598846   0.9
  0.001598846   0.5
 15.006899952   0.5
 15.006899952   0.9
 16.437402332   0.9
 16.437402332   0.5
 20.120726094   0.5
 20.120726094   0.9
 22.391873470   0.9
 22.391873470   0.5
 30.870560191   0.5
 30.870560191   0.9
 30.870560191   0.9
 30.870560191   0.5
 40.607855938   0.5
 40.607855938   0.9
 42.943688524   0.9
 42.943688524   0.5
 45.720501224   0.5
 45.720501224   0.9
 66.345089024   0.9
 66.345089024   0.5

# Per device
#              8,3 : q activity
  0.000001431   1.0
  0.000001431   1.4
  0.001325920   1.4
  0.001325920   1.0
 15.005189431   1.0
 15.005189431   1.4
 16.309961711   1.4
 16.309961711   1.0
 20.119132434   1.0
 20.119132434   1.4
 22.238091856   1.4
 22.238091856   1.0
 30.870365414   1.0
 30.870365414   1.4
 30.870365414   1.4
 30.870365414   1.0
 40.604921128   1.0
 40.604921128   1.4
 42.814391667   1.4
 42.814391667   1.0
 45.719003807   1.0
 45.719003807   1.4
 66.333262851   1.4
 66.333262851   1.0

#              8,3 : c activity
  0.000271345   1.5
  0.000271345   1.9
  0.001598846   1.9
  0.001598846   1.5
 15.006899952   1.5
 15.006899952   1.9
 16.437402332   1.9
 16.437402332   1.5
 20.120726094   1.5
 20.120726094   1.9
 22.391873470   1.9
 22.391873470   1.5
 30.870560191   1.5
 30.870560191   1.9
 30.870560191   1.9
 30.870560191   1.5
 40.607855938   1.5
 40.607855938   1.9
 42.943688524   1.9
 42.943688524   1.5
 45.720501224   1.5
 45.720501224   1.9
 66.345089024   1.9
 66.345089024   1.5

# Per process
#           auditd : q activity
  0.000001431   2.0
  0.000001431   2.4
  0.001325920   2.4
  0.001325920   2.0

#           auditd : c activity

#         blktrace : q activity

#         blktrace : c activity
 16.037824860   3.5
 16.037824860   3.9
 16.040146725   3.9
 16.040146725   3.5
 48.523254848   3.5
 48.523254848   3.9
 48.523254848   3.9
 48.523254848   3.5
 50.982199011   3.5
 50.982199011   3.9
 50.982199011   3.9
 50.982199011   3.5

#  btrfs-transacti : q activity
 21.168002272   4.0
 21.168002272   4.4
 21.385768586   4.4
 21.385768586   4.0
 51.866209105   4.0
 51.866209105   4.4
 51.892354220   4.4
 51.892354220   4.0
 51.994706531   4.0
 51.994706531   4.4
 52.062538437   4.4
 52.062538437   4.0

#  btrfs-transacti : c activity
 21.147591077   4.5
 21.147591077   4.9
 21.168231901   4.9
 21.168231901   4.5

#           kernel : q activity

#           kernel : c activity
  0.000271345   5.5
  0.000271345   5.9
  0.001598846   5.9
  0.001598846   5.5
 15.006899952   5.5
 15.006899952   5.9
 16.437402332   5.9
 16.437402332   5.5
 20.120726094   5.5
 20.120726094   5.9
 22.391873470   5.9
 22.391873470   5.5
 30.870560191   5.5
 30.870560191   5.9
 30.870560191   5.9
 30.870560191   5.5
 40.607855938   5.5
 40.607855938   5.9
 42.943688524   5.9
 42.943688524   5.5
 45.720501224   5.5
 45.720501224   5.9
 66.345089024   5.9
 66.345089024   5.5

#        ksoftirqd : q activity

#        ksoftirqd : c activity
 20.718258756   6.5
 20.718258756   6.9
 21.074090831   6.9
 21.074090831   6.5
 45.867866336   6.5
 45.867866336   6.9
 45.867866336   6.9
 45.867866336   6.5
 52.003304294   6.5
 52.003304294   6.9
 52.003304294   6.9
 52.003304294   6.5
 52.547972485   6.5
 52.547972485   6.9
 52.559856247   6.9
 52.559856247   6.5

#          kworker : q activity
 15.005189431   7.0
 15.005189431   7.4
 16.309961711   7.4
 16.309961711   7.0
 20.119132434   7.0
 20.119132434   7.4
 21.168362250   7.4
 21.168362250   7.0
 21.280574998   7.0
 21.280574998   7.4
 22.238091856   7.4
 22.238091856   7.0
 30.870365414   7.0
 30.870365414   7.4
 30.870365414   7.4
 30.870365414   7.0
 40.604921128   7.0
 40.604921128   7.4
 42.814391667   7.4
 42.814391667   7.0
 45.719003807   7.0
 45.719003807   7.4
 66.333262851   7.4
 66.333262851   7.0

#          kworker : c activity
 20.855499128   7.5
 20.855499128   7.9
 21.070540767   7.9
 21.070540767   7.5
 45.728052971   7.5
 45.728052971   7.9
 45.732241835   7.9
 45.732241835   7.5
 52.492099242   7.5
 52.492099242   7.9
 52.492099242   7.9
 52.492099242   7.5
 52.594258177   7.5
 52.594258177   7.9
 52.595446831   7.9
 52.595446831   7.5
```

#### Checkpoint - Disk Monitor

```bash
-----------------------------------------------------------------------------------------
# monitor your mounted disk 
# here my disk is /dev/sda3
##  blktrace -d /dev/sda3 -o - | blkparse  -i -
# part of output is listed below ：
8,0   48      407    30.906416066 2342076  A   W 72432672 + 8 <- (8,3) 69104672
  8,3   48      408    30.906416272 2342076  Q   W 72432672 + 8 [kworker/u128:1]
  8,3   48      409    30.906417717 2342076  G   W 72432672 + 8 [kworker/u128:1]
  8,0   48      410    30.906436206 2342076  A   W 72432768 + 8 <- (8,3) 69104768
  8,3   48      411    30.906436437 2342076  Q   W 72432768 + 8 [kworker/u128:1]
  8,3   48      412    30.906438094 2342076  G   W 72432768 + 8 [kworker/u128:1]
  8,0   48      413    30.906445799 2342076  A   W 72432880 + 48 <- (8,3) 69104880
  8,3   48      414    30.906445968 2342076  Q   W 72432880 + 48 [kworker/u128:1]
  8,3   48      415    30.906447554 2342076  G   W 72432880 + 48 [kworker/u128:1]
  8,0   48      416    30.906461587 2342076  A   W 72374136 + 8 <- (8,3) 69046136
  8,3   48      417    30.906461818 2342076  Q   W 72374136 + 8 [kworker/u128:1]
  8,3   48      418    30.906463308 2342076  G   W 72374136 + 8 [kworker/u128:1]
  8,3   48      419    30.906464924 2342076  U   N [kworker/u128:1] 10
  8,3   48      420    30.906465091 2342076  I   W 72432264 + 8 [kworker/u128:1]
  8,3   48      421    30.906468800 2342076  I   W 72432320 + 8 [kworker/u128:1]
  8,3   48      422    30.906470426 2342076  I   W 72432352 + 8 [kworker/u128:1]
  8,3   48      423    30.906472006 2342076  I   W 72432392 + 8 [kworker/u128:1]
  8,3   48      424    30.906474780 2342076  I   W 72432472 + 8 [kworker/u128:1]
  8,3   48      425    30.906479919 2342076  I   W 72432576 + 8 [kworker/u128:1]
  8,3   48      426    30.906481860 2342076  I   W 72432672 + 8 [kworker/u128:1]
  8,3   48      427    30.906483522 2342076  I   W 72432768 + 8 [kworker/u128:1]
  8,3   48      428    30.906485111 2342076  I   W 72432880 + 48 [kworker/u128:1]
  8,3   48      429    30.906488399 2342076  I   W 72374136 + 8 [kworker/u128:1]
  8,3   48      430    30.906493378 2342076  D   W 72432320 + 8 [kworker/u128:1]
  8,3   48      431    30.906499347 2342076  D   W 72432392 + 8 [kworker/u128:1]
  8,3   48      432    30.906502924 2342076  D   W 72432472 + 8 [kworker/u128:1]
  8,3   48      433    30.906507165 2342076  D   W 72432576 + 8 [kworker/u128:1]
  8,3   48      434    30.906511920 2342076  D   W 72432672 + 8 [kworker/u128:1]
  8,3   48      435    30.906516214 2342076  D   W 72432768 + 8 [kworker/u128:1]
  8,3   48      436    30.906521994 2342076  D   W 72374136 + 8 [kworker/u128:1]
  8,0   12      137    33.978788139   927  A  WS 15560232 + 512 <- (8,3) 12232232
  8,3   12      138    33.978789410   927  Q  WS 15560232 + 512 [btrfs-transacti]
  8,3   12      139    33.978802655   927  G  WS 15560232 + 512 [btrfs-transacti]
  8,3   12      140    33.978804843   927  I  WS 15560232 + 512 [btrfs-transacti]
  8,3   12      141    33.978849468    73  D  WS 15560232 + 512 [kworker/12:0H]
  8,3   12      142    33.979444259   927  C  WS 15560232 + 512 [0]
  8,0   12      143    33.979965124   927  A  WS 42061104 + 512 <- (8,3) 38733104
  8,3   12      144    33.979965589   927  Q  WS 42061104 + 512 [btrfs-transacti]
  8,3   12      145    33.979970959   927  G  WS 42061104 + 512 [btrfs-transacti]
  8,3   12      146    33.979971724   927  I  WS 42061104 + 512 [btrfs-transacti]
  8,3   12      147    33.979993668    73  D  WS 42061104 + 512 [kworker/12:0H]
  8,3   12      148    33.980567924   927  C  WS 42061104 + 512 [0]
  8,0   12      149    33.980970925   927  A  WS 42069824 + 512 <- (8,3) 38741824
  8,3   12      150    33.980971259   927  Q  WS 42069824 + 512 [btrfs-transacti]
  8,3   12      151    33.980975678   927  G  WS 42069824 + 512 [btrfs-transacti]
  8,3   12      152    33.980976274   927  I  WS 42069824 + 512 [btrfs-transacti]
  8,3   12      153    33.980992229    73  D  WS 42069824 + 512 [kworker/12:0H]
  8,3   12      154    33.981564340   927  C  WS 42069824 + 512 [0]
  8,0   12      155    33.982142269   927  A  WS 15560232 + 512 <- (8,3) 12232232
  8,3   12      156    33.982142582   927  Q  WS 15560232 + 512 [btrfs-transacti]
  8,3   12      157    33.982147038   927  G  WS 15560232 + 512 [btrfs-transacti]
  8,3   12      158    33.982147685   927  I  WS 15560232 + 512 [btrfs-transacti]
  8,3   12      159    33.982163140    73  D  WS 15560232 + 512 [kworker/12:0H]
  8,3   12      160    33.982733506   927  C  WS 15560232 + 512 [0]
  8,0   12      161    33.983125254   927  A  WS 42070336 + 512 <- (8,3) 38742336
  8,3   12      162    33.983125531   927  Q  WS 42070336 + 512 [btrfs-transacti]
  8,3   12      163    33.983129638   927  G  WS 42070336 + 512 [btrfs-transacti]
  8,3   12      164    33.983130250   927  I  WS 42070336 + 512 [btrfs-transacti]
  8,3   12      165    33.983143695    73  D  WS 42070336 + 512 [kworker/12:0H]
  8,3   12      166    33.983715300   927  C  WS 42070336 + 512 [0]
  8,0   12      167    33.984136110   927  A  WS 42093080 + 512 <- (8,3) 38765080
  8,3   12      168    33.984136431   927  Q  WS 42093080 + 512 [btrfs-transacti]
  8,3   12      169    33.984140790   927  G  WS 42093080 + 512 [btrfs-transacti]
  8,3   12      170    33.984141510   927  I  WS 42093080 + 512 [btrfs-transacti]
  8,3   12      171    33.984159539    73  D  WS 42093080 + 512 [kworker/12:0H]
  8,3   12      172    33.984732490   927  C  WS 42093080 + 512 [0]
  8,0   12      173    33.985114512   927  A  WS 42099472 + 512 <- (8,3) 38771472
  8,3   12      174    33.985114795   927  Q  WS 42099472 + 512 [btrfs-transacti]
  8,3   12      175    33.985118811   927  G  WS 42099472 + 512 [btrfs-transacti]
  8,3   12      176    33.985119483   927  I  WS 42099472 + 512 [btrfs-transacti]
  8,3   12      177    33.985151796    73  D  WS 42099472 + 512 [kworker/12:0H]
  8,3   12      178    33.985722763   927  C  WS 42099472 + 512 [0]
  8,0   12      179    33.986536240   927  A  WS 15560232 + 512 <- (8,3) 12232232
  8,3   12      180    33.986536577   927  Q  WS 15560232 + 512 [btrfs-transacti]
  8,3   12      181    33.986541857   927  G  WS 15560232 + 512 [btrfs-transacti]
  8,3   12      182    33.986542671   927  I  WS 15560232 + 512 [btrfs-transacti]
  8,3   12      183    33.986561291    73  D  WS 15560232 + 512 [kworker/12:0H]
  8,3   12      184    33.987133152   927  C  WS 15560232 + 512 [0]
  8,0   12      185    33.987372624   927  A  WS 42093080 + 512 <- (8,3) 38765080
  8,3   12      186    33.987372900   927  Q  WS 42093080 + 512 [btrfs-transacti]
  8,3   12      187    33.987377064   927  G  WS 42093080 + 512 [btrfs-transacti]
  8,3   12      188    33.987377817   927  I  WS 42093080 + 512 [btrfs-transacti]
  8,3   12      189    33.987393447    73  D  WS 42093080 + 512 [kworker/12:0H]
  8,0   12      190    33.987934652   927  A  WS 42099984 + 512 <- (8,3) 38771984
  8,3   12      191    33.987934765   927  Q  WS 42099984 + 512 [btrfs-transacti]
  8,3   12      192    33.987936391   927  G  WS 42099984 + 512 [btrfs-transacti]
  8,3   12      193    33.987936604   927  I  WS 42099984 + 512 [btrfs-transacti]
  8,3   12      194    33.987943005    73  D  WS 42099984 + 512 [kworker/12:0H]
  8,3   12      195    33.987959663   927  C  WS 42093080 + 512 [0]
  8,0   12      196    33.988360643   927  A  WS 42100496 + 512 <- (8,3) 38772496
  8,3   12      197    33.988360782   927  Q  WS 42100496 + 512 [btrfs-transacti]
  8,3   12      198    33.988362530   927  G  WS 42100496 + 512 [btrfs-transacti]
  8,3   12      199    33.988362799   927  I  WS 42100496 + 512 [btrfs-transacti]
  8,3   12      200    33.988369845    73  D  WS 42100496 + 512 [kworker/12:0H]
  8,3   12      201    33.988522945   927  C  WS 42099984 + 512 [0]
  8,0   12      202    33.988685315   927  A  WS 42093080 + 512 <- (8,3) 38765080
  8,3   12      203    33.988685434   927  Q  WS 42093080 + 512 [btrfs-transacti]
  8,3   12      204    33.988687016   927  G  WS 42093080 + 512 [btrfs-transacti]
  8,3   12      205    33.988687208   927  I  WS 42093080 + 512 [btrfs-transacti]
  8,3   12      206    33.988693431    73  D  WS 42093080 + 512 [kworker/12:0H]
  8,0   12      207    33.988985346   927  A  WS 42099472 + 512 <- (8,3) 38771472
  8,3   12      208    33.988985476   927  Q  WS 42099472 + 512 [btrfs-transacti]
  8,3   12      209    33.988986970   927  G  WS 42099472 + 512 [btrfs-transacti]
  8,3   12      210    33.988987157   927  I  WS 42099472 + 512 [btrfs-transacti]
  8,3   12      211    33.988998886    73  D  WS 42099472 + 512 [kworker/12:0H]
  8,3   12      212    33.989090486   927  C  WS 42100496 + 512 [0]
  8,0   12      213    33.989304541   927  A  WS 15560232 + 512 <- (8,3) 12232232
  8,3   12      214    33.989304675   927  Q  WS 15560232 + 512 [btrfs-transacti]
  8,3   12      215    33.989306233   927  G  WS 15560232 + 512 [btrfs-transacti]
  8,3   12      216    33.989306393   927  I  WS 15560232 + 512 [btrfs-transacti]
  8,3   12      217    33.989312511    73  D  WS 15560232 + 512 [kworker/12:0H]
  8,3   12      218    33.989696775     0  C  WS 42093080 + 512 [0]
  8,3   12      219    33.990202799     0  C  WS 42099472 + 512 [0]
  8,3   12      220    33.990764624     0  C  WS 15560232 + 512 [0]
  8,0   12      221    33.990931852   927  A WSM 7039136 + 128 <- (8,3) 3711136
  8,3   12      222    33.990931972   927  Q WSM 7039136 + 128 [btrfs-transacti]
  8,3   12      223    33.990933294   927  G WSM 7039136 + 128 [btrfs-transacti]
  8,3   12      224    33.990933705   927  P   N [btrfs-transacti]
  8,0   12      225    33.991213995   927  A WSM 7039296 + 384 <- (8,3) 3711296
  8,3   12      226    33.991214108   927  Q WSM 7039296 + 384 [btrfs-transacti]
  8,3   12      227    33.991215510   927  G WSM 7039296 + 384 [btrfs-transacti]
  8,0   12      228    33.991338405   927  A WSM 7044256 + 160 <- (8,3) 3716256
  8,3   12      229    33.991338512   927  Q WSM 7044256 + 160 [btrfs-transacti]
  8,3   12      230    33.991339490   927  G WSM 7044256 + 160 [btrfs-transacti]
  8,3   12      231    33.991339981   927  U   N [btrfs-transacti] 2
  8,3   12      232    33.991340164   927  I WSM 7039136 + 128 [btrfs-transacti]
  8,3   12      233    33.991341813   927  I WSM 7039296 + 384 [btrfs-transacti]
  8,3   12      234    33.991345461   927  D WSM 7039136 + 128 [btrfs-transacti]
  8,3   12      235    33.991349441   927  D WSM 7039296 + 384 [btrfs-transacti]
  8,3   12      236    33.991352393   927  P   N [btrfs-transacti]
  8,0   12      237    33.991444009   927  A WSM 7044576 + 96 <- (8,3) 3716576
  8,3   12      238    33.991444119   927  Q WSM 7044576 + 96 [btrfs-transacti]
  8,3   12      239    33.991445251   927  G WSM 7044576 + 96 [btrfs-transacti]
  8,3   12      240    33.991502162   927  C WSM 7039136 + 128 [0]
  8,0   12      241    33.991560327   927  A WSM 7044832 + 128 <- (8,3) 3716832
  8,3   12      242    33.991560434   927  Q WSM 7044832 + 128 [btrfs-transacti]
  8,3   12      243    33.991561432   927  G WSM 7044832 + 128 [btrfs-transacti]
  8,0   12      244    33.991745485   927  A WSM 7044992 + 288 <- (8,3) 3716992
  8,3   12      245    33.991745602   927  Q WSM 7044992 + 288 [btrfs-transacti]
  8,3   12      246    33.991746841   927  G WSM 7044992 + 288 [btrfs-transacti]
  8,3   12      247    33.991882401   927  C WSM 7039296 + 384 [0]
  8,0   12      248    33.991959863   927  A WSM 7046496 + 288 <- (8,3) 3718496
  8,3   12      249    33.991959970   927  Q WSM 7046496 + 288 [btrfs-transacti]
  8,3   12      250    33.991961225   927  G WSM 7046496 + 288 [btrfs-transacti]
  8,3   12      251    33.991961462   927  U   N [btrfs-transacti] 4
  8,3   12      252    33.991961558   927  I WSM 7044256 + 160 [btrfs-transacti]
  8,3   12      253    33.991962695   927  I WSM 7044576 + 96 [btrfs-transacti]
  8,3   12      254    33.991963694   927  I WSM 7044832 + 128 [btrfs-transacti]
  8,3   12      255    33.991964628   927  I WSM 7044992 + 288 [btrfs-transacti]
  8,3   12      256    33.991967752   927  D WSM 7044256 + 160 [btrfs-transacti]
  8,3   12      257    33.991971631   927  D WSM 7044576 + 96 [btrfs-transacti]
  8,3   12      258    33.991974644   927  D WSM 7044832 + 128 [btrfs-transacti]
  8,3   12      259    33.991977583   927  D WSM 7044992 + 288 [btrfs-transacti]
  8,3   12      260    33.991980222   927  P   N [btrfs-transacti]
  8,3   12      261    33.992166423   927  C WSM 7044256 + 160 [0]
  8,3   12      262    33.992263118    73  C WSM 7044576 + 96 [0]
  8,0   12      263    33.992268935   927  A WSM 7047040 + 480 <- (8,3) 3719040
  8,3   12      264    33.992269039   927  Q WSM 7047040 + 480 [btrfs-transacti]
  8,3   12      265    33.992270398   927  G WSM 7047040 + 480 [btrfs-transacti]
  8,3   12      266    33.992270538   927  U   N [btrfs-transacti] 1
  8,3   12      267    33.992270645   927  I WSM 7046496 + 288 [btrfs-transacti]
  8,3   12      268    33.992273692   927  D WSM 7046496 + 288 [btrfs-transacti]
  8,3   12      269    33.992276250   927  P   N [btrfs-transacti]
  8,3   12      270    33.992276924   927  U   N [btrfs-transacti] 1
  8,3   12      271    33.992277016   927  I WSM 7047040 + 480 [btrfs-transacti]
  8,3   12      272    33.992279827   927  D WSM 7047040 + 480 [btrfs-transacti]
  8,3   12      273    33.992392024     0  C WSM 7044832 + 128 [0]
  8,3   12      274    33.992678456     0  C WSM 7044992 + 288 [0]
  8,3   12      275    33.993050652     0  C WSM 7046496 + 288 [0]
  8,3   12      276    33.993525318     0  C WSM 7047040 + 480 [0]
  8,3   12      277    33.993540459   927  Q FWS [btrfs-transacti]
  8,3   12      278    33.993540930   927  G FWS [btrfs-transacti]
  8,3   12      279    33.993543680    73  D  FN [kworker/12:0H]
  8,3   12      280    33.993570287     0  C  FN 0 [0]
  8,3   12      281    33.993570774     0  C  WS 0 [0]
  8,0   12      282    33.993577954   927  A WFSM 3328128 + 8 <- (8,3) 128
  8,3   12      283    33.993578083   927  Q WFSM 3328128 + 8 [btrfs-transacti]
  8,3   12      284    33.993578409   927  G WFSM 3328128 + 8 [btrfs-transacti]
  8,3   12      285    33.993580822    73  D WSM 3328128 + 8 [kworker/12:0H]
  8,0   12      286    33.993583926   927  A WSM 3459072 + 8 <- (8,3) 131072
  8,3   12      287    33.993584043   927  Q WSM 3459072 + 8 [btrfs-transacti]
  8,3   12      288    33.993584843   927  G WSM 3459072 + 8 [btrfs-transacti]
  8,3   12      289    33.993585056   927  I WSM 3459072 + 8 [btrfs-transacti]
  8,3   12      290    33.993590222    73  D WSM 3459072 + 8 [kworker/12:0H]
  8,3   12      291    33.993615781     0  C WSM 3328128 + 8 [0]
  8,3   12      292    33.993618134    73  D  FN [kworker/12:0H]
  8,3   12      293    33.993618788    73  R  FN 0 [0]
  8,3   12      294    33.993628455     0  C WSM 3459072 + 8 [0]
  8,3   12      295    33.993632662    73  D  FN [kworker/12:0H]
  8,3   12      296    33.993670447     0  C  FN 0 [0]
  8,3   12      297    33.993670679     0  C WSM 3328128 [0]

#########################################################################################
## blktrace -d /dev/sda3

^C=== sda3 ===
  CPU  0:                30322 events,     1422 KiB data
  CPU  1:                14678 events,      689 KiB data
  CPU  2:                    0 events,        0 KiB data
  CPU  3:                10948 events,      514 KiB data
  CPU  4:                    0 events,        0 KiB data
  CPU  5:                    0 events,        0 KiB data
  CPU  6:                    0 events,        0 KiB data
  CPU  7:                    0 events,        0 KiB data
  CPU  8:                 5094 events,      239 KiB data
  CPU  9:                    0 events,        0 KiB data
  CPU 10:                    0 events,        0 KiB data
  CPU 11:                    0 events,        0 KiB data
  CPU 12:               270218 events,    12667 KiB data
  CPU 13:                14689 events,      689 KiB data
  CPU 14:                 8173 events,      384 KiB data
  CPU 15:                    0 events,        0 KiB data
  CPU 16:                    0 events,        0 KiB data
  CPU 17:                    0 events,        0 KiB data
  CPU 18:                10943 events,      513 KiB data
  CPU 19:                    0 events,        0 KiB data
  CPU 20:                    0 events,        0 KiB data
  CPU 21:                    0 events,        0 KiB data
  CPU 22:                    0 events,        0 KiB data
  CPU 23:                    0 events,        0 KiB data
  CPU 24:                    0 events,        0 KiB data
  CPU 25:                    0 events,        0 KiB data
  CPU 26:                   64 events,        4 KiB data
  CPU 27:                    0 events,        0 KiB data
  CPU 28:                77251 events,     3622 KiB data
  CPU 29:                    0 events,        0 KiB data
  CPU 30:                 5395 events,      253 KiB data
  CPU 31:                    0 events,        0 KiB data
  CPU 32:                    0 events,        0 KiB data
  CPU 33:                    0 events,        0 KiB data
  CPU 34:                    0 events,        0 KiB data
  CPU 35:                    0 events,        0 KiB data
  CPU 36:                    0 events,        0 KiB data
  CPU 37:                10925 events,      513 KiB data
  CPU 38:                    0 events,        0 KiB data
  CPU 39:                    0 events,        0 KiB data
  CPU 40:                    0 events,        0 KiB data
  CPU 41:                 1865 events,       88 KiB data
  CPU 42:                    0 events,        0 KiB data
  CPU 43:                    0 events,        0 KiB data
  CPU 44:                 1365 events,       64 KiB data
  CPU 45:                    0 events,        0 KiB data
  CPU 46:                10149 events,      476 KiB data
  CPU 47:                    0 events,        0 KiB data
  CPU 48:                   81 events,        4 KiB data
  CPU 49:                    0 events,        0 KiB data
  CPU 50:                    0 events,        0 KiB data
  CPU 51:                    0 events,        0 KiB data
  CPU 52:                    0 events,        0 KiB data
  CPU 53:                    0 events,        0 KiB data
  CPU 54:                    0 events,        0 KiB data
  CPU 55:                    1 events,        1 KiB data
  CPU 56:                    0 events,        0 KiB data
  CPU 57:                    0 events,        0 KiB data
  CPU 58:                    0 events,        0 KiB data
  CPU 59:                    0 events,        0 KiB data
  CPU 60:                    0 events,        0 KiB data
  CPU 61:                28905 events,     1355 KiB data
  CPU 62:                 2894 events,      136 KiB data
  CPU 63:                    0 events,        0 KiB data
  Total:                503960 events (dropped 0),    23624 KiB data
-----------------------------------------------------------------------------------------
## blkparse -i sda3 -d checkpoint.bin

CPU0 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          76,    1,189MiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      926,    1,135MiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU1 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          39,  582,164KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      478,  586,840KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU3 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          32,  430,836KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      346,  420,036KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU8 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          16,  107,184KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:       97,  107,184KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU12 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         164,    2,189MiB
 Read Dispatches:        5,        0KiB	 Write Dispatches:    1,952,    2,334MiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:       10,        0KiB	 Writes Completed:    9,287,   10,877MiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 PC Reads Queued:        0,        0KiB	 PC Writes Queued:        0,        0KiB
 PC Read Disp.:          0,        0KiB	 PC Write Disp.:          0,        0KiB
 PC Reads Req.:          0		 PC Writes Req.:          0
 PC Reads Compl.:        5		 PC Writes Compl.:        0
 IO unplugs:             0        	 Timer unplugs:           0
CPU13 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          43,  561,880KiB
 Read Dispatches:        1,        0KiB	 Write Dispatches:      452,  549,860KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             1        	 Timer unplugs:           1
CPU14 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         264,   40,560KiB
 Read Dispatches:        4,        0KiB	 Write Dispatches:      234,   52,652KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:            38        	 Timer unplugs:          26
CPU18 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          49,  416,648KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      353,  407,848KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU26 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:           1,        4KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:        1,        4KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU28 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         253,    2,896MiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:    2,393,    2,847MiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU30 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          17,  241,972KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      181,  218,116KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU37 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          28,  452,136KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      357,  440,576KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU41 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:           8,   67,192KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:       48,   53,764KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU44 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          61,      320KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:       49,      256KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             4        	 Timer unplugs:           1
CPU46 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          37,  362,808KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      303,  360,088KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU48 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:           1,        4KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:        1,        4KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 PC Reads Queued:        0,        0KiB	 PC Writes Queued:        0,        0KiB
 PC Read Disp.:          5,        1KiB	 PC Write Disp.:          0,        0KiB
 PC Reads Req.:          0		 PC Writes Req.:          0
 PC Reads Compl.:        0		 PC Writes Compl.:        0
 IO unplugs:             0        	 Timer unplugs:           0
CPU61 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          79,    1,177MiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      973,    1,195MiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU62 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:           7,  112,348KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      101,  125,964KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0

Total (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:       1,175,   10,828MiB
 Read Dispatches:       10,        0KiB	 Write Dispatches:    9,245,   10,837MiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:       10,        0KiB	 Writes Completed:    9,287,   10,877MiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 PC Reads Queued:        0,        0KiB	 PC Writes Queued:        0,        0KiB
 PC Read Disp.:          5,        1KiB	 PC Write Disp.:          0,        0KiB
 PC Reads Req.:          0		 PC Writes Req.:          0
 PC Reads Compl.:        5		 PC Writes Compl.:        0
 IO unplugs:            43        	 Timer unplugs:          28

Throughput (R/W): 0KiB/s / 76,609KiB/s
Events (sda3): 47,612 entries
Skips: 0 forward (0 -   0.0%)

-----------------------------------------------------------------------------------------
# btt -i checkpoint.bin -o checkPoint
# cat checkPoint.avg
==================== All Devices ====================

            ALL           MIN           AVG           MAX           N
--------------- ------------- ------------- ------------- -----------

Q2Q               0.000002599   0.121287623  22.936877111        1169
Q2A               2.461899034  16.011193770  40.098967428         391
Q2G               0.000000369   0.689061793 102.091150799        9238
G2I               0.000000113   0.000007021   0.001233113        9233
I2D               0.000002632   0.002037353   0.156234836         336
D2C               0.000030792   0.018980926   0.180848553         341
Q2C               0.000034552   0.021567265   0.300426251         341

==================== Device Overhead ====================

       DEV |       Q2G       G2I       Q2M       I2D       D2C
---------- | --------- --------- --------- --------- ---------
 (  8,  3) | 86553.9080%   0.8815%   0.0000%   9.3080%  88.0080%
---------- | --------- --------- --------- --------- ---------
   Overall | 86553.9080%   0.8815%   0.0000%   9.3080%  88.0080%

==================== Device Merge Information ====================

       DEV |       #Q       #D   Ratio |   BLKmin   BLKavg   BLKmax    Total
---------- | -------- -------- ------- | -------- -------- -------- --------
 (  8,  3) |     9239     9239     1.0 |        8     2352     2560 21737000

==================== Device Q2Q Seek Information ====================

       DEV |          NSEEKS            MEAN          MEDIAN | MODE           
---------- | --------------- --------------- --------------- | ---------------
 (  8,  3) |            1170       7397036.2               0 | 0(461)
---------- | --------------- --------------- --------------- | ---------------
   Overall |          NSEEKS            MEAN          MEDIAN | MODE           
   Average |            1170       7397036.2               0 | 0(461)

==================== Device D2D Seek Information ====================

       DEV |          NSEEKS            MEAN          MEDIAN | MODE           
---------- | --------------- --------------- --------------- | ---------------
 (  8,  3) |            9239        923170.8               0 | 0(8514)
---------- | --------------- --------------- --------------- | ---------------
   Overall |          NSEEKS            MEAN          MEDIAN | MODE           
   Average |            9239        923170.8               0 | 0(8514)

==================== Plug Information ====================

       DEV |    # Plugs # Timer Us  | % Time Q Plugged
---------- | ---------- ----------  | ----------------
 (  8,  3) |         43(        28) |   0.012839805%

       DEV |    IOs/Unp   IOs/Unp(to)
---------- | ----------   ----------
 (  8,  3) |        3.4          2.8
 (  8,  0) |        0.0          0.0
---------- | ----------   ----------
   Overall |    IOs/Unp   IOs/Unp(to)
   Average |        3.4          2.8

==================== Active Requests At Q Information ====================

       DEV |  Avg Reqs @ Q
---------- | -------------
 (  8,  3) |           0.1

==================== I/O Active Period Information ====================

       DEV |     # Live      Avg. Act     Avg. !Act % Live
---------- | ---------- ------------- ------------- ------
 (  8,  3) |         32   0.044343337   4.275588521   1.06
 (  8,  0) |          0   0.000000000   0.000000000   0.00
---------- | ---------- ------------- ------------- ------
 Total Sys |         32   0.044343337   4.275588521   1.06
 
# Omit some of content because it is too long ....
```

#### Persist - Disk Monitor

```bash
# monitor your mounted disk 
# here my disk is /dev/sda3
##  blktrace -d /dev/sda3 -o - | blkparse  -i -
# part of output is listed below：
 ,3   19      625   164.810927437 2343685  Q   W 80254696 + 8192 [kworker/u128:7]
  8,3   19      626   164.810931532 2343685  X   W 80254696 / 80257256 [kworker/u128:7]
  8,3   19      627   164.815550364 2343685  G   W 80254696 + 2560 [kworker/u128:7]
  8,3   19      628   164.815550784 2343685  I   W 80254696 + 2560 [kworker/u128:7]
  8,3   19      629   164.815567238  1006  D   W 80254696 + 2560 [kworker/19:1H]
  8,3   19      630   164.815576653 2343685  X   W 80257256 / 80259816 [kworker/u128:7]
  8,3   12     5951   164.793295554     0  C   W 80177896 + 2560 [0]
  8,3   12     5952   164.794512228     0  C   W 80180456 + 512 [0]
  8,3   12     5953   164.799423000     0  C   W 80180968 + 2560 [0]
  8,3   12     5954   164.804582911     0  C   W 80183528 + 2560 [0]
  8,3   12     5955   164.809565701     0  C   W 80186088 + 2560 [0]
  8,3   12     5956   164.810340389     0  C   W 80188648 + 512 [0]
  8,3   12     5957   164.815532603     0  C   W 80189160 + 2560 [0]
  8,3   12     5958   164.821793011     0  C   W 80191720 + 2560 [0]
  8,3   12     5959   164.827045237     0  C   W 80194280 + 2560 [0]
  8,3   12     5960   164.827550983     0  C   W 80196840 + 512 [0]
  8,3   12     5961   164.833291321     0  C   W 80197352 + 2560 [0]
  8,3   12     5962   164.839068718     0  C   W 80199912 + 2560 [0]
  8,3   19      631   164.821809587 2343685  G   W 80257256 + 2560 [kworker/u128:7]
  8,3   19      632   164.821810110 2343685  I   W 80257256 + 2560 [kworker/u128:7]
  8,3   19      633   164.821826727  1006  D   W 80257256 + 2560 [kworker/19:1H]
  8,3   19      634   164.821836627 2343685  X   W 80259816 / 80262376 [kworker/u128:7]
  8,3   19      635   164.827061938 2343685  G   W 80259816 + 2560 [kworker/u128:7]
  8,3   19      636   164.827062383 2343685  I   W 80259816 + 2560 [kworker/u128:7]
  8,3   19      637   164.827076544 2343685  D   W 80259816 + 2560 [kworker/u128:7]
  8,3   19      638   164.828118270 2343685  G   W 80262376 + 512 [kworker/u128:7]
  8,3   19      639   164.828118554 2343685  I   W 80262376 + 512 [kworker/u128:7]
  8,3   19      640   164.828125324  1006  D   W 80262376 + 512 [kworker/19:1H]
  8,0   19      641   164.828127704 2343685  A   W 80262888 + 8192 <- (8,3) 76934888
  8,3   19      642   164.828127854 2343685  Q   W 80262888 + 8192 [kworker/u128:7]
  8,3   19      643   164.828129804 2343685  X   W 80262888 / 80265448 [kworker/u128:7]
  8,3   19      644   164.833306136 2343685  G   W 80262888 + 2560 [kworker/u128:7]
  8,3   19      645   164.833306383 2343685  I   W 80262888 + 2560 [kworker/u128:7]
  8,3   19      646   164.833314438  1006  D   W 80262888 + 2560 [kworker/19:1H]
  8,3   19      647   164.833319094 2343685  X   W 80265448 / 80268008 [kworker/u128:7]
  8,3   19      648   164.839085133 2343685  G   W 80265448 + 2560 [kworker/u128:7]
  8,3   19      649   164.839085409 2343685  I   W 80265448 + 2560 [kworker/u128:7]
  8,3   19      650   164.839093459  1006  D   W 80265448 + 2560 [kworker/19:1H]
  8,3   19      651   164.839098021 2343685  X   W 80268008 / 80270568 [kworker/u128:7]
  8,3   19      652   164.844362682 2343685  G   W 80268008 + 2560 [kworker/u128:7]
  8,3   19      653   164.844363160 2343685  I   W 80268008 + 2560 [kworker/u128:7]
  8,3   19      654   164.844377157 2343685  D   W 80268008 + 2560 [kworker/u128:7]
  8,3   19      655   164.845874692 2343685  G   W 80270568 + 512 [kworker/u128:7]
  8,3   19      656   164.845875191 2343685  I   W 80270568 + 512 [kworker/u128:7]
  8,3   19      657   164.845888226  1006  D   W 80270568 + 512 [kworker/19:1H]
  8,0   19      658   164.845893286 2343685  A   W 80271080 + 3672 <- (8,3) 76943080
  8,3   19      659   164.845893737 2343685  Q   W 80271080 + 3672 [kworker/u128:7]
  8,3   19      660   164.845898157 2343685  X   W 80271080 / 80273640 [kworker/u128:7]
  8,3   19      661   164.850533034 2343685  G   W 80271080 + 2560 [kworker/u128:7]
  8,3   19      662   164.850533470 2343685  I   W 80271080 + 2560 [kworker/u128:7]
  8,3   19      663   164.850549080 2343685  D   W 80271080 + 2560 [kworker/u128:7]
  8,3   19      664   164.855298782 2343685  G   W 80273640 + 1112 [kworker/u128:7]
  8,3   19      665   164.855299260 2343685  I   W 80273640 + 1112 [kworker/u128:7]
  8,3   19      666   164.855312052  1006  D   W 80273640 + 1112 [kworker/19:1H]
  8,3   12     5963   164.844345541     0  C   W 80202472 + 2560 [0]
  8,3   12     5964   164.845296997     0  C   W 80205032 + 512 [0]
  8,3   12     5965   164.850515455     0  C   W 80205544 + 2560 [0]
  8,3   12     5966   164.855282125     0  C   W 80208104 + 2560 [0]
  8,3   12     5967   164.860508452     0  C   W 80210664 + 2560 [0]
  8,3   12     5968   164.861495268     0  C   W 80213224 + 512 [0]
  8,3   12     5969   164.866768691     0  C   W 80213736 + 2560 [0]
  8,3   12     5970   164.873098202     0  C   W 80216296 + 2560 [0]
  8,3   12     5971   164.878772652     0  C   W 80218856 + 2560 [0]
  8,3   12     5972   164.879277805     0  C   W 80221416 + 512 [0]
  8,3   12     5973   164.884678127     0  C   W 80221928 + 2560 [0]
  8,3   12     5974   164.890244092     0  C   W 80224488 + 2560 [0]
  8,3   12     5975   164.895364300     0  C   W 80227048 + 2560 [0]
  8,3   12     5976   164.896525889     0  C   W 80229608 + 512 [0]
  8,3   12     5977   164.901396646     0  C   W 80230120 + 2560 [0]
  8,3   12     5978   164.906716828     0  C   W 80232680 + 2560 [0]
  8,3   12     5979   164.912493615     0  C   W 80235240 + 2560 [0]
  8,3   12     5980   164.912998616     0  C   W 80237800 + 512 [0]
  8,3   12     5981   164.918148742     0  C   W 80238312 + 2560 [0]
  8,3   12     5982   164.922465887     0  C   W 80240872 + 2560 [0]
  8,3   12     5983   164.930030955     0  C   W 80243432 + 2560 [0]
  8,3   12     5984   164.930536320     0  C   W 80245992 + 512 [0]
  8,3   12     5985   164.936216402     0  C   W 80246504 + 2560 [0]
  8,3   12     5986   164.941663074     0  C   W 80249064 + 2560 [0]
  8,3   12     5987   164.947013197     0  C   W 80251624 + 2560 [0]
  8,3   12     5988   164.948089755     0  C   W 80254184 + 512 [0]
  8,3   12     5989   164.953257285     0  C   W 80254696 + 2560 [0]
  8,3   12     5990   164.958167588     0  C   W 80257256 + 2560 [0]
  8,3   12     5991   164.965554927     0  C   W 80259816 + 2560 [0]
  8,3   12     5992   164.966648931     0  C   W 80262376 + 512 [0]
  8,3   12     5993   164.972045568     0  C   W 80262888 + 2560 [0]
  8,3   12     5994   164.976749232     0  C   W 80265448 + 2560 [0]
  8,3   12     5995   164.983894839     0  C   W 80268008 + 2560 [0]
  8,3   12     5996   164.984400092     0  C   W 80270568 + 512 [0]
  8,3   12     5997   164.990169962     0  C   W 80271080 + 2560 [0]
  8,3   12     5998   164.992547747     0  C   W 80273640 + 1112 [0]
  8,0   22     1245   166.294138760   927  A  WS 15559336 + 512 <- (8,3) 12231336
  8,3   22     1246   166.294140460   927  Q  WS 15559336 + 512 [btrfs-transacti]
  8,3   22     1247   166.294154025   927  G  WS 15559336 + 512 [btrfs-transacti]
  8,3   22     1248   166.294156168   927  I  WS 15559336 + 512 [btrfs-transacti]
  8,3   22     1249   166.294215183   123  D  WS 15559336 + 512 [kworker/22:0H]
  8,0   22     1250   166.295089205   927  A  WS 37725728 + 512 <- (8,3) 34397728
  8,3   22     1251   166.295089559   927  Q  WS 37725728 + 512 [btrfs-transacti]
  8,3   22     1252   166.295093951   927  G  WS 37725728 + 512 [btrfs-transacti]
  8,3   22     1253   166.295094471   927  I  WS 37725728 + 512 [btrfs-transacti]
  8,3   22     1254   166.295112067   123  D  WS 37725728 + 512 [kworker/22:0H]
  8,0   22     1255   166.295718586   927  A  WS 37726240 + 512 <- (8,3) 34398240
  8,3   22     1256   166.295718826   927  Q  WS 37726240 + 512 [btrfs-transacti]
  8,3   22     1257   166.295721458   927  G  WS 37726240 + 512 [btrfs-transacti]
  8,3   22     1258   166.295721907   927  I  WS 37726240 + 512 [btrfs-transacti]
  8,3   22     1259   166.295734354   123  D  WS 37726240 + 512 [kworker/22:0H]
  8,0   22     1260   166.296635916   927  A  WS 15559336 + 512 <- (8,3) 12231336
  8,3   22     1261   166.296636286   927  Q  WS 15559336 + 512 [btrfs-transacti]
  8,3   22     1262   166.296639926   927  G  WS 15559336 + 512 [btrfs-transacti]
  8,3   22     1263   166.296640424   927  I  WS 15559336 + 512 [btrfs-transacti]
  8,3   22     1264   166.296653538   123  D  WS 15559336 + 512 [kworker/22:0H]
  8,0   22     1265   166.297348550   927  A  WS 39242208 + 512 <- (8,3) 35914208
  8,3   22     1266   166.297348786   927  Q  WS 39242208 + 512 [btrfs-transacti]
  8,3   22     1267   166.297352157   927  G  WS 39242208 + 512 [btrfs-transacti]
  8,3   22     1268   166.297352612   927  I  WS 39242208 + 512 [btrfs-transacti]
  8,3   22     1269   166.297363786   123  D  WS 39242208 + 512 [kworker/22:0H]
  8,0   22     1270   166.298066212   927  A  WS 39243232 + 512 <- (8,3) 35915232
  8,3   22     1271   166.298066450   927  Q  WS 39243232 + 512 [btrfs-transacti]
  8,3   22     1272   166.298069821   927  G  WS 39243232 + 512 [btrfs-transacti]
  8,3   22     1273   166.298070147   927  I  WS 39243232 + 512 [btrfs-transacti]
  8,3   22     1274   166.298084612   123  D  WS 39243232 + 512 [kworker/22:0H]
  8,0   22     1275   166.298761061   927  A  WS 39248928 + 512 <- (8,3) 35920928
  8,3   22     1276   166.298761357   927  Q  WS 39248928 + 512 [btrfs-transacti]
  8,3   22     1277   166.298764629   927  G  WS 39248928 + 512 [btrfs-transacti]
  8,3   22     1278   166.298765021   927  I  WS 39248928 + 512 [btrfs-transacti]
  8,3   22     1279   166.298790743   123  D  WS 39248928 + 512 [kworker/22:0H]
  8,0   22     1280   166.299659727   927  A  WS 15559336 + 512 <- (8,3) 12231336
  8,3   22     1281   166.299660036   927  Q  WS 15559336 + 512 [btrfs-transacti]
  8,3   22     1282   166.299663933   927  G  WS 15559336 + 512 [btrfs-transacti]
  8,3   22     1283   166.299664376   927  I  WS 15559336 + 512 [btrfs-transacti]
  8,3   22     1284   166.299678707   123  D  WS 15559336 + 512 [kworker/22:0H]
  8,0   22     1285   166.300228004   927  A  WS 39248928 + 512 <- (8,3) 35920928
  8,3   22     1286   166.300228213   927  Q  WS 39248928 + 512 [btrfs-transacti]
  8,3   22     1287   166.300230922   927  G  WS 39248928 + 512 [btrfs-transacti]
  8,3   22     1288   166.300231266   927  I  WS 39248928 + 512 [btrfs-transacti]
  8,3   22     1289   166.300244331   123  D  WS 39248928 + 512 [kworker/22:0H]
  8,0   22     1290   166.300941048   927  A WSM 3330048 + 32 <- (8,3) 2048
  8,3   22     1291   166.300941382   927  Q WSM 3330048 + 32 [btrfs-transacti]
  8,3   22     1292   166.300943998   927  G WSM 3330048 + 32 [btrfs-transacti]
  8,3   22     1293   166.300944633   927  P   N [btrfs-transacti]
  8,0   22     1294   166.300969782   927  A WSM 5860192 + 96 <- (8,3) 2532192
  8,3   22     1295   166.300969983   927  Q WSM 5860192 + 96 [btrfs-transacti]
  8,3   22     1296   166.300972024   927  G WSM 5860192 + 96 [btrfs-transacti]
  8,0   22     1297   166.301045204   927  A WSM 5860896 + 96 <- (8,3) 2532896
  8,3   22     1298   166.301045423   927  Q WSM 5860896 + 96 [btrfs-transacti]
  8,3   22     1299   166.301047315   927  G WSM 5860896 + 96 [btrfs-transacti]
  8,0   22     1300   166.301187633   927  A WSM 5861664 + 384 <- (8,3) 2533664
  8,3   22     1301   166.301187845   927  Q WSM 5861664 + 384 [btrfs-transacti]
  8,3   22     1302   166.301195397   927  G WSM 5861664 + 384 [btrfs-transacti]
  8,0   22     1303   166.301694805   927  A WSM 5862080 + 384 <- (8,3) 2534080
  8,3   22     1304   166.301695022   927  Q WSM 5862080 + 384 [btrfs-transacti]
  8,3   22     1305   166.301697545   927  G WSM 5862080 + 384 [btrfs-transacti]
  8,3   22     1306   166.301698313   927  U   N [btrfs-transacti] 4
  8,3   22     1307   166.301698620   927  I WSM 3330048 + 32 [btrfs-transacti]
  8,3   22     1308   166.301701500   927  I WSM 5860192 + 96 [btrfs-transacti]
  8,3   22     1309   166.301703545   927  I WSM 5860896 + 96 [btrfs-transacti]
  8,3   22     1310   166.301705415   927  I WSM 5861664 + 384 [btrfs-transacti]
  8,3   22     1311   166.301712292   927  D WSM 3330048 + 32 [btrfs-transacti]
  8,3   22     1312   166.301719019   927  D WSM 5860192 + 96 [btrfs-transacti]
  8,3   22     1313   166.301724365   927  D WSM 5860896 + 96 [btrfs-transacti]
  8,3   22     1314   166.301729323   927  D WSM 5861664 + 384 [btrfs-transacti]
  8,3   22     1315   166.301735157   927  P   N [btrfs-transacti]
  8,0   22     1316   166.301968105   927  A WSM 5862496 + 192 <- (8,3) 2534496
  8,3   22     1317   166.301968343   927  Q WSM 5862496 + 192 [btrfs-transacti]
  8,3   22     1318   166.301970595   927  G WSM 5862496 + 192 [btrfs-transacti]
  8,3   22     1319   166.301970903   927  U   N [btrfs-transacti] 1
  8,3   22     1320   166.301971142   927  I WSM 5862080 + 384 [btrfs-transacti]
  8,3   22     1321   166.301977195   927  D WSM 5862080 + 384 [btrfs-transacti]
  8,3   22     1322   166.301982594   927  P   N [btrfs-transacti]
  8,0   22     1323   166.302198475   927  A WSM 5862752 + 192 <- (8,3) 2534752
  8,3   22     1324   166.302198787   927  Q WSM 5862752 + 192 [btrfs-transacti]
  8,3   22     1325   166.302201288   927  G WSM 5862752 + 192 [btrfs-transacti]
  8,0   22     1326   166.302553357   927  A WSM 5863040 + 256 <- (8,3) 2535040
  8,3   22     1327   166.302553594   927  Q WSM 5863040 + 256 [btrfs-transacti]
  8,3   22     1328   166.302556174   927  G WSM 5863040 + 256 [btrfs-transacti]
  8,0   22     1329   166.302923067   927  A WSM 7218304 + 224 <- (8,3) 3890304
  8,3   22     1330   166.302923304   927  Q WSM 7218304 + 224 [btrfs-transacti]
  8,3   22     1331   166.302925697   927  G WSM 7218304 + 224 [btrfs-transacti]
  8,3   22     1332   166.302926064   927  U   N [btrfs-transacti] 3
  8,3   22     1333   166.302926269   927  I WSM 5862496 + 192 [btrfs-transacti]
  8,3   22     1334   166.302929049   927  I WSM 5862752 + 192 [btrfs-transacti]
  8,3   22     1335   166.302930934   927  I WSM 5863040 + 256 [btrfs-transacti]
  8,3   22     1336   166.302936659   927  D WSM 5862496 + 192 [btrfs-transacti]
  8,3   22     1337   166.302942324   927  D WSM 5862752 + 192 [btrfs-transacti]
  8,3   22     1338   166.302947834   927  D WSM 5863040 + 256 [btrfs-transacti]
  8,3   22     1339   166.302952514   927  P   N [btrfs-transacti]
  8,0   22     1340   166.303054159   927  A WSM 7218784 + 448 <- (8,3) 3890784
  8,3   22     1341   166.303054369   927  Q WSM 7218784 + 448 [btrfs-transacti]
  8,3   22     1342   166.303057071   927  G WSM 7218784 + 448 [btrfs-transacti]
  8,0   22     1343   166.303080672   927  A WSM 7219424 + 96 <- (8,3) 3891424
  8,3   22     1344   166.303080911   927  Q WSM 7219424 + 96 [btrfs-transacti]
  8,3   22     1345   166.303082685   927  G WSM 7219424 + 96 [btrfs-transacti]
  8,3   22     1346   166.303083049   927  U   N [btrfs-transacti] 2
  8,3   22     1347   166.303083261   927  I WSM 7218304 + 224 [btrfs-transacti]
  8,3   22     1348   166.303085227   927  I WSM 7218784 + 448 [btrfs-transacti]
  8,3   22     1349   166.303090725   927  D WSM 7218304 + 224 [btrfs-transacti]
  8,3   22     1350   166.303107985   927  D WSM 7218784 + 448 [btrfs-transacti]
  8,3   22     1351   166.303113258   927  P   N [btrfs-transacti]
  8,0   22     1352   166.303123264   927  A WSM 7219552 + 32 <- (8,3) 3891552
  8,3   22     1353   166.303123479   927  Q WSM 7219552 + 32 [btrfs-transacti]
  8,3   22     1354   166.303125999   927  G WSM 7219552 + 32 [btrfs-transacti]
  8,0   22     1355   166.303148438   927  A WSM 7219616 + 96 <- (8,3) 3891616
  8,3   22     1356   166.303148667   927  Q WSM 7219616 + 96 [btrfs-transacti]
  8,3   22     1357   166.303150239   927  G WSM 7219616 + 96 [btrfs-transacti]
  8,0   22     1358   166.303160347   927  A WSM 7219744 + 32 <- (8,3) 3891744
  8,3   22     1359   166.303160541   927  Q WSM 7219744 + 32 [btrfs-transacti]
  8,3   22     1360   166.303161984   927  G WSM 7219744 + 32 [btrfs-transacti]
  8,0   22     1361   166.303183234   927  A WSM 7219872 + 64 <- (8,3) 3891872
  8,3   22     1362   166.303183483   927  Q WSM 7219872 + 64 [btrfs-transacti]
  8,3   22     1363   166.303185889   927  G WSM 7219872 + 64 [btrfs-transacti]
  8,0   22     1364   166.303199347   927  A WSM 7219968 + 32 <- (8,3) 3891968
  8,3   22     1365   166.303199584   927  Q WSM 7219968 + 32 [btrfs-transacti]
  8,3   22     1366   166.303202667   927  G WSM 7219968 + 32 [btrfs-transacti]
  8,0   22     1367   166.303219163   927  A WSM 7220032 + 64 <- (8,3) 3892032
  8,3   22     1368   166.303219369   927  Q WSM 7220032 + 64 [btrfs-transacti]
  8,3   22     1369   166.303221151   927  G WSM 7220032 + 64 [btrfs-transacti]
  8,0   22     1370   166.303237052   927  A WSM 7220576 + 64 <- (8,3) 3892576
  8,3   22     1371   166.303237252   927  Q WSM 7220576 + 64 [btrfs-transacti]
  8,3   22     1372   166.303239538   927  G WSM 7220576 + 64 [btrfs-transacti]
  8,0   22     1373   166.303365214   927  A WSM 7220672 + 256 <- (8,3) 3892672
  8,3   22     1374   166.303365452   927  Q WSM 7220672 + 256 [btrfs-transacti]
  8,3   22     1375   166.303367799   927  G WSM 7220672 + 256 [btrfs-transacti]
  8,0   22     1376   166.303384183   927  A WSM 7221280 + 64 <- (8,3) 3893280
  8,3   22     1377   166.303384416   927  Q WSM 7221280 + 64 [btrfs-transacti]
  8,3   22     1378   166.303386572   927  G WSM 7221280 + 64 [btrfs-transacti]
  8,3   22     1379   166.303386909   927  U   N [btrfs-transacti] 9
  8,3   22     1380   166.303387129   927  I WSM 7219424 + 96 [btrfs-transacti]
  8,3   22     1381   166.303389066   927  I WSM 7219552 + 32 [btrfs-transacti]
  8,3   22     1382   166.303390806   927  I WSM 7219616 + 96 [btrfs-transacti]
  8,3   22     1383   166.303392419   927  I WSM 7219744 + 32 [btrfs-transacti]
  8,3   22     1384   166.303394169   927  I WSM 7219872 + 64 [btrfs-transacti]
  8,3   22     1385   166.303396003   927  I WSM 7219968 + 32 [btrfs-transacti]

  
#########################################################################################
## blktrace -d /dev/sda3
^C=== sda3 ===
  CPU  0:                37234 events,     1746 KiB data
  CPU  1:                    0 events,        0 KiB data
  CPU  2:                    0 events,        0 KiB data
  CPU  3:                10935 events,      513 KiB data
  CPU  4:                    0 events,        0 KiB data
  CPU  5:                  407 events,       20 KiB data
  CPU  6:                    4 events,        1 KiB data
  CPU  7:                  512 events,       25 KiB data
  CPU  8:                 2698 events,      127 KiB data
  CPU  9:                10934 events,      513 KiB data
  CPU 10:                    0 events,        0 KiB data
  CPU 11:                    0 events,        0 KiB data
  CPU 12:               234515 events,    10993 KiB data
  CPU 13:                15090 events,      708 KiB data
  CPU 14:                 4318 events,      203 KiB data
  CPU 15:                24008 events,     1126 KiB data
  CPU 16:                12272 events,      576 KiB data
  CPU 17:                39067 events,     1832 KiB data
  CPU 18:                10923 events,      513 KiB data
  CPU 19:                    0 events,        0 KiB data
  CPU 20:                    0 events,        0 KiB data
  CPU 21:                 5086 events,      239 KiB data
  CPU 22:                    0 events,        0 KiB data
  CPU 23:                    0 events,        0 KiB data
  CPU 24:                    0 events,        0 KiB data
  CPU 25:                    0 events,        0 KiB data
  CPU 26:                    0 events,        0 KiB data
  CPU 27:                    0 events,        0 KiB data
  CPU 28:                    0 events,        0 KiB data
  CPU 29:                    1 events,        1 KiB data
  CPU 30:                 3287 events,      155 KiB data
  CPU 31:                19566 events,      918 KiB data
  CPU 32:                 1481 events,       70 KiB data
  CPU 33:                   64 events,        4 KiB data
  CPU 34:                10985 events,      515 KiB data
  CPU 35:                    0 events,        0 KiB data
  CPU 36:                    0 events,        0 KiB data
  CPU 37:                  821 events,       39 KiB data
  CPU 38:                10926 events,      513 KiB data
  CPU 39:                    0 events,        0 KiB data
  CPU 40:                    0 events,        0 KiB data
  CPU 41:                    0 events,        0 KiB data
  CPU 42:                    0 events,        0 KiB data
  CPU 43:                    0 events,        0 KiB data
  CPU 44:                 3326 events,      156 KiB data
  CPU 45:                    0 events,        0 KiB data
  CPU 46:                 9591 events,      450 KiB data
  CPU 47:                 3310 events,      156 KiB data
  CPU 48:                  146 events,        7 KiB data
  CPU 49:                    0 events,        0 KiB data
  CPU 50:                 8408 events,      395 KiB data
  CPU 51:                    0 events,        0 KiB data
  CPU 52:                    0 events,        0 KiB data
  CPU 53:                13075 events,      613 KiB data
  CPU 54:                 4369 events,      205 KiB data
  CPU 55:                 1105 events,       52 KiB data
  CPU 56:                10930 events,      513 KiB data
  CPU 57:                    0 events,        0 KiB data
  CPU 58:                    0 events,        0 KiB data
  CPU 59:                    0 events,        0 KiB data
  CPU 60:                    0 events,        0 KiB data
  CPU 61:                    0 events,        0 KiB data
  CPU 62:                    0 events,        0 KiB data
  CPU 63:                    0 events,        0 KiB data
  Total:                509394 events (dropped 0),    23879 KiB data


-----------------------------------------------------------------------------------------
## blkparse -i sda3 -d persist.bin

CPU0 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         379,    1,151MiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:    1,112,    1,129MiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            1,      180KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU3 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          55,  381,840KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      327,  376,720KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU5 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          16,      116KiB
 Read Dispatches:        1,        0KiB	 Write Dispatches:       12,      116KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            3,       24KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             2        	 Timer unplugs:           0
CPU7 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:           0,        0KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:       24,   24,356KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU8 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          24,   93,732KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:       93,   95,012KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU9 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         191,  262,416KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      375,  260,368KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU12 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         652,    1,448MiB
 Read Dispatches:       36,        0KiB	 Write Dispatches:    1,718,    1,495MiB
 Reads Requeued:        11		 Writes Requeued:         0
 Reads Completed:       36,        0KiB	 Writes Completed:   10,089,    9,683MiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 PC Reads Queued:        0,        0KiB	 PC Writes Queued:        0,        0KiB
 PC Read Disp.:          0,        0KiB	 PC Write Disp.:          0,        0KiB
 PC Reads Req.:          0		 PC Writes Req.:          0
 PC Reads Compl.:        5		 PC Writes Compl.:        0
 IO unplugs:            51        	 Timer unplugs:           0
CPU13 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         178,  433,448KiB
 Read Dispatches:        1,        0KiB	 Write Dispatches:      448,  428,060KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             8        	 Timer unplugs:           0
CPU14 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          68,   73,660KiB
 Read Dispatches:        1,        0KiB	 Write Dispatches:      109,   73,660KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             4        	 Timer unplugs:           0
CPU15 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         194,  784,744KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      709,  768,664KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             3        	 Timer unplugs:           0
CPU16 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         129,  344,320KiB
 Read Dispatches:        1,        0KiB	 Write Dispatches:      365,  342,784KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             3        	 Timer unplugs:           0
CPU17 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         325,    1,235MiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:    1,134,    1,232MiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU18 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          67,  324,084KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      300,  321,012KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU21 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          84,  167,524KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      167,  167,524KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU30 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          47,   87,332KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:       96,   87,332KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU31 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         165,  617,532KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      609,  613,180KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU32 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:           7,   55,072KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:       47,   55,072KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU33 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:           1,      512KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:        1,      512KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU34 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          56,  369,696KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      320,  368,176KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU37 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          11,   10,320KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:       21,   10,320KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU38 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          93,  338,768KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      325,  334,160KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU44 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         104,   17,816KiB
 Read Dispatches:        3,        0KiB	 Write Dispatches:      101,   17,816KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             9        	 Timer unplugs:           0
CPU46 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          49,  335,540KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      290,  332,980KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU47 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          18,  134,784KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      114,  132,224KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 PC Reads Queued:        0,        0KiB	 PC Writes Queued:        0,        0KiB
 PC Read Disp.:          5,        1KiB	 PC Write Disp.:          0,        0KiB
 PC Reads Req.:          0		 PC Writes Req.:          0
 PC Reads Compl.:        0		 PC Writes Compl.:        0
 IO unplugs:             0        	 Timer unplugs:           0
CPU48 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:           8,       72KiB
 Read Dispatches:        2,        0KiB	 Write Dispatches:        4,       72KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            2,       32KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             2        	 Timer unplugs:           0
CPU50 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          41,  296,472KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      250,  288,280KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU53 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:         363,  158,052KiB
 Read Dispatches:        2,        0KiB	 Write Dispatches:      463,  170,476KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:            23        	 Timer unplugs:           0
CPU54 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          39,  147,116KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      146,  147,116KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU55 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:           6,   24,568KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:       24,   24,568KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0
CPU56 (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:          69,  388,504KiB
 Read Dispatches:        0,        0KiB	 Write Dispatches:      349,  385,432KiB
 Reads Requeued:         0		 Writes Requeued:         0
 Reads Completed:        0,        0KiB	 Writes Completed:        0,        0KiB
 Read Merges:            0,        0KiB	 Write Merges:            0,        0KiB
 Read depth:             1        	 Write depth:            32
 IO unplugs:             0        	 Timer unplugs:           0

Total (sda3):
 Reads Queued:           0,        0KiB	 Writes Queued:       3,439,    9,683MiB
 Read Dispatches:       47,        0KiB	 Write Dispatches:   10,053,    9,683MiB
 Reads Requeued:        11		 Writes Requeued:         0
 Reads Completed:       36,        0KiB	 Writes Completed:   10,089,    9,683MiB
 Read Merges:            0,        0KiB	 Write Merges:            6,      236KiB
 PC Reads Queued:        0,        0KiB	 PC Writes Queued:        0,        0KiB
 PC Read Disp.:          5,        1KiB	 PC Write Disp.:          0,        0KiB
 PC Reads Req.:          0		 PC Writes Req.:          0
 PC Reads Compl.:        5		 PC Writes Compl.:        0
 IO unplugs:           105        	 Timer unplugs:           0

Throughput (R/W): 0KiB/s / 22,585KiB/s
Events (sda3): 54,066 entries
Skips: 0 forward (0 -   0.0%)

-----------------------------------------------------------------------------------------
# btt -i persist.bin -o persist
# cat persist.avg

==================== All Devices ====================

            ALL           MIN           AVG           MAX           N
--------------- ------------- ------------- ------------- -----------

Q2Q               0.000004147   0.125359659  30.193228866        3420
Q2A              15.262302296  76.189369431 309.254030474         914
Q2G               0.000000305   0.009036609   0.070659840       10053
G2I               0.000000115   0.000013699   0.001318605       10033
Q2M               0.000000569   0.000001439   0.000002079           6
I2D               0.000002502   0.000043865   0.005164352         862
M2D               0.000019166   0.010120207   0.040130592           4
D2C               0.000028888   0.019429091   0.189601567         886
Q2C               0.000031446   0.020122203   0.199053340         886

==================== Device Overhead ====================

       DEV |       Q2G       G2I       Q2M       I2D       D2C
---------- | --------- --------- --------- --------- ---------
 (  8,  3) | 509.5560%   0.7709%   0.0000%   0.2121%  96.5555%
---------- | --------- --------- --------- --------- ---------
   Overall | 509.5560%   0.7709%   0.0000%   0.2121%  96.5555%

==================== Device Merge Information ====================

       DEV |       #Q       #D   Ratio |   BLKmin   BLKavg   BLKmax    Total
---------- | -------- -------- ------- | -------- -------- -------- --------
 (  8,  3) |    10053    10053     1.0 |        8     1926     2560 19366376

==================== Device Q2Q Seek Information ====================

       DEV |          NSEEKS            MEAN          MEDIAN | MODE           
---------- | --------------- --------------- --------------- | ---------------
 (  8,  3) |            3421       2300367.7               0 | 0(2456)
---------- | --------------- --------------- --------------- | ---------------
   Overall |          NSEEKS            MEAN          MEDIAN | MODE           
   Average |            3421       2300367.7               0 | 0(2456)

==================== Device D2D Seek Information ====================

       DEV |          NSEEKS            MEAN          MEDIAN | MODE           
---------- | --------------- --------------- --------------- | ---------------
 (  8,  3) |           10053        775209.1               0 | 0(9085)
---------- | --------------- --------------- --------------- | ---------------
   Overall |          NSEEKS            MEAN          MEDIAN | MODE           
   Average |           10053        775209.1               0 | 0(9085)

==================== Plug Information ====================

       DEV |    # Plugs # Timer Us  | % Time Q Plugged
---------- | ---------- ----------  | ----------------
 (  8,  3) |        105(         0) |   0.007109606%

       DEV |    IOs/Unp   IOs/Unp(to)
---------- | ----------   ----------
 (  8,  0) |        0.0          0.0
 (  8,  3) |        4.7          0.0
---------- | ----------   ----------
   Overall |    IOs/Unp   IOs/Unp(to)
   Average |        4.7          0.0

==================== Active Requests At Q Information ====================

       DEV |  Avg Reqs @ Q
---------- | -------------
 (  8,  3) |           0.3

==================== I/O Active Period Information ====================

       DEV |     # Live      Avg. Act     Avg. !Act % Live
---------- | ---------- ------------- ------------- ------
 (  8,  0) |          0   0.000000000   0.000000000   0.00
 (  8,  3) |        286   0.051384028   1.452751742   3.43
---------- | ---------- ------------- ------------- ------
 Total Sys |        286   0.051384028   1.452751742   3.43

```



#### 