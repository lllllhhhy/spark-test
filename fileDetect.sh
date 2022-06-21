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



