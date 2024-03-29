import http from 'k6/http';

export const options = {
  scenarios: {
    "dummy-upstream": {
      executor: 'ramping-arrival-rate',
      gracefulStop: '10s',
      preAllocatedVUs: 20000,
      maxVUs: 50000,
      startRate: 200,
      timeUnit: '1s',
      stages: [
        { target: 200, duration: '10s' },
        { target: 30000, duration: '3m' }
      ]
    }
  }
};

export default function () {
  http.get('http://upstream.dummy-upstream-api-service.svc.cluster.local:8000/json/valid');
}
