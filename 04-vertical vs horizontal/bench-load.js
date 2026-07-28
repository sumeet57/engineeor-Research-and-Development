const autocannon = require('autocannon');

const URL = process.env.TARGET_URL || 'http://localhost/api/workload';
const CONNECTIONS = parseInt(process.env.CONNECTIONS || '100', 10);
const DURATION = parseInt(process.env.DURATION || '20', 10);

console.log(`Running REST API Benchmark on ${URL}`);
console.log(`Connections: ${CONNECTIONS}, Duration: ${DURATION}s`);

const instance = autocannon({
  url: URL,
  connections: CONNECTIONS,
  duration: DURATION
}, (err, result) => {
  if (err) {
    console.error(err);
    return;
  }
  console.log('\n===== BENCHMARK RESULTS =====');
  console.log(`Req/Sec (Throughput) : ${result.requests.average}`);
  console.log(`Latency Average      : ${result.latency.average} ms`);
  console.log(`Latency P99          : ${result.latency.p99} ms`);
  console.log(`Total Requests       : ${result.requests.total}`);
  console.log(`Errors               : ${result.errors}`);
});

autocannon.track(instance, { renderProgressBar: true });
