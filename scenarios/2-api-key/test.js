import http from 'k6/http';

export const options = {
  scenarios: {
    "apikey": {
      executor: 'ramping-arrival-rate',
      gracefulStop: '10s',
      preAllocatedVUs: 20000,
      maxVUs: 50000,
      startRate: 200,
      timeUnit: '1s',
      stages: [
        { target: 200, duration: '10s' },
        { target: 20000, duration: '5m' },
        { target: 20000, duration: '30s' },
        { target: 200, duration: '30s' }
      ]
    },
  },
};

export default function () {
  const params = {
    headers: {
      'X-Gravitee-Api-Key': '99095f64-0071-4cc9-b70d-5c0760beafdb',
    },
  };

  http.get('http://apim-gateway.gio-apim.svc.cluster.local:82/apikey/json/valid', params);
}
