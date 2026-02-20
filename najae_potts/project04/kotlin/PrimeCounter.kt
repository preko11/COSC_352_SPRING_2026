import java.io.File
import java.util.concurrent.Callable
import java.util.concurrent.Executors

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        System.err.println("Usage: kotlin PrimeCounter.kt <numbers.txt>")
        return
    }
    val file = File(args[0])
    if (!file.canRead()) {
        System.err.println("Cannot read file: ${args[0]}")
        return
    }

    val numbers = mutableListOf<Long>()
    file.forEachLine { line ->
        val s = line.trim()
        if (s.isEmpty()) return@forEachLine
        try {
            numbers.add(s.toLong())
        } catch (e: NumberFormatException) {
            // skip
        }
    }

    println("File: ${args[0]} (${numbers.size} numbers)")

    val startSingle = System.nanoTime()
    val singleCount = numbers.count { isPrime(it) }
    val endSingle = System.nanoTime()
    val singleMs = (endSingle - startSingle) / 1_000_000.0

    println()
    println("[Single-Threaded]")
    println("  Primes found: $singleCount")
    println("  Time: ${"%.3f".format(singleMs)} ms")

    val threads = Runtime.getRuntime().availableProcessors()
    val pool = Executors.newFixedThreadPool(threads)
    val size = numbers.size
    val chunk = (size + threads - 1) / threads
    val tasks = mutableListOf<Callable<Long>>()

    for (i in 0 until threads) {
        val from = i * chunk
        val to = kotlin.math.min(size, from + chunk)
        tasks.add(Callable {
            var local = 0L
            for (j in from until to) if (isPrime(numbers[j])) local++
            local
        })
    }

    val startMulti = System.nanoTime()
    val results = pool.invokeAll(tasks)
    var multiCount = 0L
    for (r in results) {
        try {
            multiCount += r.get()
        } catch (e: Exception) {
            // ignore
        }
    }
    pool.shutdown()
    val endMulti = System.nanoTime()
    val multiMs = (endMulti - startMulti) / 1_000_000.0

    println()
    println("[Multi-Threaded] ($threads threads)")
    println("  Primes found: $multiCount")
    println("  Time: ${"%.3f".format(multiMs)} ms")

    val speedup = singleMs / multiMs
    println()
    println("Speedup: ${"%.2f".format(speedup)}x")
}

fun isPrime(n: Long): Boolean {
    if (n <= 1) return false
    if (n <= 3) return true
    if (n % 2L == 0L || n % 3L == 0L) return false
    val r = kotlin.math.sqrt(n.toDouble()).toLong()
    var i = 5L
    while (i <= r) {
        if (n % i == 0L) return false
        if (n % (i + 2) == 0L) return false
        i += 6L
    }
    return true
}
