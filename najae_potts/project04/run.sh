#!/usr/bin/env bash
set -euo pipefail

FILE=${1:-numbers.txt}
if [ ! -f "$FILE" ]; then
  echo "Input file not found: $FILE"
  echo "Use ./generate_numbers.sh to create a sample numbers.txt or provide a file path."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==== Java ===="
mkdir -p java/classes
javac java/PrimeCounter.java -d java/classes
java -cp java/classes PrimeCounter "$FILE"

echo
echo "==== Kotlin ===="
# Source SDKMAN to use the newer Kotlin compiler
if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  source "$HOME/.sdkman/bin/sdkman-init.sh"
fi
mkdir -p kotlin/classes
kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/PrimeCounter.jar 2>/dev/null || {
  echo "  Note: Could not compile Kotlin. If just installed via SDKMAN, restart your shell:"
  echo "  source \$HOME/.sdkman/bin/sdkman-init.sh"
}
java -jar kotlin/PrimeCounter.jar "$FILE" 2>/dev/null || true

echo
echo "==== Go ===="
go build -o golang/prime_counter golang/prime_counter.go
./golang/prime_counter "$FILE"
