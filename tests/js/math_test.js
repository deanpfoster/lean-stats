// tests/js/math_test.js — verify JS math functions match Lean's answers
// Run: node tests/js/math_test.js
// Expected values come from our ProvenTheorems (native_decide in Lean)

const assert = require('assert');

// ═══════════════════════════════════════════════════════════
// Manually define the math functions (same as in our generated JS)
// This is the "extract math into testable module" approach
// ═══════════════════════════════════════════════════════════

// Transform functions (from Jmp.lean)
function tx(v, f) {
  switch(f) {
    case 'recip': return v !== 0 ? 1/v : NaN;
    case 'log': return v > 0 ? Math.log(v) : NaN;
    case 'sqrt': return v >= 0 ? Math.sqrt(v) : NaN;
    case 'square': return v * v;
    case 'exp': return Math.exp(v);
    default: return v;
  }
}

// Inverse transforms
function itx(v, f) {
  switch(f) {
    case 'recip': return v !== 0 ? 1/v : NaN;
    case 'log': return Math.exp(v);
    case 'sqrt': return v * v;
    case 'square': return v >= 0 ? Math.sqrt(v) : NaN;
    case 'exp': return Math.log(v);
    default: return v;
  }
}

// Polynomial fit via normal equations (from Jmp.lean)
function polyFit(x, y, deg) {
  const n = x.length, p = deg + 1;
  let XtX = []; for (let i = 0; i < p; i++) { XtX[i] = []; for (let j = 0; j < p; j++) { let s = 0; for (let k = 0; k < n; k++) s += Math.pow(x[k], i) * Math.pow(x[k], j); XtX[i][j] = s; } }
  let Xty = []; for (let i = 0; i < p; i++) { let s = 0; for (let k = 0; k < n; k++) s += Math.pow(x[k], i) * y[k]; Xty[i] = s; }
  let A = XtX.map((r, i) => [...r, Xty[i]]);
  const m = A.length;
  for (let i = 0; i < m; i++) { let mx = i; for (let j = i+1; j < m; j++) if (Math.abs(A[j][i]) > Math.abs(A[mx][i])) mx = j; [A[i], A[mx]] = [A[mx], A[i]];
    if (Math.abs(A[i][i]) < 1e-12) continue;
    for (let j = i+1; j < m; j++) { let f = A[j][i]/A[i][i]; for (let k = i; k <= m; k++) A[j][k] -= f * A[i][k]; } }
  let coef = new Array(m);
  for (let i = m-1; i >= 0; i--) { coef[i] = A[i][m]; for (let j = i+1; j < m; j++) coef[i] -= A[i][j] * coef[j]; coef[i] /= A[i][i]; }
  return coef;
}

function polyEval(coef, x) { let y = 0; for (let i = 0; i < coef.length; i++) y += coef[i] * Math.pow(x, i); return y; }

// PAV (from Binary.lean)
function pav(y) {
  var n = y.length; var val = y.slice(); var cnt = new Array(n).fill(1);
  var j = 0;
  for (var i = 1; i < n; i++) {
    val[j+1] = y[i]; cnt[j+1] = 1; j++;
    while (j > 0 && val[j] < val[j-1]) {
      val[j-1] = (val[j-1]*cnt[j-1] + val[j]*cnt[j]) / (cnt[j-1] + cnt[j]);
      cnt[j-1] += cnt[j]; j--;
    }
  }
  var result = []; for (var k = 0; k <= j; k++) { for (var m = 0; m < cnt[k]; m++) result.push(val[k]); }
  return result;
}

// ═══════════════════════════════════════════════════════════
// TESTS — Layer 1: Math correctness
// Expected values from Lean ProvenTheorems
// ═══════════════════════════════════════════════════════════

let passed = 0, failed = 0;

function test(name, fn) {
  try { fn(); passed++; console.log(`  ✓ ${name}`); }
  catch(e) { failed++; console.log(`  ✗ ${name}: ${e.message}`); }
}

function approx(a, b, tol = 1e-8) {
  assert(Math.abs(a - b) < tol, `expected ${b}, got ${a}`);
}

console.log('Layer 1: Math correctness');
console.log('─────────────────────────');

// Transforms
test('tx linear identity', () => approx(tx(5, 'linear'), 5));
test('tx log(e) = 1', () => approx(tx(Math.E, 'log'), 1));
test('tx sqrt(4) = 2', () => approx(tx(4, 'sqrt'), 2));
test('tx recip(2) = 0.5', () => approx(tx(2, 'recip'), 0.5));
test('tx square(3) = 9', () => approx(tx(3, 'square'), 9));
test('tx exp(0) = 1', () => approx(tx(0, 'exp'), 1));
test('tx log(-1) = NaN', () => assert(isNaN(tx(-1, 'log'))));

// Inverse transforms round-trip
test('itx(tx(5, log), log) = 5', () => approx(itx(tx(5, 'log'), 'log'), 5));
test('itx(tx(4, sqrt), sqrt) = 4', () => approx(itx(tx(4, 'sqrt'), 'sqrt'), 4));
test('itx(tx(3, recip), recip) = 3', () => approx(itx(tx(3, 'recip'), 'recip'), 3));

// Polynomial fit — Lean proves: linearRegression [1,2,3] [3,5,7] → slope=2, intercept=1
test('polyFit degree 1: slope=2, intercept=1', () => {
  const coef = polyFit([1,2,3], [3,5,7], 1);
  approx(coef[0], 1);  // intercept
  approx(coef[1], 2);  // slope
});

// Lean proves: mean [1,2,3,4,5] = 3
test('polyFit degree 0: mean = 3', () => {
  const coef = polyFit([1,2,3,4,5], [1,2,3,4,5], 0);
  approx(coef[0], 3);  // intercept = mean(y)
});

// Quadratic: y = x² on [1,2,3,4] → coef[2] should be 1
test('polyFit degree 2: y=x²', () => {
  const coef = polyFit([1,2,3,4], [1,4,9,16], 2);
  approx(coef[2], 1, 1e-6);  // x² coefficient
  approx(coef[1], 0, 1e-6);  // x coefficient
  approx(coef[0], 0, 1e-6);  // intercept
});

test('polyEval [1, 2] at x=3 → 7', () => approx(polyEval([1, 2], 3), 7));
test('polyEval [0, 0, 1] at x=3 → 9', () => approx(polyEval([0, 0, 1], 3), 9));

// PAV — monotone increasing
test('pav already monotone', () => {
  const result = pav([0, 0.3, 0.7, 1]);
  assert.deepStrictEqual(result, [0, 0.3, 0.7, 1]);
});

test('pav with violation', () => {
  const result = pav([0, 1, 0, 1]);
  // [0, 1, 0, 1] → [0, 0.5, 0.5, 1] (pool middle two)
  approx(result[0], 0);
  approx(result[1], 0.5);
  approx(result[2], 0.5);
  approx(result[3], 1);
});

test('pav all same', () => {
  const result = pav([0.5, 0.5, 0.5]);
  assert.deepStrictEqual(result, [0.5, 0.5, 0.5]);
});

test('pav decreasing → all pooled to mean', () => {
  const result = pav([1, 0]);
  approx(result[0], 0.5);
  approx(result[1], 0.5);
});

// ═══════════════════════════════════════════════════════════
// TESTS — Layer 2: Signal correctness
// ═══════════════════════════════════════════════════════════

console.log('');
console.log('Layer 2: Signal construction');
console.log('────────────────────────────');

// Simulate pointState and test what report() would produce
function buildSelectionReport(pointState) {
  const selected = [], excluded = [];
  let nVisible = 0;
  for (let i = 0; i < pointState.length; i++) {
    if (pointState[i].selected) selected.push(i);
    if (pointState[i].excluded) excluded.push(i);
    if (!pointState[i].hidden) nVisible++;
  }
  return { event: 'selection_changed', selected, excluded, n_visible: nVisible };
}

test('no selection → empty arrays', () => {
  const state = Array(5).fill(null).map(() => ({selected:false, excluded:false, hidden:false}));
  const msg = buildSelectionReport(state);
  assert.deepStrictEqual(msg.selected, []);
  assert.deepStrictEqual(msg.excluded, []);
  assert.strictEqual(msg.n_visible, 5);
});

test('select points 1,3 → selected=[1,3]', () => {
  const state = Array(5).fill(null).map(() => ({selected:false, excluded:false, hidden:false}));
  state[1].selected = true;
  state[3].selected = true;
  const msg = buildSelectionReport(state);
  assert.deepStrictEqual(msg.selected, [1, 3]);
});

test('exclude point 2 → excluded=[2]', () => {
  const state = Array(5).fill(null).map(() => ({selected:false, excluded:false, hidden:false}));
  state[2].excluded = true;
  const msg = buildSelectionReport(state);
  assert.deepStrictEqual(msg.excluded, [2]);
});

test('hide point 4 → n_visible=4', () => {
  const state = Array(5).fill(null).map(() => ({selected:false, excluded:false, hidden:false}));
  state[4].hidden = true;
  const msg = buildSelectionReport(state);
  assert.strictEqual(msg.n_visible, 4);
});

// Test command handling
function applyCommand(pointState, cmd) {
  if (cmd.cmd === 'select') {
    pointState.forEach(p => p.selected = false);
    cmd.ids.forEach(i => { if (pointState[i]) pointState[i].selected = true; });
  } else if (cmd.cmd === 'clearSelection') {
    pointState.forEach(p => p.selected = false);
  } else if (cmd.cmd === 'excludeSelected') {
    pointState.forEach(p => { if (p.selected) { p.excluded = true; p.selected = false; } });
  } else if (cmd.cmd === 'includeAll') {
    pointState.forEach(p => p.excluded = false);
  } else if (cmd.cmd === 'hideExcluded') {
    pointState.forEach(p => { if (p.excluded) p.hidden = true; });
  } else if (cmd.cmd === 'showAll') {
    pointState.forEach(p => p.hidden = false);
  } else if (cmd.cmd === 'invertSelection') {
    pointState.forEach(p => { if (!p.hidden) p.selected = !p.selected; });
  }
  return pointState;
}

test('cmd select [1,2] → only those selected', () => {
  let state = Array(5).fill(null).map(() => ({selected:false, excluded:false, hidden:false}));
  state = applyCommand(state, {cmd: 'select', ids: [1, 2]});
  assert(state[1].selected && state[2].selected);
  assert(!state[0].selected && !state[3].selected);
});

test('cmd excludeSelected → selected become excluded', () => {
  let state = Array(5).fill(null).map(() => ({selected:false, excluded:false, hidden:false}));
  state[3].selected = true;
  state = applyCommand(state, {cmd: 'excludeSelected'});
  assert(state[3].excluded);
  assert(!state[3].selected);
});

test('cmd invertSelection → flips non-hidden', () => {
  let state = Array(4).fill(null).map(() => ({selected:false, excluded:false, hidden:false}));
  state[0].selected = true;
  state[3].hidden = true;
  state = applyCommand(state, {cmd: 'invertSelection'});
  assert(!state[0].selected);  // was selected, now not
  assert(state[1].selected);   // was not, now is
  assert(state[2].selected);   // was not, now is
  assert(!state[3].selected);  // hidden, unchanged
});

test('cmd includeAll → clears all excluded', () => {
  let state = Array(3).fill(null).map(() => ({selected:false, excluded:true, hidden:false}));
  state = applyCommand(state, {cmd: 'includeAll'});
  assert(!state[0].excluded && !state[1].excluded && !state[2].excluded);
});

test('cmd hideExcluded → excluded become hidden', () => {
  let state = Array(3).fill(null).map(() => ({selected:false, excluded:false, hidden:false}));
  state[1].excluded = true;
  state = applyCommand(state, {cmd: 'hideExcluded'});
  assert(state[1].hidden);
  assert(!state[0].hidden);
});

test('full workflow: select boys, exclude, fit girls', () => {
  // 5 points: 0,1,2 are "boys", 3,4 are "girls"
  let state = Array(5).fill(null).map(() => ({selected:false, excluded:false, hidden:false}));
  // Select boys
  state = applyCommand(state, {cmd: 'select', ids: [0, 1, 2]});
  // Exclude them
  state = applyCommand(state, {cmd: 'excludeSelected'});
  // Now only girls (3,4) are in the fit
  const inFit = state.map((p, i) => !p.excluded ? i : null).filter(x => x !== null);
  assert.deepStrictEqual(inFit, [3, 4]);
});

// ═══════════════════════════════════════════════════════════
// Summary
// ═══════════════════════════════════════════════════════════

console.log('');
console.log(`═══════════════════════════`);
console.log(`Results: ${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
