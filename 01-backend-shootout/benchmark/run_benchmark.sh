#!/bin/bash
# Backend Shootout - Benchmark Runner
# Usage: ./run_benchmark.sh <runtime_name> <start_command>
# Example: ./run_benchmark.sh nodejs "node server.js"

set -e

RUNTIME=${1:-"unknown"}
START_CMD=${2:-""}
PORT=3000
RESULTS_DIR="$(dirname "$0")/../results"
RESULT_FILE="$RESULTS_DIR/${RUNTIME}.txt"
DURATION=30          # seconds per test
CONNECTIONS=100      # concurrent connections
THREADS=4            # wrk threads

mkdir -p "$RESULTS_DIR"

echo "============================================"
echo "  Backend Shootout: $RUNTIME"
echo "============================================"
echo ""

# ── Check deps ────────────────────────────────
for cmd in wrk curl bc; do
    if ! command -v $cmd &>/dev/null; then
        echo "ERROR: '$cmd' not found. Install it first."
        exit 1
    fi
done

wait_for_server() {
    echo "Waiting for server on port $PORT..."
    for i in $(seq 1 30); do
        if curl -sf http://localhost:$PORT/hello >/dev/null 2>&1; then
            echo "Server is up!"
            return 0
        fi
        sleep 1
    done
    echo "ERROR: Server did not start in 30 seconds"
    exit 1
}

# ── Startup time ──────────────────────────────
echo "[1/5] Measuring startup time..."
START_TS=$(date +%s%N)
eval "$START_CMD" &
SERVER_PID=$!
wait_for_server
END_TS=$(date +%s%N)
STARTUP_MS=$(( (END_TS - START_TS) / 1000000 ))
echo "  Startup time: ${STARTUP_MS}ms"

sleep 1  # stabilize

# ── Memory before load ────────────────────────
MEM_KB=$(cat /proc/$SERVER_PID/status 2>/dev/null | grep VmRSS | awk '{print $2}' || echo "0")
MEM_MB=$(echo "scale=1; $MEM_KB / 1024" | bc)
echo "  Idle memory: ${MEM_MB} MB"

# ── /hello benchmark ─────────────────────────
echo ""
echo "[2/5] Benchmarking GET /hello (${DURATION}s, ${CONNECTIONS} connections)..."
HELLO_RESULT=$(wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s --latency http://localhost:$PORT/hello 2>&1)
echo "$HELLO_RESULT"

HELLO_RPS=$(echo "$HELLO_RESULT" | grep "Requests/sec" | awk '{print $2}')
HELLO_LAT=$(echo "$HELLO_RESULT" | grep "Latency" | head -1 | awk '{print $2}')
HELLO_P99=$(echo "$HELLO_RESULT" | grep "99%" | awk '{print $2}')

# ── /user/:id benchmark ───────────────────────
echo ""
echo "[3/5] Benchmarking GET /user/:id (${DURATION}s, ${CONNECTIONS} connections)..."
USER_RESULT=$(wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s --latency \
    -s "$(dirname "$0")/user_bench.lua" \
    http://localhost:$PORT 2>&1)
echo "$USER_RESULT"

USER_RPS=$(echo "$USER_RESULT" | grep "Requests/sec" | awk '{print $2}')
USER_LAT=$(echo "$USER_RESULT" | grep "Latency" | head -1 | awk '{print $2}')

# ── /cpu benchmark ────────────────────────────
echo ""
echo "[4/5] Benchmarking GET /cpu (${DURATION}s, 20 connections — CPU heavy)..."
CPU_RESULT=$(wrk -t$THREADS -c20 -d${DURATION}s --latency http://localhost:$PORT/cpu 2>&1)
echo "$CPU_RESULT"

CPU_RPS=$(echo "$CPU_RESULT" | grep "Requests/sec" | awk '{print $2}')
CPU_LAT=$(echo "$CPU_RESULT" | grep "Latency" | head -1 | awk '{print $2}')

# ── CPU usage under load ──────────────────────
echo ""
echo "[5/5] Measuring CPU under load..."
wrk -t$THREADS -c$CONNECTIONS -d10s http://localhost:$PORT/hello >/dev/null 2>&1 &
WRK_PID=$!
sleep 3
CPU_USAGE=$(ps -p $SERVER_PID -o %cpu --no-headers 2>/dev/null | tr -d ' ' || echo "N/A")
wait $WRK_PID 2>/dev/null || true

# ── Memory under load ─────────────────────────
MEM_LOAD_KB=$(cat /proc/$SERVER_PID/status 2>/dev/null | grep VmRSS | awk '{print $2}' || echo "0")
MEM_LOAD_MB=$(echo "scale=1; $MEM_LOAD_KB / 1024" | bc)

# ── Crash point (find max connections) ────────
echo ""
echo "Testing crash/stability at high concurrency (500 connections)..."
CRASH_RESULT=$(wrk -t8 -c500 -d10s http://localhost:$PORT/hello 2>&1 || echo "CRASHED")
CRASH_ERRORS=$(echo "$CRASH_RESULT" | grep -E "errors|CRASHED" | head -1 || echo "stable")

# ── Stop server ───────────────────────────────
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

# ── Write results ─────────────────────────────
cat > "$RESULT_FILE" << EOF
Runtime: $RUNTIME
Date: $(date)

=== API Benchmark (GET /hello) ===
Requests/sec:  $HELLO_RPS
Avg Latency:   $HELLO_LAT
P99 Latency:   $HELLO_P99

=== Database Benchmark (GET /user/:id) ===
Requests/sec:  $USER_RPS
Avg Latency:   $USER_LAT

=== CPU Benchmark (GET /cpu) ===
Requests/sec:  $CPU_RPS
Avg Latency:   $CPU_LAT

=== Resource Usage ===
Idle Memory:   ${MEM_MB} MB
Peak Memory:   ${MEM_LOAD_MB} MB
CPU Under Load: ${CPU_USAGE}%
Startup Time:  ${STARTUP_MS}ms

=== Stability ===
High Concurrency (500): $CRASH_ERRORS
EOF

echo ""
echo "============================================"
echo "  Results saved to: $RESULT_FILE"
echo "============================================"
cat "$RESULT_FILE"
