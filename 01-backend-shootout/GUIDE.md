# Backend Runtime Shootout — Complete Guide
# DigitalOcean Droplet Setup

## Recommended Droplet
- **Size**: 4 vCPU / 8GB RAM (CPU-Optimized preferred)
- **OS**: Ubuntu 22.04 LTS
- **Why**: Consistent results; avoids OOM during Rust compilation

---

## STEP 0 — Initial Droplet Setup

```bash
# SSH into your droplet
ssh root@YOUR_DROPLET_IP

# Update system
apt update && apt upgrade -y

# Upload this project to the droplet
# From your local machine:
scp -r backend-shootout root@YOUR_DROPLET_IP:~/
```

---

## STEP 1 — Install Dependencies (Do Once)

```bash
# Install wrk (benchmarking tool)
apt install -y wrk curl git cmake build-essential libssl-dev zlib1g-dev

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Install Python 3 + pip
apt install -y python3 python3-pip python3-venv

# Install Go
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
go version

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
rustup update stable
cargo --version

# Verify wrk is available
wrk --version
```

---

## STEP 2 — Build All Servers

```bash
cd ~/backend-shootout

# ── Python ──────────────────────────────────
cd servers/python
pip3 install -r requirements.txt
cd ~/backend-shootout

# ── Go ──────────────────────────────────────
cd servers/go
go build -o server main.go
ls -lh server   # check binary size
cd ~/backend-shootout

# ── Rust ────────────────────────────────────
# NOTE: First build takes 3–5 minutes
cd servers/rust
cargo build --release
ls -lh target/release/server   # check binary size
cd ~/backend-shootout

# ── C++ ─────────────────────────────────────
cd servers/cpp
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
ls -lh server   # check binary size
cd ~/backend-shootout

# ── Node.js ─────────────────────────────────
# No build step needed! (interpreted)
```

---

## STEP 3 — Run Benchmarks (One at a Time)

Make scripts executable first:
```bash
chmod +x benchmark/run_benchmark.sh benchmark/compare_results.sh
```

### Test 1: Node.js

```bash
cd ~/backend-shootout
./benchmark/run_benchmark.sh nodejs "node servers/nodejs/server.js"
```

### Test 2: Python (FastAPI)

```bash
cd ~/backend-shootout
./benchmark/run_benchmark.sh python \
  "uvicorn servers.python.server:app --host 0.0.0.0 --port 3000 --workers 4"
```

> **Note**: The module path `servers.python.server` requires running from the project root.
> If it fails, try: `cd servers/python && uvicorn server:app --port 3000 --workers 4`

### Test 3: Go

```bash
cd ~/backend-shootout
./benchmark/run_benchmark.sh go "./servers/go/server"
```

### Test 4: Rust

```bash
cd ~/backend-shootout
./benchmark/run_benchmark.sh rust "./servers/rust/target/release/server"
```

### Test 5: C++

```bash
cd ~/backend-shootout
./benchmark/run_benchmark.sh cpp "./servers/cpp/build/server"
```

---

## STEP 4 — Manual Metrics to Record

The script captures most metrics, but record these **manually** per runtime:

### Binary / Build Size
```bash
# Go
ls -lh servers/go/server

# Rust
ls -lh servers/rust/target/release/server

# C++
ls -lh servers/cpp/build/server

# Python (no binary)
du -sh servers/python/

# Node.js (no binary)
du -sh servers/nodejs/
```

### Build Time
```bash
# Time the build commands:
time go build -o server main.go
time cargo build --release
time make -j$(nproc)
```

### Manually run a sanity check on each endpoint:
```bash
# Start a server first, then:
curl http://localhost:3000/hello
curl http://localhost:3000/user/42
curl http://localhost:3000/cpu
```

---

## STEP 5 — View Comparison

After all 5 runtimes are tested:

```bash
cd ~/backend-shootout
./benchmark/compare_results.sh
```

Results are also saved individually in `results/` as:
- `results/nodejs.txt`
- `results/python.txt`
- `results/go.txt`
- `results/rust.txt`
- `results/cpp.txt`

---

## STEP 6 — Manual Evaluation Checklist

Fill this in after testing. Rate each 1–5.

| Criteria            | Node.js | Python | Go | Rust | C++ |
|---------------------|---------|--------|----|------|-----|
| Dev Experience      |         |        |    |      |     |
| Learning Curve      |         |        |    |      |     |
| Ecosystem           |         |        |    |      |     |
| Community           |         |        |    |      |     |
| Hosting Cost        |         |        |    |      |     |
| Production Ready    |         |        |    |      |     |

**Scoring guide:**
- Dev Experience: How fast can you write/debug?
- Learning Curve: How hard to get started?
- Ecosystem: Packages, libraries, tooling
- Community: Stack Overflow, Discord, docs quality
- Hosting Cost: Reflects how much horsepower you need
- Production Ready: Error handling, observability, stability

---

## Troubleshooting

**Port already in use:**
```bash
lsof -ti:3000 | xargs kill -9
```

**wrk not found:**
```bash
apt install -y wrk
# or build from source:
git clone https://github.com/wg/wrk.git && cd wrk && make && cp wrk /usr/local/bin/
```

**Rust build OOM crash:**
```bash
# Add swap space
fallocate -l 4G /swapfile
chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
# Then retry: cargo build --release
```

**Python module not found:**
```bash
cd servers/python
pip3 install fastapi uvicorn[standard]
uvicorn server:app --host 0.0.0.0 --port 3000 --workers 4
```

---

## Expected Results (Rough Ballpark)

| Runtime | /hello RPS    | Idle RAM | Startup  |
|---------|---------------|----------|----------|
| C++     | 80k–200k      | ~5 MB    | <50ms    |
| Rust    | 70k–150k      | ~8 MB    | <100ms   |
| Go      | 50k–100k      | ~15 MB   | <200ms   |
| Node.js | 20k–50k       | ~40 MB   | ~200ms   |
| Python  | 5k–15k        | ~60 MB   | ~800ms   |

> Results vary heavily by droplet specs. CPU-optimized droplets favor compiled langs even more.
