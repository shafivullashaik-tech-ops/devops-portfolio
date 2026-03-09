// k6 Load Test — High Latency Simulation
// Generates sustained traffic to trigger HighP99Latency alert
// Usage: k6 run sre-observability-stack/load-tests/high-latency.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

const latencyTrend = new Trend('custom_latency');

const BASE_URL = __ENV.TARGET_URL || 'http://demo-app.default.svc.cluster.local:3000';

export const options = {
  stages: [
    { duration: '30s', target: 5 },   // Warm up
    { duration: '5m', target: 100 },  // High load - forces latency
    { duration: '30s', target: 0 },   // Wind down
  ],
  thresholds: {
    'http_req_duration': ['p(99)<2000'], // Alert fires at 1s - we expect breach
  },
};

export default function () {
  // Hit multiple endpoints
  const endpoints = ['/health', '/ready', '/api/metrics'];
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];

  const res = http.get(`${BASE_URL}${endpoint}`);

  latencyTrend.add(res.timings.duration);

  check(res, {
    'status is 2xx': (r) => r.status >= 200 && r.status < 300,
  });

  sleep(0.1); // Aggressive pacing to saturate
}

export function handleSummary(data) {
  return {
    'stdout': JSON.stringify({
      testName: 'high-latency',
      totalRequests: data.metrics.http_reqs.values.count,
      p50Latency: data.metrics.http_req_duration.values['p(50)'],
      p95Latency: data.metrics.http_req_duration.values['p(95)'],
      p99Latency: data.metrics.http_req_duration.values['p(99)'],
      avgLatency: data.metrics.http_req_duration.values.avg,
    }, null, 2),
  };
}
