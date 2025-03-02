package com.demo.chaos.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

@RestController
@RequestMapping("/api")
public class ChaosController {

    private static final Logger logger = LoggerFactory.getLogger(ChaosController.class);
    private final Map<String, Object> memoryLeakMap = new ConcurrentHashMap<>();
    private final AtomicInteger counter = new AtomicInteger(0);
    private ExecutorService threadPool;

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> status = new HashMap<>();
        status.put("status", "UP");
        status.put("service", "chaos-java-service");
        return ResponseEntity.ok(status);
    }

    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> info() {
        Map<String, Object> info = new HashMap<>();
        info.put("service", "chaos-java-service");
        info.put("version", "1.0.0");
        info.put("jvm", System.getProperty("java.version"));
        info.put("memory", Runtime.getRuntime().maxMemory() / (1024 * 1024) + "MB");
        info.put("processors", Runtime.getRuntime().availableProcessors());
        return ResponseEntity.ok(info);
    }

    @GetMapping("/memory-leak")
    public ResponseEntity<Map<String, Object>> memoryLeak(
            @RequestParam(defaultValue = "1") int sizeInMB) {
        
        logger.info("Triggering memory leak of {} MB", sizeInMB);
        
        // Create a byte array of the specified size
        byte[] bytes = new byte[sizeInMB * 1024 * 1024];
        
        // Store in the map to prevent garbage collection
        String key = "leak-" + counter.incrementAndGet();
        memoryLeakMap.put(key, bytes);
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "Memory leak triggered");
        response.put("leakSizeInMB", sizeInMB);
        response.put("totalLeaks", memoryLeakMap.size());
        response.put("estimatedLeakSizeMB", 
                memoryLeakMap.size() * sizeInMB);
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/clear-leaks")
    public ResponseEntity<Map<String, Object>> clearLeaks() {
        int leakCount = memoryLeakMap.size();
        memoryLeakMap.clear();
        System.gc(); // Suggest garbage collection
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "Memory leaks cleared");
        response.put("clearedLeaks", leakCount);
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/cpu-load")
    public ResponseEntity<Map<String, Object>> cpuLoad(
            @RequestParam(defaultValue = "80") int loadPercentage,
            @RequestParam(defaultValue = "30") int durationSeconds) {
        
        logger.info("Triggering CPU load of {}% for {} seconds", loadPercentage, durationSeconds);
        
        int processors = Runtime.getRuntime().availableProcessors();
        threadPool = Executors.newFixedThreadPool(processors);
        
        // Calculate how long to burn CPU vs sleep
        final long startTime = System.currentTimeMillis();
        final long endTime = startTime + (durationSeconds * 1000);
        
        for (int i = 0; i < processors; i++) {
            threadPool.submit(() -> {
                while (System.currentTimeMillis() < endTime) {
                    // Calculate burn and sleep times based on load percentage
                    long burnTime = (loadPercentage * 10) / 100;
                    long sleepTime = 10 - burnTime;
                    
                    // Burn CPU
                    long burnUntil = System.currentTimeMillis() + burnTime;
                    while (System.currentTimeMillis() < burnUntil) {
                        // Burn CPU with meaningless calculations
                        Math.sin(Math.random() * Math.PI);
                    }
                    
                    // Sleep to achieve desired load percentage
                    if (sleepTime > 0) {
                        try {
                            Thread.sleep(sleepTime);
                        } catch (InterruptedException e) {
                            Thread.currentThread().interrupt();
                            return;
                        }
                    }
                }
            });
        }
        
        // Schedule shutdown of thread pool
        new Thread(() -> {
            try {
                Thread.sleep(durationSeconds * 1000L);
                threadPool.shutdown();
                threadPool.awaitTermination(5, TimeUnit.SECONDS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            } finally {
                if (!threadPool.isTerminated()) {
                    threadPool.shutdownNow();
                }
            }
        }).start();
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "CPU load triggered");
        response.put("loadPercentage", loadPercentage);
        response.put("durationSeconds", durationSeconds);
        response.put("processors", processors);
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/thread-leak")
    public ResponseEntity<Map<String, Object>> threadLeak(
            @RequestParam(defaultValue = "10") int threadCount) {
        
        logger.info("Creating {} threads that will never terminate", threadCount);
        
        for (int i = 0; i < threadCount; i++) {
            Thread thread = new Thread(() -> {
                while (!Thread.currentThread().isInterrupted()) {
                    try {
                        Thread.sleep(10000);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                }
            });
            thread.setName("LeakedThread-" + counter.incrementAndGet());
            thread.setDaemon(false); // Non-daemon threads
            thread.start();
        }
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "Thread leak triggered");
        response.put("threadsCreated", threadCount);
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/out-of-memory")
    public ResponseEntity<Map<String, Object>> outOfMemory() {
        logger.info("Triggering OutOfMemoryError");
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "Attempting to trigger OutOfMemoryError");
        
        // Start a new thread to avoid crashing the response
        new Thread(() -> {
            try {
                Thread.sleep(1000); // Wait a second before triggering
                List<byte[]> list = new ArrayList<>();
                while (true) {
                    // Allocate 10MB at a time
                    list.add(new byte[10 * 1024 * 1024]);
                    Thread.sleep(100); // Small delay to make it less aggressive
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }).start();
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/deadlock")
    public ResponseEntity<Map<String, Object>> deadlock() {
        logger.info("Triggering deadlock between threads");
        
        final Object lock1 = new Object();
        final Object lock2 = new Object();
        
        // Thread 1: Tries to lock lock1 then lock2
        Thread thread1 = new Thread(() -> {
            synchronized (lock1) {
                try {
                    Thread.sleep(500); // Wait to ensure thread2 locks lock2
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
                synchronized (lock2) {
                    logger.info("Thread 1 acquired both locks (this will never happen)");
                }
            }
        });
        thread1.setName("DeadlockThread-1");
        
        // Thread 2: Tries to lock lock2 then lock1
        Thread thread2 = new Thread(() -> {
            synchronized (lock2) {
                try {
                    Thread.sleep(500); // Wait to ensure thread1 locks lock1
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
                synchronized (lock1) {
                    logger.info("Thread 2 acquired both locks (this will never happen)");
                }
            }
        });
        thread2.setName("DeadlockThread-2");
        
        thread1.start();
        thread2.start();
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "Deadlock triggered between two threads");
        
        return ResponseEntity.ok(response);
    }
} 