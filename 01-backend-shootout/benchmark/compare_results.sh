#!/bin/bash
# Aggregates all result files and prints a comparison table

RESULTS_DIR="$(dirname "$0")/../results"

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    BACKEND RUNTIME SHOOTOUT RESULTS                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

extract() {
    local file="$1"
    local key="$2"
    grep "$key" "$file" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | xargs
}

printf "%-12s %-14s %-14s %-12s %-12s %-10s %-10s %-12s\n" \
    "Runtime" "/hello RPS" "/user RPS" "/cpu RPS" "Idle RAM" "Peak RAM" "CPU%" "Startup"
printf "%-12s %-14s %-14s %-12s %-12s %-10s %-10s %-12s\n" \
    "-------" "----------" "---------" "--------" "--------" "--------" "----" "-------"

for file in "$RESULTS_DIR"/*.txt; do
    [ -f "$file" ] || continue
    runtime=$(extract "$file" "^Runtime")
    hello_rps=$(extract "$file" "Requests/sec" | head -1)
    # re-extract per section
    hello_rps=$(grep -A3 "API Benchmark" "$file" | grep "Requests/sec" | awk -F': ' '{print $2}' | xargs)
    user_rps=$(grep -A3 "Database Benchmark" "$file" | grep "Requests/sec" | awk -F': ' '{print $2}' | xargs)
    cpu_rps=$(grep -A3 "CPU Benchmark" "$file" | grep "Requests/sec" | awk -F': ' '{print $2}' | xargs)
    idle_mem=$(extract "$file" "Idle Memory")
    peak_mem=$(extract "$file" "Peak Memory")
    cpu_pct=$(extract "$file" "CPU Under Load")
    startup=$(extract "$file" "Startup Time")

    printf "%-12s %-14s %-14s %-12s %-12s %-10s %-10s %-12s\n" \
        "$runtime" "$hello_rps" "$user_rps" "$cpu_rps" "$idle_mem" "$peak_mem" "$cpu_pct" "$startup"
done

echo ""
echo "Higher RPS = better | Lower latency/RAM/CPU = better"
echo ""

# Rankings
echo "=== RANKINGS BY /hello RPS ==="
for file in "$RESULTS_DIR"/*.txt; do
    [ -f "$file" ] || continue
    runtime=$(extract "$file" "^Runtime")
    rps=$(grep -A3 "API Benchmark" "$file" | grep "Requests/sec" | awk -F': ' '{print $2}' | xargs)
    echo "$rps $runtime"
done | sort -rn | awk '{printf "  %d. %-12s %s req/s\n", NR, $2, $1}'
