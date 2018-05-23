#!/bin/bash
# author: XIE Chengbo
# email: chengbo.xie.ext@nokia-sbell.com

# -----------------------formate_table Util function-----------------------
sep="#"
function append_cell(){
    #对表格追加单元格
    #append_cell col0 "col 1" ""
    #append_cell col3
    local i
    for i in "$@"
    do
        line+="|$i${sep}"
    done
}
function check_line(){
if [ -n "$line" ] 
then
    c_c=$(echo $line|tr -cd "${sep}"|wc -c)
    difference=$((${column_count}-${c_c}))
    if [ $difference -gt 0 ]
    then
        line+=$(seq -s " " $difference|sed -r s/[0-9]\+/\|${sep}/g|sed -r  s/${sep}\ /${sep}/g)
    fi
    content+="${line}|\n"
fi

}
function append_line(){
    check_line
    line=""
    local i
    for i in "$@"
    do
        line+="|$i${sep}"
    done
    check_line
    line=""
}
function segmentation(){
    local seg=""
    local i
    for i in $(seq $column_count)
    do 
        seg+="+${sep}"
    done
    seg+="${sep}+\n"
    echo $seg
}
function set_title(){
    #表格标头，以空格分割，包含空格的字符串用引号，如
    #set_title Column_0 "Column 1" "" Column3
    [ -n "$title" ] && echo "Warring:title has been defined, rewrite title and content"
    column_count=0
    title=""
    local i
    for i in "$@"
    do
        title+="|${i}${sep}"
        let column_count++
    done
    title+="|\n"
    seg=`segmentation`
    title="${seg}${title}${seg}"
    content=""
}
function output_table(){
    if [ ! -n "${title}" ] 
    then
        echo "no set title,exit" && return 1
    fi
    append_line
    table="${title}${content}$(segmentation)"
    echo -e $table|column -s "${sep}" -t|awk '{if($0 ~ /^+/){gsub(" ","-",$0);print $0}else{gsub("\\(\\*\\)","\033[31m(*)\033[0m",$0);print $0}}'

}
# -----------------------formate_table Util function-----------------------


readme(){
	echo "Usage: cplus [OPTION] SOURCE TARGET"
	echo ""
	echo "-b                                 Copy the files in SOURCE to TARGET, and the corresponding files in TARGET are prepared as '*.org'."
	echo "                                   E.g cplus -b ./tmp1 ./tmp2"
	echo "-c                                 Based on file in A, restore the corresponding '*.org' file in B."
	echo "                                   E.g cplus -c ./tmp1 ./tmp2"
	echo "-h,--help                          Display this help text"
}

# param： 要搜索的目录, 要搜索的文件名， return 搜索到的所有文件
function findTarget(){
	TARGET=${1}
	TARGETFILE=${2}
	array=()
	pathname=$(find ${TARGET} -type f -name ${TARGETFILE} -printf "%p\n")
	for path in ${pathname[@]}
	do
		length=${#array[@]}
		#echo -e "lalala :${length} ${path}"
		array[length]=${path}
	done
	echo "${array[@]}"
}
 #targetFiles=($(findTarget . "README.md"))
 #echo -e "返回的数组为： ${targetFiles[@]}  ${#targetFiles[@]}"

#param: 需要遍历的目录，return 遍历的数组（当前文件下的文件）
function findSource(){
	SOURCE=${1}
	array=()
	for filename in "${SOURCE}"/*
	do
		length=${#array[@]}
		if [ -f "${filename}" ];then
			array[length]=${filename}
		fi
	done
	echo "${array[@]}"
}
# sourceFiles=($(findSource .))
# echo -e "返回的数组为： ${sourceFiles[@]} ${#sourceFiles[@]}"


# 参数校验， 不校验选项 param： SOURCE, TARGET
function validate(){
	flag=0
	msg=""
	source=${1}
	target=${2}
	if [ -d "${source}" ];then
		if [ `find ${source} -type f | wc -l` -gt 0 ];then
			let flag++
		else
			msg="There is no file in directory ${source}"
		fi
	else
		msg="${source}: No directory"
	fi
	if [ -d "${target}" ];then
		if [ `find ${target} -type f | wc -l` -gt 0 ];then
			let flag++
		else
			msg="There is no file in directory ${target}"
		fi
	else
		msg="${target}: No directory"
	fi
	echo "${flag}_${msg}"
}
#flag=$(validate . ./tmp)
#echo "flag: ${flag} or $?"
#echo "$(validate . ./tmp)"

#TIMESTAMPS=`date -d today +'%Y%m%dT%H%M%S'`

#执行替换操作
function replace(){
	echo -e "Files is replacing..."
	set_title "Source" " " "target"
	sourceDir=${1}
	targetDir=${2}
	sourceFiles=($(findSource $sourceDir)) #source下的文件名
	for sourceFile in "${sourceFiles[@]}"
	do
		#echo "${sourceFile}"
		tarFileName=$(echo "${sourceFile}"| awk -F '/' {'print $NF'}) #有后缀
		#echo "文件名：${tarFileName}"
		targetFiles=($(findTarget ${targetDir} ${tarFileName}))
		#echo -e "返回的数组为： ${targetFiles[@]}  ${#targetFiles[@]}"
		for targetFilePN in "${targetFiles[@]}"
		do
			#echo "文件路径和名字： ${targetFilePN}"
			tarFilePath=$(echo "${targetFilePN}"| awk -F '/' '{gsub("/"$NF,"");print}')
			#echo "文件路径：${tarFilePath}"

			if [ `find ${tarFilePath} -maxdepth 1 -name ${tarFileName}.org | wc -l` -eq 0 ];then
				mv "${targetFilePN}" "${tarFilePath}/${tarFileName}.org" #备份
			fi
			cp ${sourceFile} ${targetFilePN}
			append_line ${sourceFile} "-->" ${targetFilePN}
		done
	done
	output_table
}
#replace ./tmp ./tmp/tmp

# 恢复操作： 也是根据SOURCE中文件名字进行对替换的文件恢复
function regress(){
	echo -e "Files is regressing..."
	set_title "Source" " " "target"
	sourceDir=${1}
	targetDir=${2}
	sourceFiles=($(findSource $sourceDir)) #source下的文件名
	for sourceFile in "${sourceFiles[@]}"
	do
		tarFileName=$(echo "${sourceFile}"| awk -F '/' {'print $NF'}) # 有后缀，需要被恢复的文件。
		targetFiles=($(findTarget ${targetDir} ${tarFileName}.org))   # 原始文件，带有org后缀
		for targetFilePN in "${targetFiles[@]}"
		do
			tarFilePath=$(echo "${targetFilePN}"| awk -F '/' '{gsub("/"$NF,"");print}')
			if [ `find ${tarFilePath} -maxdepth 1 -name ${tarFileName} | wc -l` -ne 0 ];then
				#echo "删除测试文件 ${tarFilePath}/${tarFileName}"
				rm "${tarFilePath}/${tarFileName}" #删除
			fi
			mv ${targetFilePN} ${targetFilePN%.*}
			append_line ${targetFilePN} "-->" ${targetFilePN%.*}
		done
	done
	output_table
}

# 1个选项，2个参数
# cplus [OPTION] SOURCE TARGET
OPTION=${1}
SOURCE=${2}
TARGET=${3}
if [ $# -lt 1 ];then
	echo "cplus: Help you debug."
	echo "Try 'cplus -h' or 'cplus --help' for more information."
	exit 0
elif [ $# -eq 3 ]; then
	# 校验参数
	flag_msg=`validate ${SOURCE} ${TARGET}`
	flag=$(echo "${flag_msg}" | awk -F '_' {'print $1'})
	msg=$(echo "${flag_msg}" | awk -F '_' {'print $2'})
	#echo "${flag}  ${msg}"
	if [ "${flag}" -eq 2 ];then
		echo "Great,let's go ... ..."
	else
		echo -e "\033[31mParameter verification failed\033[0m \n${msg}\nTry 'cplus -h' or 'cplus --help' for more information."
		exit 0
	fi
fi

# 参数已经校验完成
case "${OPTION}" in
	-h|--help) readme;
		exit 0;;
	-b)
		replace $SOURCE $TARGET
	;;
	-c)
		regress $SOURCE $TARGET
	;;
	*)
		echo "cplus: invalid option '${1}'"
		echo "Try 'cplus -h' or 'cplus --help' for more information."
		exit 0
	;;
esac