#!/bin/bash
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && echo "Script is being sourced ..." || echo "Script is NOT sourced - ERROR" || exit 1

ultra_bin=./UltraSqrt.exe

num="002 003 005 017 019 023 4294967295 4294967294 1073741825 1073741823"

# One by one processing 6e6
ultrasqrt_1b1 () {
  local i; local l; local d; local p;
  local st; local en;
  local file; local fline;
  l=6000000
  d=06e6; p=06e6
  while [[ $# -ge 1 ]]; do eval "$1"; shift; done
  echo "ultra_bin = $ultra_bin"
  echo "num = $num"
  echo "l   = $l"
  echo
  mkdir -p "${d}"
  st=$(date "+%s")
  for i in $num; do
    dt=$(date "+%T")
    echo "At $dt *** $i ***"
    file="${d}/sqrt_${i}_${p}.txt"
    echo "  ==> $file"
    $ultra_bin $i $l >"$file"
    echo
    fline=$(cat "$file" | wc -l)
    head -n 28 -- "$file"
    echo " ... $((fline-30)) line(s) ..."
    tail -n 02 -- "$file"
    echo
  done
  en=$(date "+%s")
  echo "Total time: $(( en-st )) sec"
  echo
}

# Parallel processing 1e7
ultrasqrt_par () {
  local i; local l; local d; local p;
  local u_max; local u; local sl; local dt;
  local st; local en;
  local file; local fline;
  l=10000000
  u_max=2; sl=5
  d=10e6; p=10e6
  while [[ $# -ge 1 ]]; do eval "$1"; shift; done
  echo "ultra_bin = $ultra_bin"
  echo "num = $num"
  echo "l   = $l"
  echo "prc = $u_max"
  echo
  mkdir -p "${d}"
  st=$(date "+%s")
  for i in $num; do
    dt=$(date "+%T")
    echo "At $dt *** $i ***"
    file="${d}/sqrt_${i}_${p}.txt"
    echo "  ==> $file"
    $ultra_bin $i $l >"$file"&
    u=$u_max
    while [[ $u -ge $u_max ]]; do
      sleep $sl
      dt=$(date "+%T")
      u=$(ps -f | grep UltraSqrt | wc -l)
      echo "$dt - running processes: $u" >&2
    done
  done
  u=$u_max
  while [[ $u -gt 0 ]]; do
    sleep $sl
    dt=$(date "+%T")
    u=$(ps -f | grep UltraSqrt | wc -l)
    echo "$dt - running processes: $u" >&2
  done
  en=$(date "+%s")
  echo
  for i in $num; do
    dt=$(date "+%T")
    echo "At $dt *** $i ***"
    file="${d}/sqrt_${i}_${p}.txt"
    fline=$(cat "$file" | wc -l)
    echo "  <== $file"
    echo
    head -n 28 -- "$file"
    echo " ... $((fline-30)) line(s) ..."
    tail -n 02 -- "$file"
    echo
  done
  echo "Total time: $(( en-st )) sec"
  echo
}

# Compare
ultrasqrt_cmp () {
  local i; local l; local d; local p; local d2; local p2;
  local file; local file2;
  local nrnd=27; local nfrc;
  local gsrc='/^sqrt/ || /^[1-9][0-9]*\./ { print; next }
              /^[0-9]/ { if (num>=length($0)) { print; num-=length($0) } else if (num>0) { print substr($0,1,num); num=0 } }'
  l=6000000
  d=06e6;  p=06e6
  d2=20e6; p2=20e6
  while [[ $# -ge 1 ]]; do eval "$1"; shift; done
  nfrc=$((l+nrnd-1-(l-1)%nrnd))
  for i in $num; do
    echo "*** $i ***"
    file="${d}/sqrt_${i}_${p}.txt"
    echo "< $file <<"
    file2="${d2}/sqrt_${i}_${p2}.txt"
    echo "> $file2 >>"
    diff <(gawk -v num=$nfrc -- "$gsrc" "$file") <(gawk -v num=$nfrc -- "$gsrc" "$file2")
    echo
  done
}

# Meta mega
ultramega () {
  local m=$1; shift
  local n="$(printf '%02d' $m)e6"
  local u_action=$1; shift
  local s="${u_action#*_}"
  local ss="${u_action##*_}"
  $u_action l=${m}000000 d="${n}_${ss}" p="${n}" "$@" | tee "${s}_${n}.txt"
}
# Meta mega compare
ultrasqrt_cmp_1b1 () {
    ultrasqrt_cmp d2=20e6_1b1 p2=20e6 "$@"
}
ultrasqrt_cmp_par () {
    ultrasqrt_cmp d2=20e6_par p2=20e6 "$@"
}
