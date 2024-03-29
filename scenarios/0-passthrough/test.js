import http from 'k6/http';

export const options = {
  scenarios: {
    "warm-up": {
      executor: 'constant-arrival-rate',
      duration: '30s',
      gracefulStop: '10s',
      preAllocatedVUs: 1000,
      rate: 200,
      timeUnit: '1s',
    },
    "passthrough": {
      executor: 'ramping-arrival-rate',
      startTime: '50s', // 10s to 20s after warm-up
      gracefulStop: '10s',
      preAllocatedVUs: 20000,
      maxVUs: 50000,
      startRate: 200,
      timeUnit: '1s',
      stages: [
        { target: 200, duration: '10s' },
        { target: 25000, duration: '3m' },
        { target: 25000, duration: '30s' },
        { target: 200, duration: '30s' }
      ]
    }
  }
};

export default function () {
  http.get('http://apim-gateway.gio-apim.svc.cluster.local:82/passthrough/json/valid');
}
