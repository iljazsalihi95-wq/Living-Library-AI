// Safe initial backend: no public OpenAI proxy until authentication and limits are ready.
export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/health') {
      return Response.json({ service: 'living-library-ai-api', status: 'ok', aiEnabled: false }, {
        headers: { 'Cache-Control': 'no-store' },
      });
    }
    return Response.json({ error: 'AI is not enabled yet. Authentication and rate limits are required.' }, {
      status: 503,
      headers: { 'Cache-Control': 'no-store' },
    });
  },
};
