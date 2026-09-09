import { serveStdio } from '@modelcontextprotocol/server/stdio';
import { buildServer } from './server.js';
await serveStdio(() => buildServer());
