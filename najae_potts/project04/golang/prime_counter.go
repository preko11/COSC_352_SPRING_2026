package main

import (
    "bufio"
    "fmt"
    "math"
    "os"
    "runtime"
    "strconv"
    "strings"
    "sync"
    "time"
)

func main() {
    if len(os.Args) < 2 {
        fmt.Fprintln(os.Stderr, "Usage: prime_counter <numbers.txt>")
        os.Exit(1)
    }
    path := os.Args[1]
    f, err := os.Open(path)
    if err != nil {
        fmt.Fprintln(os.Stderr, "Cannot open file:", err)
        os.Exit(1)
    }
    defer f.Close()

    var numbers []int64
    scanner := bufio.NewScanner(f)
    for scanner.Scan() {
        s := scanner.Text()
        s = trimSpace(s)
        if s == "" {
            continue
        }
        if v, err := strconv.ParseInt(s, 10, 64); err == nil {
            numbers = append(numbers, v)
        }
    }

    fmt.Printf("File: %s (%d numbers)\n", path, len(numbers))

    // Single-threaded
    start := time.Now()
    var singleCount int64
    for _, n := range numbers {
        if isPrime(n) {
            singleCount++
        }
    }
    singleElapsed := time.Since(start)

    fmt.Println()
    fmt.Println("[Single-Threaded]")
    fmt.Printf("  Primes found: %d\n", singleCount)
    fmt.Printf("  Time: %.3f ms\n", float64(singleElapsed.Nanoseconds())/1e6)

    // Multi-threaded
    threads := runtime.NumCPU()
    chunk := (len(numbers) + threads - 1) / threads
    var wg sync.WaitGroup
    results := make(chan int64, threads)
    start = time.Now()
    for i := 0; i < threads; i++ {
        from := i * chunk
        if from >= len(numbers) {
            break
        }
        to := min(len(numbers), from+chunk)
        wg.Add(1)
        go func(slice []int64) {
            defer wg.Done()
            var local int64
            for _, v := range slice {
                if isPrime(v) {
                    local++
                }
            }
            results <- local
        }(numbers[from:to])
    }
    wg.Wait()
    close(results)
    var multiCount int64
    for c := range results {
        multiCount += c
    }
    multiElapsed := time.Since(start)

    fmt.Println()
    fmt.Printf("[Multi-Threaded] (%d threads)\n", threads)
    fmt.Printf("  Primes found: %d\n", multiCount)
    fmt.Printf("  Time: %.3f ms\n", float64(multiElapsed.Nanoseconds())/1e6)

    speedup := float64(singleElapsed.Nanoseconds()) / float64(multiElapsed.Nanoseconds())
    fmt.Println()
    fmt.Printf("Speedup: %.2fx\n", speedup)
}

func trimSpace(s string) string {
    return strings.TrimSpace(s)
}

func min(a, b int) int {
    if a < b {
        return a
    }
    return b
}

func isPrime(n int64) bool {
    if n <= 1 {
        return false
    }
    if n <= 3 {
        return true
    }
    if n%2 == 0 || n%3 == 0 {
        return false
    }
    r := int64(math.Sqrt(float64(n)))
    for i := int64(5); i <= r; i += 6 {
        if n%i == 0 || n%(i+2) == 0 {
            return false
        }
    }
    return true
}
