#!/bin/bash

ultra_bin=./UltraSqrt.exe

num="002 003 005 017 019 023 4294967295 4294967294 1073741825 1073741823"

# One by one processing 6e6
ultrasqrt_1b1 () {
  local i; local l; local p;
  local st; local en;
  local file;
  l=6000000
  p=6e6
  while [[ $# -ge 1 ]]; do eval "$1"; shift; done
  echo "ultra_bin = $ultra_bin"
  echo "num = $num"
  echo "l   = $l"
  echo
  st=$(date "+%s")
  for i in $num; do
    echo "*** $i ***"
    file=sqrt_${i}_${p}.txt
    echo "  ==> $file"
    $ultra_bin $i $l >"$file"
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
  l=10000000
  u_max=2
  sl=5
  p=Ae6
  while [[ $# -ge 1 ]]; do eval "$1"; shift; done
  echo "ultra_bin = $ultra_bin"
  echo "num = $num"
  echo "l   = $l"
  echo "prc = $u_max"
  echo
  st=$(date "+%s")
  for i in $num; do
    echo "*** $i ***"
    file=sqrt_${i}_${p}.txt
    echo "  ==> $file"
    $ultra_bin $i $l >"$file"&
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
    file=sqrt_${i}_${p}.txt
    echo "  <== $file"
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
  l=6000000
  p1=6e6
  p2=Ae6
  while [[ $# -ge 1 ]]; do eval "$1"; shift; done
  echo "num = $num"
  echo "l   = $l"
  h=$((l/100+8))
  echo
  for i in $num; do
    echo "*** $i ***"
    file1=sqrt_${i}_${p1}.txt
    echo "< $file1 <<"
    file2=sqrt_${i}_${p2}.txt
    echo "> $file2 >>"
    diff <(head -n $h "$file1"| tail -n +6) <(head -n $h "$file2"| tail -n +6)
    echo
  done
}
