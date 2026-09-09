import http from 'node:http';
import { createMcpHandler } from '@modelcontextprotocol/server';
import { toNodeHandler } from '@modelcontextprotocol/node';
import { buildServer } from './server.js';
const port = Number(process.env.PORT ?? 3000);
const handler = createMcpHandler(() => buildServer());
const nodeHandler = toNodeHandler(handler);
http.createServer((req,res)=>{ if(req.url?.startsWith('/mcp')) return nodeHandler(req,res); res.writeHead(404).end(); }).listen(port,()=>console.error(`Orbitas MCP listening on :${port}/mcp`));
