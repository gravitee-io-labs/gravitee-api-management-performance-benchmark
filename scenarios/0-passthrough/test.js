import http from 'k6/http';

export const options = {
  scenarios: {
    "warm-up": {
      executor: 'constant-arrival-rate',
      duration: '30s',
      gracefulStop: '10s',
      preAllocatedVUs: 10,
      maxVUs: 10,
      rate: 200,
      timeUnit: '1s',
    },
    "passthrough": {
      executor: 'ramping-arrival-rate',
      startTime: '40s', // 10s after warm-up
      gracefulStop: '10s',
      preAllocatedVUs: 100,
      maxVUs: 100,
      startRate: 200,
      timeUnit: '1s',
      stages: [
        { target: 10000, duration: '2m' }, // Configure your limit here
        { target: 10000, duration: '10s' }, // Configure your limit here
        { target: 200, duration: '30s' },
        { target: 200, duration: '30s' }
      ]
    }
  }
};

export default function () {
  http.get('http://apim-gateway.gio-apim.svc.cluster.local:82/passthrough/json/valid');
}
