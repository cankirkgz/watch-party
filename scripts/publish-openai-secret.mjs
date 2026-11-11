import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
process.loadEnvFile(fileURLToPath(new URL('../.env.local',import.meta.url)));
if (!process.env.OPENAI_API_KEY?.startsWith('sk-')) throw new Error('OPENAI_API_KEY is missing');
const child = spawn(process.platform==='win32'?'npx.cmd':'npx',['--yes','firebase-tools@15.34.2','functions:secrets:set','OPENAI_API_KEY','--project','watch-party-d4610','--data-file','-','--non-interactive'],{cwd:fileURLToPath(new URL('..',import.meta.url)),env:process.env,stdio:['pipe','inherit','inherit'],shell:process.platform==='win32'});
child.stdin.end(process.env.OPENAI_API_KEY);
child.on('exit',code=>process.exitCode=code ?? 1);
