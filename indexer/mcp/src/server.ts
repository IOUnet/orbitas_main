import { McpServer, ResourceTemplate } from '@modelcontextprotocol/server';
import * as z from 'zod/v4';
import { GraphClient } from './graphClient.js';
import * as Q from './queries.js';

const MAX_PAGE = 100;

type Edge = { id:string; issuerPassportId:string; beneficiaryPassportId:string; resourceType:number; resourceCode:string; unitCode:string; currencyCode:string; availableQuantity:string; decimals:number; dueDate:string; status:number };

export function buildServer(): McpServer {
  const endpoint = process.env.GRAPHQL_ENDPOINT;
  if (!endpoint) throw new Error('GRAPHQL_ENDPOINT is required');
  const graph = new GraphClient(endpoint, process.env.GRAPH_API_KEY);
  const server = new McpServer({ name:'orbitas-indexer', version:'0.1.0' }, { capabilities:{ tools:{}, resources:{} } });
  const text = (value:unknown) => ({ content:[{ type:'text' as const, text:JSON.stringify(value,null,2) }] });

  server.registerTool('orbitas_index_health',{description:'Return Orbitas Subgraph deployment, indexed block and indexing-error state.'},async()=>text(await graph.query(Q.HEALTH,{})));
  server.registerTool('orbitas_get_passport',{description:'Read one SELF_DECLARED Orbitas participant passport projection.',inputSchema:z.object({passportId:z.string().regex(/^\\d+$/)})},async({passportId})=>text(await graph.query(Q.PASSPORT,{id:passportId})));
  server.registerTool('orbitas_get_obligation',{description:'Read one multidimensional obligation projection including current quality dimensions. Projection is not canonical settlement authority.',inputSchema:z.object({obligationId:z.string().regex(/^\\d+$/)})},async({obligationId})=>text(await graph.query(Q.OBLIGATION,{id:obligationId})));
  server.registerTool('orbitas_list_obligations',{description:'List indexed obligations with bounded cursor pagination.',inputSchema:z.object({first:z.number().int().min(1).max(MAX_PAGE).default(25),after:z.string().default(''),issuerPassportId:z.string().regex(/^\\d+$/).optional(),beneficiaryPassportId:z.string().regex(/^\\d+$/).optional(),status:z.number().int().min(0).max(3).optional()})},async(args)=>text(await graph.query(Q.LIST,{first:args.first,after:args.after,issuer:args.issuerPassportId??null,beneficiary:args.beneficiaryPassportId??null,status:args.status??null})));
  server.registerTool('orbitas_get_incoming_obligations',{description:'List active indexed obligations owed to a participant.',inputSchema:z.object({passportId:z.string().regex(/^\\d+$/),first:z.number().int().min(1).max(MAX_PAGE).default(50)})},async({passportId,first})=>text(await graph.query(Q.INCOMING,{pid:passportId,first})));
  server.registerTool('orbitas_get_outgoing_obligations',{description:'List active indexed obligations owed by a participant.',inputSchema:z.object({passportId:z.string().regex(/^\\d+$/),first:z.number().int().min(1).max(MAX_PAGE).default(50)})},async({passportId,first})=>text(await graph.query(Q.OUTGOING,{pid:passportId,first})));
  server.registerTool('orbitas_find_local_paths',{description:'Find deterministic indexed A→B→C candidate paths around intermediary B. Candidates require canonical revalidation and consent before execution.',inputSchema:z.object({intermediaryPassportId:z.string().regex(/^\\d+$/),limit:z.number().int().min(1).max(50).default(20)})},async({intermediaryPassportId,limit})=>{
    const [inc,out] = await Promise.all([graph.query<{obligations:Edge[],_meta:unknown}>(Q.INCOMING,{pid:intermediaryPassportId,first:MAX_PAGE}),graph.query<{obligations:Edge[],_meta:unknown}>(Q.OUTGOING,{pid:intermediaryPassportId,first:MAX_PAGE})]);
    const paths=[] as unknown[];
    const incoming=[...inc.obligations].sort((a,b)=>BigInt(b.availableQuantity)>BigInt(a.availableQuantity)?1:BigInt(b.availableQuantity)<BigInt(a.availableQuantity)?-1:Number(BigInt(a.id)-BigInt(b.id)));
    const outgoing=[...out.obligations].sort((a,b)=>BigInt(b.availableQuantity)>BigInt(a.availableQuantity)?1:BigInt(b.availableQuantity)<BigInt(a.availableQuantity)?-1:Number(BigInt(a.id)-BigInt(b.id)));
    for(const a of incoming){for(const c of outgoing){if(paths.length>=limit)break; if(a.issuerPassportId===c.beneficiaryPassportId)continue; if(a.resourceType!==c.resourceType||a.resourceCode!==c.resourceCode||a.unitCode!==c.unitCode||a.currencyCode!==c.currencyCode||a.decimals!==c.decimals)continue; const q=BigInt(a.availableQuantity)<BigInt(c.availableQuantity)?BigInt(a.availableQuantity):BigInt(c.availableQuantity); paths.push({incomingObligationId:a.id,outgoingObligationId:c.id,payerPassportId:a.issuerPassportId,intermediaryPassportId,receiverPassportId:c.beneficiaryPassportId,matchedQuantity:q.toString(),decimals:a.decimals,candidateOnly:true});} if(paths.length>=limit)break;}
    return text({paths,indexMeta:{incoming:inc._meta,outgoing:out._meta},warning:'Indexer candidates are not executable until on-chain state and consent policies are revalidated.'});
  });
  server.registerTool('orbitas_get_settlement',{description:'Read one multilateral settlement-instruction projection.',inputSchema:z.object({settlementId:z.string().regex(/^0x[0-9a-fA-F]{64}$/)})},async({settlementId})=>text(await graph.query(Q.SETTLEMENT,{id:settlementId.toLowerCase()})));

  server.registerResource('index-health','orbitas://index/health',{description:'Current Subgraph indexing health.',mimeType:'application/json'},async uri=>({contents:[{uri:uri.href,mimeType:'application/json',text:JSON.stringify(await graph.query(Q.HEALTH,{}))}]}));
  server.registerResource('obligation',new ResourceTemplate('orbitas://obligation/{id}',{list:undefined}),{description:'One indexed Orbitas obligation.',mimeType:'application/json'},async(uri,{id})=>({contents:[{uri:uri.href,mimeType:'application/json',text:JSON.stringify(await graph.query(Q.OBLIGATION,{id:String(id)}))}]}));
  return server;
}
