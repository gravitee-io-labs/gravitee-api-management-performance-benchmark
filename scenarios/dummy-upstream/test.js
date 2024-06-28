import http from 'k6/http';

export const options = {
  scenarios: {
    "dummy-upstream": {
      executor: 'ramping-arrival-rate',
      gracefulStop: '10s',
      preAllocatedVUs: 500,
      maxVUs: 500,
      startRate: 200,
      timeUnit: '1s',
      stages: [
        { target: 150000, duration: '2m' },
        { target: 150000, duration: '30s' },
        { target: 200, duration: '10s' },
      ]
    }
  }
};

export default function () {
  http.get('http://upstream.dummy-upstream-api-service.svc.cluster.local:8000/json/valid');
}
