RESULT=.result
touch $RESULT

# 列出所有的 .bin 文件路径，并保存到变量 files 中
files=$NEMU_HOME/rv_test/*.bin

for f in $files
do
  filename=$(basename "$f")  # 提取文件名部分
  basename="${filename%%.*}"  # 提取匹配到的部分

  echo -e -n "[\033[1;32m$basename\033[0m]" >> $RESULT

  if make ARGS=-b IMG="$f" run
  then
    echo -e "\033[1;32m PASS!\033[0m" >> $RESULT
  else
    echo -e "\033[1;31m FAIL!\033[0m" >> $RESULT
  fi
done

cat $RESULT
rm -rf $RESULT
