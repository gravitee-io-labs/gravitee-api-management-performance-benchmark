import http from 'k6/http';

export const options = {
  scenarios: {
    "50rps-30s": {
      executor: 'constant-arrival-rate',
      duration: '30s',
      preAllocatedVUs: 50,
      maxVUs: 100,
      rate: 200,
      timeUnit: '1s',
    },
  },
};

export default function () {
  http.get('http://apim-gateway.gio-apim.svc.cluster.local:82/echo');
}
