import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { homedir } from 'node:os';
import assert from 'node:assert/strict';

const root = fileURLToPath(new URL('../', import.meta.url));
const moon = process.env.MOON ?? resolve(homedir(), '.moon', 'bin', process.platform === 'win32' ? 'moon.exe' : 'moon');
const python = process.env.PYTHON ?? (process.platform === 'win32' ? 'python' : 'python3');
function run(command, args, capture = false) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', stdio: capture ? 'pipe' : 'inherit', timeout: 120000 });
  if (result.error) throw result.error;
  if (!capture && result.status !== 0) throw new Error(`${command} ${args.join(' ')} failed: ${result.status}`);
  return result;
}

run(moon, ['version', '--all']);
run(python, ['scripts/generate_vectors.py', '--check']);
run(moon, ['fmt', '--check']);
const targets = ['js', 'wasm', 'wasm-gc'];
if (process.env.MOON_NATIVE === '1') targets.push('native');
for (const target of targets) {
  for (const command of ['check', 'build', 'test']) run(moon, [command, '--target', target, '--deny-warn']);
}

const scenarios = run(moon, ['run', 'examples/scenarios', '--target', 'js', '--deny-warn'], true);
assert.equal(scenarios.status, 0, scenarios.stderr);
assert.equal(scenarios.stdout.trim().replaceAll('\r\n', '\n'), [
  'Billing: 2025-01-31T09:00Z, 2025-02-28T09:00Z, 2025-03-31T09:00Z',
  'Maintenance: 2025-10-20T09:00Z, 2025-10-23T09:00Z, 2025-11-03T09:00Z, 2025-11-06T09:00Z',
  'Appointments: 2025-01-03T09:00Z',
  'Exhausted: true',
].join('\n'));

function cli(args, expected) {
  const output = run(moon, ['run', 'cmd/main', '--target', 'js', '--deny-warn', '--', ...args], true);
  assert.equal(output.status, 0, output.stderr);
  assert.equal(output.stdout.trim().replaceAll('\r\n', '\n'), expected);
}
cli(['next', 'rrule:FREQ=DAILY;COUNT=3', '2025-01-01T09:00Z', '2025-01-02T10:00Z', '4'], '2025-01-03T09:00Z');
cli(['window', 'rrule:FREQ=MONTHLY;COUNT=3', '2025-01-31T09:00Z', '2025-03-01T00:00Z', '2025-06-01T00:00Z'], '2025-03-31T09:00Z\n2025-05-31T09:00Z');
cli(['next', 'cron:*/15 9-17 * * MON-FRI', '2025-01-06T09:01Z', '2'], '2025-01-06T09:15Z\n2025-01-06T09:30Z');
for (const invalid of [
  ['parse', 'rrule:FREQ=DAILY;COUNT=2;UNTIL=20250103T090000Z'],
  ['next', 'rrule:FREQ=DAILY;COUNT=3', '2025-01-01T09:00Z', '2'],
  ['window', 'rrule:FREQ=DAILY', '2025-01-01T09:00Z', 'bad-date', '2025-01-10T00:00Z'],
]) {
  const result = run(moon, ['run', 'cmd/main', '--target', 'js', '--deny-warn', '--', ...invalid], true);
  assert.notEqual(result.status, 0, 'Invalid CLI input must return a failing exit status');
  assert.match(result.stderr + result.stdout, /invalid (rule|arguments|date)/);
}
run(moon, ['package']);
console.log(`Verified ${targets.join(', ')}; independent vectors, CLI errors, scenarios, and source package passed.`);
