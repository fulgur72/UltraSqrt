#!/bin/bash

num="02 03 05 17 19 23 4294967295 4294967294 1073741825 1073741823"

# One by one processing 6e6
ultrasqrt_1b1 () {
  local i; local l; local p;
  local st; local en;
  local file;
  echo "num = $num"
  l=6000000
  echo "l   = $l"
  echo
  p=6e6
  st=$(date "+%s")
  for i in $num; do
    echo "*** $i ***"
    file=sqrt${p}_${i}.txt
    echo "  ==> $file"
    ./UltraSqrt.exe $i $l >"$file"
    head -n 7 "$file"
  done
  en=$(date "+%s")
  echo "Total time: $(( en-st )) sec"
  echo
}

# Parallel processing 1e7
ultrasqrt_par () {
  local i; local l; local p;
  local u_max; local u; local sl; local dt;
  local st; local en;
  local file;
  echo "num = $num"
  l=10000000
  echo "l   = $l"
  u_max=2
  echo "prc = $u_max"
  sl=5
  echo
  p=1e7
  st=$(date "+%s")
  for i in $num; do
    echo "*** $i ***"
    file=sqrt${p}_${i}.txt
    ./UltraSqrt.exe $i $l >"$file"&
    u=$u_max
    while [[ $u -ge $u_max ]]; do
      sleep $sl
      dt=$(date "+%T")
      u=$(ps -f | grep UltraSqrt | wc -l)
      echo "$dt - running processes: $u"
    done
  done
  u=$u_max
  while [[ $u -gt 0 ]]; do
    sleep $sl
    dt=$(date "+%T")
    u=$(ps -f | grep UltraSqrt | wc -l)
    echo "$dt - running processes: $u"
  done
  en=$(date "+%s")
  for i in $num; do
    echo "*** $i ***"
    file=sqrt${p}_${i}.txt
    head -n 7 "$file"
  done
  echo "Total time: $(( en-st )) sec"
  echo
}

# Compare
ultrasqrt_cmp () {
  local i; local l; local p1; local p2;
  local file1; local file2;
  local h;
  echo "num = $num"
  l=6000000
  echo "l   = $l"
  h=$((l/100+8))
  echo
  p1=1e7
  p2=6e6
  for i in $num; do
    echo "*** $i ***"
    file1=sqrt${p1}_${i}.txt
    echo "< $file1 <<"
    file2=sqrt${p2}_${i}.txt
    echo "> $file2 >>"
    diff <(head -n $h "$file1"| tail -n +6) <(head -n $h "$file2"| tail -n +6)
    echo
  done
}
