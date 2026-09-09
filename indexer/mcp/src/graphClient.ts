export type GraphResponse<T> = { data?: T; errors?: Array<{ message: string }> };

export class GraphClient {
  constructor(private readonly endpoint: string, private readonly apiKey?: string) {}

  async query<T>(query: string, variables: Record<string, unknown>, timeoutMs = 8_000): Promise<T> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const headers: Record<string,string> = { 'content-type': 'application/json' };
      if (this.apiKey) headers.authorization = `Bearer ${this.apiKey}`;
      const r = await fetch(this.endpoint, { method: 'POST', headers, body: JSON.stringify({ query, variables }), signal: controller.signal });
      if (!r.ok) throw new Error(`GraphQL HTTP ${r.status}`);
      const body = await r.json() as GraphResponse<T>;
      if (body.errors?.length) throw new Error(body.errors.map(e=>e.message).join('; '));
      if (!body.data) throw new Error('GraphQL response missing data');
      return body.data;
    } finally { clearTimeout(timer); }
  }
}
