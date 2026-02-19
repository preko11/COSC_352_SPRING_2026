Prime Counter (Java, Kotlin, Go)
================================

This project implements a prime number counter in three languages (Java, Kotlin, Go) with both single-threaded and multi-threaded approaches to compare performance.

Prerequisites
- Java JDK (javac/java) - installed
- Go toolchain (go) - installed
- Kotlin compiler (kotlinc) - optional (see note below)

Quick Start
===========

1. Generate test data:
   bash generate_numbers.sh 10000 numbers.txt

2. Run all implementations:
   bash run.sh numbers.txt

Expected Output
===============
File: numbers.txt (1,000 numbers)

[Single-Threaded]
  Primes found: 80
  Time: 1.234 ms

[Multi-Threaded] (2 threads)
  Primes found: 80
  Time: 3.456 ms

Speedup: 0.36x

What Each Program Does
======================
- Reads all integers from the provided file (one per line), skipping blanks and invalid lines.
- Counts primes using a single-threaded pass and a multi-threaded pass.
- Uses trial division with 6k±1 optimization for efficiency.
- Prints counts, timings (milliseconds), and speedup ratio.

Files
=====
- java/PrimeCounter.java - Java implementation using ExecutorService
- kotlin/PrimeCounter.kt - Kotlin implementation using Coroutines
- golang/prime_counter.go - Go implementation using goroutines
- run.sh - Build-and-run script
- generate_numbers.sh - Test data generator

Kotlin Note
===========
The default Kotlin compiler (v1.3.31 from apt) is incompatible with Java 25.
To enable Kotlin, install a newer version:

  curl https://get.sdkman.io | bash
  source $HOME/.sdkman/bin/sdkman-init.sh
  sdk install kotlin

Then re-run: bash run.sh numbers.txt

Design Highlights
=================

### Prime Algorithm
All three implementations use the same efficient trial division approach:
- Check divisibility by 2 and 3 first
- Then test only factors of the form 6k±1
- Check only up to sqrt(n)

### Threading Models
- Java: ExecutorService with fixed thread pool
- Go: Goroutines with WaitGroup and channels
- Kotlin: Coroutines with ExecutorService

### File Reading
Numbers are read once before timing begins, ensuring fair timing measurements.
Invalid lines are skipped gracefully; only valid integers are counted.
Class Repo for Project Submission
