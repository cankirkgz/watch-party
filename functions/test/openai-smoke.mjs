import { fileURLToPath } from 'node:url';
import OpenAI from 'openai';
import { translationInstructions } from '../src/translation.js';
try {
  process.loadEnvFile(fileURLToPath(new URL('../../.env.local', import.meta.url)));
  const response=await new OpenAI({timeout:25000,maxRetries:0}).responses.create({model:'gpt-4.1-mini',instructions:translationInstructions('tr'),input:'Этот момент просто невероятный 😂',max_output_tokens:120,store:false});
  console.log(JSON.stringify({ok:true,model:response.model,translation:response.output_text}));
} catch(e) { console.log(JSON.stringify({ok:false,status:e.status ?? null,code:e.code ?? null}));process.exitCode=1; }
