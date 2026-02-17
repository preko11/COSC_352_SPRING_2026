import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class PrimeCounter {

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: java PrimeCounter <numbers.txt>");
            System.exit(1);
        }

        File f = new File(args[0]);
        if (!f.canRead()) {
            System.err.println("Cannot read file: " + args[0]);
            System.exit(1);
        }

        List<Long> numbers = new ArrayList<>();
        try (BufferedReader br = new BufferedReader(new FileReader(f))) {
            String line;
            while ((line = br.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty()) continue;
                try {
                    long v = Long.parseLong(line);
                    numbers.add(v);
                } catch (NumberFormatException e) {
                    // skip invalid lines
                }
            }
        } catch (IOException e) {
            System.err.println("Error reading file: " + e.getMessage());
            System.exit(1);
        }

        System.out.println("File: " + args[0] + " (" + numbers.size() + " numbers)");

        // Single-threaded
        long start = System.nanoTime();
        long singleCount = 0;
        for (long n : numbers) {
            if (isPrime(n)) singleCount++;
        }
        long end = System.nanoTime();
        double singleMs = (end - start) / 1_000_000.0;

        System.out.println();
        System.out.println("[Single-Threaded]");
        System.out.println("  Primes found: " + singleCount);
        System.out.printf("  Time: %.3f ms\n", singleMs);

        // Multi-threaded
        int threads = Runtime.getRuntime().availableProcessors();
        ExecutorService ex = Executors.newFixedThreadPool(threads);
        List<Callable<Long>> tasks = new ArrayList<>();
        final int size = numbers.size();
        int chunk = (size + threads - 1) / threads;
        for (int i = 0; i < threads; i++) {
            final int from = i * chunk;
            final int to = Math.min(size, from + chunk);
            tasks.add(() -> {
                long local = 0;
                for (int j = from; j < to; j++) {
                    if (isPrime(numbers.get(j))) local++;
                }
                return local;
            });
        }

        start = System.nanoTime();
        long multiCount = 0;
        try {
            List<Future<Long>> results = ex.invokeAll(tasks);
            for (Future<Long> fRes : results) {
                try {
                    multiCount += fRes.get();
                } catch (ExecutionException e) {
                    // ignore individual task failures
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } finally {
            ex.shutdown();
        }
        end = System.nanoTime();
        double multiMs = (end - start) / 1_000_000.0;

        System.out.println();
        System.out.println("[Multi-Threaded] (" + threads + " threads)");
        System.out.println("  Primes found: " + multiCount);
        System.out.printf("  Time: %.3f ms\n", multiMs);

        double speedup = singleMs / multiMs;
        System.out.println();
        System.out.printf("Speedup: %.2fx\n", speedup);
    }

    private static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;
        long r = (long) Math.sqrt((double) n);
        for (long i = 5; i <= r; i += 6) {
            if (n % i == 0) return false;
            if (n % (i + 2) == 0) return false;
        }
        return true;
    }
}
