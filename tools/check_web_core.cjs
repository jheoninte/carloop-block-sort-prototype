// Exercise the production web core without a DOM or browser storage.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'web-prototype/index.html'), 'utf8');
const start = html.indexOf('class GameCore {');
const end = html.indexOf("const STORAGE_KEY =", start);
assert(start >= 0 && end > start, 'production core boundaries');
const Core = new Function('const clone = value => JSON.parse(JSON.stringify(value));\n' + html.slice(start, end) + '\nreturn GameCore;')();
const levels = JSON.parse(fs.readFileSync(path.join(root, 'godot-project/data/levels.json'), 'utf8'));
const solutions = JSON.parse(fs.readFileSync(path.join(root, 'godot-project/data/level_solutions.json'), 'utf8'));
const embedded = JSON.parse(html.match(/<script id="levelData" type="application\/json">([\s\S]*?)<\/script>/)[1]);
assert.deepEqual(embedded, levels, 'shared level definitions');
let runs = 0;
for (const level of levels) for (const rate of [60, 120]) for (const speed of [1, 2]) {
  const core = new Core([level]);
  core.state.speed = speed;
  for (const id of solutions[level.id].launches) {
    const source = core.state.cars.find(car => car.id === id);
    assert.equal(core.launchCar(id), 'launched', level.id + ' launches ' + id);
    assert.equal(core.state.track.at(-1).progress, source.lane % level.trackNodes.length, 'source dock');
    for (let frame = 0; frame < Math.round(solutions[level.id].waitSeconds * rate); frame++) core.updateProgress(1 / rate);
    assert(core.validSnapshot(core.state, 0), level.id + ' conserved state');
  }
  assert(core.isCleared(), level.id + ' clears');
  runs++;
}
console.log(`PASS: web core ${levels.length} levels, ${runs} replays, source docks and shared data`);
