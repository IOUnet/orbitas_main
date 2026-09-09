import { Client, StreamableHTTPClientTransport } from '@modelcontextprotocol/client';

const endpoint = process.env.MCP_URL ?? 'http://127.0.0.1:3000/mcp';

function extractText(result: unknown): string {
  const content = (result as { content?: Array<{ type?: string; text?: string }> }).content ?? [];
  const firstText = content.find((item) => item.type === 'text' && typeof item.text === 'string');
  if (!firstText?.text) throw new Error('MCP tool returned no text payload');
  return firstText.text;
}

const client = new Client(
  { name: 'orbitas-test-env-smoke', version: '0.1.0' },
  { versionNegotiation: { mode: 'auto' } }
);
const transport = new StreamableHTTPClientTransport(new URL(endpoint));

try {
  await client.connect(transport);

  const healthResult = await client.callTool({
    name: 'orbitas_index_health',
    arguments: {}
  });
  const healthText = extractText(healthResult);
  const health = JSON.parse(healthText) as { _meta?: { hasIndexingErrors?: boolean } };
  if (health._meta?.hasIndexingErrors === true) {
    throw new Error('Orbitas Subgraph reports indexing errors through MCP');
  }

  const pathResult = await client.callTool({
    name: 'orbitas_find_local_paths',
    arguments: { intermediaryPassportId: '2', limit: 20 }
  });
  const pathText = extractText(pathResult);
  const payload = JSON.parse(pathText) as {
    paths?: Array<{ payerPassportId?: string; intermediaryPassportId?: string; receiverPassportId?: string }>;
  };

  const seededPath = (payload.paths ?? []).find(
    (path) =>
      path.payerPassportId === '1' &&
      path.intermediaryPassportId === '2' &&
      path.receiverPassportId === '3'
  );

  if (!seededPath) {
    throw new Error('MCP did not return the seeded Alice(1) -> Bob(2) -> Carol(3) candidate path');
  }

  console.log('MCP protocol smoke: PASS');
  console.log(JSON.stringify(seededPath, null, 2));
} finally {
  await client.close();
}
