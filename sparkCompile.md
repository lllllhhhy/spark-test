#### 

###  install standalone-linux-io-tracer

```shell
git clone https://github.com/Open-CAS/standalone-linux-io-tracer/
cd standalone-linux-io-tracer
cd modules
# 之后看到里面的open-cas-telemetry-framework下面什么都没有，于是去下载：
git clone https://github.com/open-cas/open-cas-telemetry-framework
cd open-cas-telemetry-framework
sudo ./setup_dependencies.sh
#检查发现缺少第三方库，于是vim .gitmodule查看缺什么
# 之后到顶层目录下执行
sudo ./setup_dependencies.sh
make
#之后到standalone-linux-io-tracer这个目录下再次make
sudo make install
```



### modify the shell to support Iotrace automatically

parse.sh为自动化日志处理函数，集成在 TPCx-HS-master.sh中

```shell
#!/bin/bash

# add the parse.sh shell script into the Benchmark to generate logs automatically
# shell传入的第一个参数表示处理哪种文件系统：
# xfs-tpc-iotrace or btrfs-tpc-iotrace


# 定义通用函数

function parse_fs_statistics()
{
cat << EOF
This script start handling with the iotrace log --fs-statistics ... 
EOF
    arr=($1);
    baseDir=$2;
    fullDir=$3/$2;
    cpDir=$4;

    for i in ${arr[*]}; do
       #	order="$(iotrace --trace-parser --fs-statistics -p "kernel/$baseDir/${arr[$i]}/")"
	#$order > $fullDir/${arr[$i]}_xfs.txt
         iotrace --trace-parser --fs-statistics -p ""kernel/$baseDir/${i}/"" > $fullDir/${i}/${i}_fs.txt
	 cp $fullDir/${i}/${i}_fs.txt  $cpDir
    done;

}

function parse_latency_histogram()
{
cat << EOF
This script start handling with the iotrace log --latency-histogram ... 
EOF
    arr=$1;
    baseDir=$2;
    fullDir=$3/$2;
    cpDir=$4;

    for i in ${arr[*]}; do
        iotrace --trace-parser --latency-histogram -p ""kernel/$baseDir/${i}/"" > $fullDir/${i}/${i}_latency.txt
	cp $fullDir/${i}/${i}_latency.txt  $cpDir
    done;

}

function parse_lba_histogram()
{
cat << EOF
This script start handling with the iotrace log --lba-histogram ... 
EOF
    arr=$1;
    baseDir=$2;
    fullDir=$3/$2;
    cpDir=$4;

    for i in ${arr[*]}; do
        iotrace --trace-parser --lba-histogram -p ""kernel/$baseDir/${i}/"" > $fullDir/${i}/${i}_lba.txt
	cp $fullDir/${i}/${i}_lba.txt $cpDir
    done;

}

function parse_io_json()
{
cat << EOF
This script start handling with the iotrace log --io json ... 
EOF
    arr=$1;
    baseDir=$2;
    fullDir=$3/$2;
    cpDir=$4;

    for i in ${arr[*]}; do
        iotrace --trace-parser  --io --path ""kernel/$baseDir/${i}/"" > $fullDir/${i}/${i}_io_json.txt
	cp $fullDir/${i}/${i}_io_json.txt $cpDir
    done;

}


if [[ $# == 0 ]];then
    echo "please input the type xfs or btrfs...";
    exit;
fi

# 第一个参数代表处理哪一部分日志
logBaseDir=""
if [[ $1 == "xfs" ]];then
    logBaseDir="xfs-tpc-iotrace";
else
    logBaseDir="btrfs-tpc-iotrace";
fi



# 设置文件夹位置 存放新生成的iotrace
logDir="/var/lib/octf/trace/kernel";

# cd到"/var/lib/octf/trace/kernel"路径下
cd $logDir;

# 默认更新了六个文件夹，分别重命名之
dirGet=(`ls -t $logDir`);

if [[ ${#dirGet[@]} == 2 ]];then
	echo "the log is not generated .. exit";
	exit 2;
fi


HSGen_1="HSGen_1";
HSGen_2="HSGen_2";
HSsort_1="HSsort_1";
HSsort_2="HSsort_2";
Hvalidate_1="HSvalidate_1";
Hvalidate_2="HSvalidate_2";
# 标准名称
dirArr=($Hvalidate_2 $HSsort_2 $HSGen_2 $Hvalidate_1 $HSsort_1 $HSGen_1);

# 获取隐藏文件.Version版本号，防止覆盖原有的文件夹
if [ ! -f $logDir/$logBaseDir/.Version ];then
    echo "1">$logDir/$logBaseDir/.Version
    systemVersion=""
else
   systemVersion=`cat $logDir/$logBaseDir/.Version`
   # 版本自增
   version=$((systemVersion+1))
   echo $version > $logDir/$logBaseDir/.Version
fi

for i in {0..5}; 
  do 
     #echo "22"
     printf "%s\t%s\n" "$i" "${dirGet[$i]}" "checked..";
       # 为了表示名称唯一性，如果有重复，则加上时间戳
        if [ ! -d $logDir/$logBaseDir/${dirArr[$i]} ];then
            mv ${dirGet[$i]} ${dirArr[$i]};
	    echo "========不重复========"
        else
           mv ${dirGet[$i]} "${systemVersion}_${dirArr[$i]}";
	   echo "${systemNs}_${dirArr[$i]}"
           dirArr[$i]="${systemVersion}_${dirArr[$i]}";
	    echo "========重复========"
        fi
        mv  ${dirArr[$i]}  $logDir/$logBaseDir
done

# 开始处理日志命令
#备份日志的地方

# 可以人为进行指定 QuickTPcx.sh只是快速启动脚本而已，可以将cpDir修改为你想要存放日志的地方
cpDir=`find  /root  -name  "QuickTPcx.sh" | awk -F '/[^/]*$' '{print $1}'`
parse_fs_statistics "${dirArr[*]}" "$logBaseDir" "$logDir" "$cpDir"
parse_latency_histogram "${dirArr[*]}" "$logBaseDir" "$logDir" "$cpDir"
parse_lba_histogram "${dirArr[*]}" "$logBaseDir" "$logDir" "$cpDir"
parse_io_json "${dirArr[*]}" "$logBaseDir" "$logDir" "$cpDir"
```

```shell
 # in TPCx-HS-master.sh
 
 #!/bin/bash
#
# Legal Notice
#
# This document and associated source code (the "Work") is a part of a
# benchmark specification maintained by the TPC.
#
# The TPC reserves all right, title, and interest to the Work as provided
# under U.S. and international laws, including without limitation all patent
# and trademark rights therein.
#
# No Warranty
#
# 1.1 TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE INFORMATION
#     CONTAINED HEREIN IS PROVIDED "AS IS" AND WITH ALL FAULTS, AND THE
#     AUTHORS AND DEVELOPERS OF THE WORK HEREBY DISCLAIM ALL OTHER
#     WARRANTIES AND CONDITIONS, EITHER EXPRESS, IMPLIED OR STATUTORY,
#     INCLUDING, BUT NOT LIMITED TO, ANY (IF ANY) IMPLIED WARRANTIES,
#     DUTIES OR CONDITIONS OF MERCHANTABILITY, OF FITNESS FOR A PARTICULAR
#     PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OF
#     WORKMANLIKE EFFORT, OF LACK OF VIRUSES, AND OF LACK OF NEGLIGENCE.
#     ALSO, THERE IS NO WARRANTY OR CONDITION OF TITLE, QUIET ENJOYMENT,
#     QUIET POSSESSION, CORRESPONDENCE TO DESCRIPTION OR NON-INFRINGEMENT
#     WITH REGARD TO THE WORK.
# 1.2 IN NO EVENT WILL ANY AUTHOR OR DEVELOPER OF THE WORK BE LIABLE TO
#     ANY OTHER PARTY FOR ANY DAMAGES, INCLUDING BUT NOT LIMITED TO THE
#     COST OF PROCURING SUBSTITUTE GOODS OR SERVICES, LOST PROFITS, LOSS
#     OF USE, LOSS OF DATA, OR ANY INCIDENTAL, CONSEQUENTIAL, DIRECT,
#     INDIRECT, OR SPECIAL DAMAGES WHETHER UNDER CONTRACT, TORT, WARRANTY,
#     OR OTHERWISE, ARISING IN ANY WAY OUT OF THIS OR ANY OTHER AGREEMENT
#     RELATING TO THE WORK, WHETHER OR NOT SUCH AUTHOR OR DEVELOPER HAD
#     ADVANCE NOTICE OF THE POSSIBILITY OF SUCH DAMAGES.
#

shopt -s expand_aliases


VERSION=`cat ./VERSION.txt`
MR_HSSORT_JAR="TPCx-HS-master_MR2.jar"
SPARK_HSSORT_JAR="TPCx-HS-master_Spark.jar"
isXfs=0;

#script assumes clush or pdsh
#unalias psh
if (type clush > /dev/null); then
  alias psh=clush
  alias dshbak=clubak
  CLUSTER_SHELL=1
elif (type pdsh > /dev/null); then
  CLUSTER_SHELL=1
  alias psh=pdsh
fi
parg="-a"

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
   -m  Use the MapReduce framework
   -s  Use the Spark framework
   -g  <TPCx-HS Scale Factor option from below>
       1   Run TPCx-HS for 10GB (For test purpose only, not a valid Scale Factor)
       2   Run TPCx-HS for 1TB
       3   Run TPCx-HS for 3TB
       4   Run TPCx-HS for 10TB
       5   Run TPCx-HS for 30TB
       6   Run TPCx-HS for 100TB
       7   Run TPCx-HS for 300TB
       8   Run TPCx-HS for 1000TB
       9   Run TPCx-HS for 3000TB
       10  Run TPCx-HS for 10000TB

   Example: $0 -m -g 2

EOF
}


while getopts "xbhmsg:" OPTION; do
     case ${OPTION} in
         x) 
            echo "using the file system xfs..."
            isXfs=1
            sleep 5
             ;;
         b) 
            echo "using the file system btrfs..."
            isXfs=0
            sleep 5
             ;;

         h) usage
                exit
             ;;
         m) FRAMEWORK="MapReduce"
             HSSORT_JAR="$MR_HSSORT_JAR"
             ;;
         s) FRAMEWORK="Spark"
             HSSORT_JAR="$SPARK_HSSORT_JAR"
             ;;
         g)  sze=$OPTARG
 			 case $sze in
				1) hssize="400000000"
				   prefix="4GB"
				     ;;
				2) hssize="10000000000"
				   prefix="1TB"
					 ;;
				3) hssize="30000000000"
				   prefix="3TB"
					 ;;	
				4) hssize="100000000000"
				   prefix="10TB"
					 ;;	
				5) hssize="300000000000"
				   prefix="30TB"
					 ;;	
				6) hssize="1000000000000"
				   prefix="100TB"
					 ;;	
				7) hssize="3000000000000"
				   prefix="300TB"
					 ;;	
				8) hssize="10000000000000"
				   prefix="1000TB"
					 ;;	
				9) hssize="30000000000000"
				   prefix="3000TB"
					 ;;	
				10) hssize="100000000000000"
				   prefix="10000TB"
					 ;;						 					 	     
				?) hssize="1000000000"
				   prefix="100GB"
				   ;;
			 esac
             ;;
         ?)  echo -e "${red}Please choose a vlaid option${NC}"
             usage
             exit 2
             ;;
    esac
done

# 不加参数表示使用 /${FILE_BASE} 加参数表示使用你加的目录
if [[ $isXfs == 0 ]];then
    source ./Benchmark_Parameters.sh mybtrfs
else
    source ./Benchmark_Parameters.sh
fi

if [ -z "$FRAMEWORK" ]; then
    echo
    echo "Please specify the framework to use (-m or -s)"
    echo
    usage
    exit 2
elif [ -z "$hssize" ]; then
    echo
    echo "Please specify the scale factor to use (-g)"
    echo
    usage
    exit 2
fi


if [ -f ./TPCx-HS-result-"$prefix".log ]; then
   mv ./TPCx-HS-result-"$prefix".log ./TPCx-HS-result-"$prefix".log.`date +%Y%m%d%H%M%S`
fi

echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}Running $prefix test${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}HSsize is $hssize${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}All Output will be logged to file ./TPCx-HS-result-$prefix.log${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log

## CLUSTER VALIDATE SUITE ##


if [ $CLUSTER_SHELL -eq 1 ]
then
   echo -e "${green}$sep${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
   echo -e "${green} Running Cluster Validation Suite${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
   echo -e "${green}$sep${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
   echo "" | tee -a ./TPCx-HS-result-"$prefix".log
   echo "" | tee -a ./TPCx-HS-result-"$prefix".log

   source ./BigData_cluster_validate_suite.sh | tee -a ./TPCx-HS-result-"$prefix".log

   echo "" | tee -a ./TPCx-HS-result-"$prefix".log
   echo -e "${green} End of Cluster Validation Suite${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
   echo "" | tee -a ./TPCx-HS-result-"$prefix".log
   echo "" | tee -a ./TPCx-HS-result-"$prefix".log
else
   echo -e "${red}CLUSH NOT INSTALLED for cluster audit report${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
   echo -e "${red}To install clush follow USER_GUIDE.txt${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
fi

## BIGDATA BENCHMARK SUITE ##

# Note for 1TB (1000000000000), input for HSgen => 10000000000 (so many 100 byte words)
#############################################################################
# sudo -u $HDFS_USER hadoop fs -mkdir /user
# sudo -u $HDFS_USER hadoop fs -mkdir /user/"$HADOOP_USER"
# sudo -u $HDFS_USER hadoop fs -chown "$HADOOP_USER":"$HADOOP_USER" /user/"$HADOOP_USER"
sudo mkdir -p /${FILE_BASE}
# 读写
sudo mkdir -p /${FILE_BASE}/input
# sort排完序 写到这里
sudo mkdir -p /${FILE_BASE}/output
# 数据验证放到这里
sudo mkdir -p /${FILE_BASE}/validate
###############################################################################


for i in `seq 1 2`;
do

benchmark_result=1

echo -e "${green}$sep${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}Deleting Previous Data - Start - `date`${NC}" | tee -a ./TPCx-HS-result-"$prefix".log

# 如果有数据，先删除之
sudo rm /${FILE_BASE}/input/*
sudo rm /${FILE_BASE}/output/*
sudo rm /${FILE_BASE}/validate/*

sleep $SLEEP_BETWEEN_RUNS
echo -e "${green}Deleting Previous Data - End - `date`${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}$sep${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log

start=`date +%s`
echo -e "${green}$sep${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green} Running BigData TPCx-HS Benchmark Suite ($FRAMEWORK) - Run $i - Epoch $start ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green} TPCx-HS Version $VERSION ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}$sep${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}Starting HSGen Run $i (output being written to ./logs/HSgen-time-run$i.txt)${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log


mkdir -p ./logs
if [ "$FRAMEWORK" = "MapReduce" ]; then
    (time hadoop jar $HSSORT_JAR HSGen -Dmapreduce.job.maps=$NUM_MAPS -Dmapreduce.job.reduces=$NUM_REDUCERS -Dmapred.map.tasks=$NUM_MAPS -Dmapred.reduce.tasks=$NUM_REDUCERS $hssize /${FILE_BASE}/input) 2> >(tee ./logs/HSgen-time-run$i.txt) 
else
    ############################## iostrace #########################
    nohup iotrace --start-tracing --devices ${DeviceBlock} --time 3600 --size 10240  1>&2 2>/dev/null &
    ##############################  iostrace #########################
    (time spark-submit --class HSGen --deploy-mode ${SPARK_DEPLOY_MODE} --master ${SPARK_MASTER_URL} --conf "spark.driver.memory=${SPARK_DRIVER_MEMORY}" --conf "spark.executor.memory=${SPARK_EXECUTOR_MEMORY}" --conf "spark.executor.cores=${SPARK_EXECUTOR_CORES}" --conf "spark.executor.instances=${SPARK_EXECUTOR_INSTANCES}" ${HSSORT_JAR} ${hssize} /${FILE_BASE}/input) 2>&1 | (tee ./logs/HSgen-time-run${i}.txt)
fi
result=$?

cat ./logs/HSgen-time-run${i}.txt >> ./TPCx-HS-result-"$prefix".log

if [ $result -ne 0 ]
then
echo -e "${red}======== HSgen Result FAILURE ========${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
benchmark_result=0
else
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}======== HSgen Result SUCCESS ========${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}======== Time taken by HSGen = `grep real ./logs/HSgen-time-run$i.txt | awk '{print $2}'`====${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
fi

echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}Listing HSGen output ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
./HSDataCheck.sh /${FILE_BASE}/input  | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log

echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}Starting HSSort Run $i (output being written to ./logs/HSsort-time-run$i.txt)${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log

############################## 延时1分钟 #########################
# kill the process of iotrace
kill `ps aux|grep iotrace|xargs|awk '{print $2}'`
echo "sleep for ${SLEEP_BETWEEN_RUNS}  s"
# sleep for one minute
sleep $SLEEP_BETWEEN_RUNS
echo "sleep finished....."
############################## 延时1分钟 #########################

if [ "$FRAMEWORK" = "MapReduce" ]; then
    (time hadoop jar $HSSORT_JAR HSSort -Dmapreduce.job.maps=$NUM_MAPS -Dmapreduce.job.reduces=$NUM_REDUCERS -Dmapred.map.tasks=$NUM_MAPS -Dmapred.reduce.tasks=$NUM_REDUCERS  /${FILE_BASE}/input /${FILE_BASE}/output) 2> >(tee ./logs/HSsort-time-run$i.txt) 
else
    ############################## iostrace #########################
    nohup iotrace --start-tracing --devices ${DeviceBlock} --time 3600 --size 10240  1>&2 2>/dev/null &
    ##############################  iostrace #########################
    (time spark-submit --class HSSort --deploy-mode ${SPARK_DEPLOY_MODE} --master ${SPARK_MASTER_URL} --conf "spark.driver.memory=${SPARK_DRIVER_MEMORY}" --conf "spark.executor.memory=${SPARK_EXECUTOR_MEMORY}"  --conf "spark.executor.cores=${SPARK_EXECUTOR_CORES}" --conf "spark.executor.instances=${SPARK_EXECUTOR_INSTANCES}" ${HSSORT_JAR}  /${FILE_BASE}/input /${FILE_BASE}/output) 2>&1 | (tee ./logs/HSsort-time-run${i}.txt)
fi
result=$?

cat ./logs/HSsort-time-run${i}.txt >> ./TPCx-HS-result-"$prefix".log

if [ $result -ne 0 ]
then
echo -e "${red}======== HSsort Result FAILURE ========${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
benchmark_result=0
else
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}======== HSsort Result SUCCESS =============${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}======== Time taken by HSSort = `grep real ./logs/HSsort-time-run$i.txt | awk '{print $2}'`====${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
fi


echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}Listing HSsort output ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
./HSDataCheck.sh /${FILE_BASE}/output | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log

############################## 延时1分钟 #########################
# kill the process of iotrace
kill `ps aux|grep iotrace|xargs|awk '{print $2}'`
echo "sleep for ${SLEEP_BETWEEN_RUNS}  s"
# sleep for one minute
sleep $SLEEP_BETWEEN_RUNS
echo "sleep finished....."
############################## 延时1分钟 #########################

echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}Starting HSValidate ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log

if [ "$FRAMEWORK" = "MapReduce" ]; then
    (time hadoop jar $HSSORT_JAR HSValidate /${FILE_BASE}/output  /${FILE_BASE}/validate) 2> >(tee ./logs/HSvalidate-time-run$i.txt) 
else
    ############################## iostrace #########################
    nohup iotrace --start-tracing --devices ${DeviceBlock} --time 3600 --size 10240  1>&2 2>/dev/null &
    ##############################  iostrace #########################
    (time spark-submit --class HSValidate --deploy-mode ${SPARK_DEPLOY_MODE} --master ${SPARK_MASTER_URL} --conf "spark.driver.memory=${SPARK_DRIVER_MEMORY}" --conf "spark.executor.memory=${SPARK_EXECUTOR_MEMORY}" --conf "spark.executor.cores=${SPARK_EXECUTOR_CORES}" --conf "spark.executor.instances=${SPARK_EXECUTOR_INSTANCES}" ${HSSORT_JAR} /${FILE_BASE}/output  /${FILE_BASE}/validate) 2>&1 | (tee ./logs/HSvalidate-time-run${i}.txt)
fi
result=$?

cat ./logs/HSvalidate-time-run${i}.txt >> ./TPCx-HS-result-"$prefix".log

if [ $result -ne 0 ]
then
echo -e "${red}======== HSsort Result FAILURE ========${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
benchmark_result=0
else
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}======== HSValidate Result SUCCESS =============${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}======== Time taken by HSValidate = `grep real ./logs/HSvalidate-time-run$i.txt | awk '{print $2}'`====${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
fi

echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}Listing HSValidate output ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
./HSDataCheck.sh /${FILE_BASE}/validate | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log

echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log

end=`date +%s`

if (($benchmark_result == 1))
then
total_time=`expr $end - $start`
total_time_in_hour=$(echo "scale=4;$total_time/3600" | bc)
scale_factor=$(echo "scale=4;$hssize/10000000000" | bc)
perf_metric=$(echo "scale=4;$scale_factor/$total_time_in_hour" | bc)

echo -e "${green}$sep============${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}md5sum of core components:${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
md5sum ./TPCx-HS-master.sh ./$HSSORT_JAR ./HSDataCheck.sh ./BigData_cluster_validate_suite.sh | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log

echo -e "${green}$sep============${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}TPCx-HS Performance Metric (HSph@SF) Report ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}Test Run $i details: Total Time = $total_time ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}                     Total Size = $hssize ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}                     Scale-Factor = $scale_factor ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}                     Framework = $FRAMEWORK ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}TPCx-HS Performance Metric (HSph@SF): $perf_metric ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo "" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${green}$sep============${NC}" | tee -a ./TPCx-HS-result-"$prefix".log

else
echo -e "${red}$sep${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${red}No Performance Metric (HSph@SF) as some tests Failed ${NC}" | tee -a ./TPCx-HS-result-"$prefix".log
echo -e "${red}$sep${NC}" | tee -a ./TPCx-HS-result-"$prefix".log

fi

############################## 延时1分钟 #########################
# kill the process of iotrace
kill `ps aux|grep iotrace|xargs|awk '{print $2}'`
echo "the test is finished once..."
# sleep for one minute
sleep 10
echo "sleep over..."
############################## 延时1分钟 #########################


done

# 集成 parse.log 支持自动化 Iotrace log生成

if [[ $isXfs == 0 ]];then
    ./parseLog.sh mybtrfs
else
    ./parseLog.sh xfs
fi
```



### modify the spark source to call the shell script(display the temp file size) when deleting the temp file.

```scala
// in ./spark-3.0.3/core/src/main/scala/org/apache/spark/SparkEnv.scala

// 引入新编写的java代码
import com.intel.log.RunShell

      driverTmpDir match {
        case Some(path) =>
          try {
              
            //-----------------------------------//
            //--Intel Log added before deleted--//
            val fileLogHelper = new RunShell() // 调用java代码 实现日志打印
            fileLogHelper.fileLog()            //
            //---------------------------------//  
              
            Utils.deleteRecursively(new File(path))
          } catch {
            case e: Exception =>
              logWarning(s"Exception while deleting Spark temp dir: $path", e)
          }
        case None => // We just need to delete tmp dir created by driver, so do nothing on executor
      }
    }
  }
```

### the java file added.

```java
package com.intel.log;

public class RunShell {
    public  void fileLog(){  
        try {  
            // 实际脚本存放的位置
            String shpath="/root/huaiyu/fileDetect.sh";
            Process ps = Runtime.getRuntime().exec(shpath);
            ps.waitFor();
            System.out.println("Intel: file logged...");
            }
        catch (Exception e) {
            e.printStackTrace();
            }
    }
}

```

### the fileDetect.sh file

```shell
#! /bin/bash
green='\e[0;32m'
red='\e[0;31m'
NC='\e[0m' # No Color

# the base dir og spark to generate input output validate
SparkBaseDir=/hdfs-fast

time=$(date "+%Y-%m-%d %H:%M:%S");
echo -e "${green}fileLog.logged time : $time ${NC}" >> /root/huaiyu/fileLog.log
echo -e "${green}###################### MyTmpDir #######################${NC}">> /root/huaiyu/fileLog.log
ls -l  /root/huaiyu/intel/MyTmpDir >> /root/huaiyu/fileLog.log
tree -a -h -L 5 --sort=size /root/huaiyu/intel/MyTmpDir >> /root/huaiyu/fileLog.log

echo -e "${green}###################### /tmp  #######################${NC}" >> /root/huaiyu/fileLog.log
ls -l /tmp  >> /root/huaiyu/fileLog.log
tree -a -h -L 5 --sort=size /tmp >> /root/huaiyu/fileLog.log

echo -e "${green}###################### /input  #######################${NC}" >> /root/huaiyu/fileLog.log
ls -l  $SparkBaseDir/input/*  >> /root/huaiyu/fileLog.log
tree -a -h -L 5 --sort=size $SparkBaseDir/input >> /root/huaiyu/fileLog.log

echo -e "${green}###################### /output  #######################${NC}" >> /root/huaiyu/fileLog.log
ls -l  $SparkBaseDir/output/*  >> /root/huaiyu/fileLog.log
tree -a -h -L 5 --sort=size $SparkBaseDir/output >> /root/huaiyu/fileLog.log

echo -e "${green}###################### /*/validate  #######################${NC}" >> /root/huaiyu/fileLog.log
ls -l $SparkBaseDir/validate/* >>/root/huaiyu/fileLog.log
tree -a -h -L 5 --sort=size $SparkBaseDir/validate  >> /root/huaiyu/fileLog.log

```

### prepare the maven jar  and build the jar

```shell
# All the jar repository is packed into a jar named sparkFullCompileMavenRepository.tar.gz

# put it int the dir /root/.m2
# unpack it 
tar -zxvf sparkFullCompileMavenRepository.tar.gz ./

# in this way it will not download the resource from intenet but use the local one.

# donwload the spark source file
wget https://dlcdn.apache.org/spark/spark-3.0.3/spark-3.0.3-bin-hadoop2.7.tgz
# unpack it
tar -zxvf spark-3.0.3-bin-hadoop2.7.tgz
# cd ./spark-3.0.3-bin-hadoop2.7
# add your scala file and java file into correct dir,then build
# build it wiht mvn way.
# You’ll need to configure Maven to use more memory than usual by setting MAVEN_OPTS:
export MAVEN_OPTS="-Xmx2g -XX:ReservedCodeCacheSize=1g"
./build/mvn -DskipTests clean package
# you had better have 4G+ memory to handle this.
# after 20-25 minutes you will see the build success results:

[INFO] ------------------------------------------------------------------------
[INFO] Reactor Summary for Spark Project Parent POM 3.0.3:
[INFO] 
[INFO] Spark Project Parent POM ........................... SUCCESS [  2.037 s]
[INFO] Spark Project Tags ................................. SUCCESS [  5.631 s]
[INFO] Spark Project Sketch ............................... SUCCESS [  7.539 s]
[INFO] Spark Project Local DB ............................. SUCCESS [  2.278 s]
[INFO] Spark Project Networking ........................... SUCCESS [  4.020 s]
[INFO] Spark Project Shuffle Streaming Service ............ SUCCESS [  1.164 s]
[INFO] Spark Project Unsafe ............................... SUCCESS [ 10.045 s]
[INFO] Spark Project Launcher ............................. SUCCESS [  1.478 s]
[INFO] Spark Project Core ................................. SUCCESS [01:54 min]
[INFO] Spark Project ML Local Library ..................... SUCCESS [ 49.667 s]
[INFO] Spark Project GraphX ............................... SUCCESS [01:07 min]
[INFO] Spark Project Streaming ............................ SUCCESS [01:48 min]
[INFO] Spark Project Catalyst ............................. SUCCESS [03:25 min]
[INFO] Spark Project SQL .................................. SUCCESS [04:35 min]
[INFO] Spark Project ML Library ........................... SUCCESS [03:33 min]
[INFO] Spark Project Tools ................................ SUCCESS [ 16.132 s]
[INFO] Spark Project Hive ................................. SUCCESS [02:40 min]
[INFO] Spark Project REPL ................................. SUCCESS [ 53.102 s]
[INFO] Spark Project Assembly ............................. SUCCESS [  2.357 s]
[INFO] Kafka 0.10+ Token Provider for Streaming ........... SUCCESS [ 56.918 s]
[INFO] Spark Integration for Kafka 0.10 ................... SUCCESS [01:16 min]
[INFO] Kafka 0.10+ Source for Structured Streaming ........ SUCCESS [01:59 min]
[INFO] Spark Project Examples ............................. SUCCESS [01:25 min]
[INFO] Spark Integration for Kafka 0.10 Assembly .......... SUCCESS [  3.934 s]
[INFO] Spark Avro ......................................... SUCCESS [01:35 min]
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  28:59 min
[INFO] Finished at: 2022-05-14T09:08:05+02:00
[INFO] ------------------------------------------------------------------------
```

![](C:\Users\huaiyuli\OneDrive - Intel Corporation\Desktop\sparkBuild.PNG)

