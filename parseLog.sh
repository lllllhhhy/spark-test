#!/bin/bash


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
cpDir=`find  /root  -name  "QuickTPcx.sh" | awk -F '/[^/]*$' '{print $1}'`
parse_fs_statistics "${dirArr[*]}" "$logBaseDir" "$logDir" "$cpDir"
parse_latency_histogram "${dirArr[*]}" "$logBaseDir" "$logDir" "$cpDir"
parse_lba_histogram "${dirArr[*]}" "$logBaseDir" "$logDir" "$cpDir"
parse_io_json "${dirArr[*]}" "$logBaseDir" "$logDir" "$cpDir"

