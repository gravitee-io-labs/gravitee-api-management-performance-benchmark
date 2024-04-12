import http from 'k6/http';

export const options = {
  scenarios: {
    "apikey": {
      executor: 'ramping-arrival-rate',
      gracefulStop: '10s',
      preAllocatedVUs: 200,
      maxVUs: 500,
      startRate: 200,
      timeUnit: '1s',
      stages: [
        { target: 30000, duration: '2m' },
        { target: 30000, duration: '30s' }
      ]
    },
  },
};

export default function () {
  const params = {
    headers: {
      'X-Gravitee-Api-Key': '',
    },
  };

  http.get('http://apim-gateway.gio-apim.svc.cluster.local:82/apikey/json/valid', params);
}