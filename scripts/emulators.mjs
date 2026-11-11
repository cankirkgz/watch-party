import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
// Load the confirmed, ignored local file into the child environment only.
try { process.loadEnvFile(fileURLToPath(new URL('../.env.local',import.meta.url))); } catch {}
const command = process.platform === 'win32' ? 'npx.cmd' : 'npx';
const child = spawn(command,['--yes','firebase-tools@15.34.2','emulators:start','--project','watch-party-d4610','--only','auth,firestore,storage,functions'],{cwd:fileURLToPath(new URL('..',import.meta.url)),env:process.env,stdio:'inherit',shell:process.platform==='win32'});
child.on('exit',code=>process.exitCode=code ?? 1);
