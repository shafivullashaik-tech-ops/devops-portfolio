// k6 Load Test — High Error Rate Simulation
// Generates traffic to trigger HighErrorRate alert
// Usage: k6 run sre-observability-stack/load-tests/high-error-rate.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

// Get the demo-app URL from environment or use default
const BASE_URL = __ENV.TARGET_URL || 'http://demo-app.default.svc.cluster.local:3000';

export const options = {
  stages: [
    { duration: '1m', target: 10 },   // Ramp up to 10 users
    { duration: '3m', target: 50 },   // Stay at 50 users (generates load)
    { duration: '1m', target: 0 },    // Ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500'],
    'errors': ['rate<0.1'],
  },
};

export default function () {
  const res = http.get(`${BASE_URL}/api/metrics`);

  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  errorRate.add(!success);
  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': JSON.stringify({
      testName: 'high-error-rate',
      totalRequests: data.metrics.http_reqs.values.count,
      errorRate: data.metrics.errors ? data.metrics.errors.values.rate : 0,
      p95Latency: data.metrics.http_req_duration.values['p(95)'],
      p99Latency: data.metrics.http_req_duration.values['p(99)'],
    }, null, 2),
  };
}
