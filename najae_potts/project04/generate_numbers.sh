#!/usr/bin/env bash
set -euo pipefail

COUNT=${1:-10000}
OUT=${2:-numbers.txt}

echo "Generating $COUNT random integers to $OUT"
awk -v n="$COUNT" 'BEGIN{srand(); for(i=0;i<n;i++){ if(i%50==0) print 1; else print int(rand()*1000000) }}' > "$OUT"
echo "Done."
